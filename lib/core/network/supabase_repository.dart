import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/bank_deposit.dart';
import '../../models/credit_customer.dart';
import '../../models/interim_cash_drop.dart';
import '../../models/monthly_payroll_settlement.dart';
import '../../models/nozzle.dart';
import '../../models/pos_transaction.dart';
import '../../models/station.dart';
import '../../models/user_profile.dart';
import '../config/supabase_config.dart';
import '../notifications/forecourt_notification.dart';

class SupabaseRepository {
  static final SupabaseRepository instance = SupabaseRepository._internal();
  SupabaseRepository._internal();

  SupabaseClient? _client;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  /// Fallback station code used when a payload carries none
  /// (matches StationAppState's default station).
  static const String _defaultStationCode = 'LEKKI-01';

  static final RegExp _uuidRe =
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Client-side RFC-4122 v4 id so offline-created rows carry an id the
  /// uuid/text primary keys of every write table accept (and so queue
  /// retries stay idempotent).
  String generateUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Resolve a station code ('LEKKI-01') to its uuid (ids pass through).
  Future<String?> _resolveStationUuid(String idOrCode) async {
    if (_uuidRe.hasMatch(idOrCode)) return idOrCode;
    try {
      final st =
          await client.from('stations').select('id').eq('code', idOrCode).maybeSingle();
      return st?['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Drop nulls (columns may predate a field) so queued payloads never
  /// reference columns the table lacks with explicit nulls.
  Map<String, dynamic> _cleanPayload(Map<String, dynamic> p) {
    final row = Map<String, dynamic>.from(p);
    row.removeWhere((_, v) => v == null);
    return row;
  }

  /// '2026-10-08T14:03:11+00:00' -> '08 Oct 2026'
  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return 'Unknown';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  /// Initialize Supabase connection
  Future<bool> initialize() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      _client = Supabase.instance.client;
      _isConnected = true;
      return true;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // STATIONS & BRANCHES (§1, §2.1)
  // ---------------------------------------------------------------------------

  /// Fetch all active stations from Supabase
  Future<List<Station>> fetchAllStations() async {
    if (!_isConnected) return [];

    try {
      final data = await client
          .from('stations')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);

      return (data as List)
          .map((row) => Station.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Director / Admin: Register a new branch station (§1)
  Future<Station?> createStation({
    required String code,
    required String name,
    String? address,
    String? phone,
    String? managerName,
    bool hasInterlockedTanks = false,
  }) async {
    if (!_isConnected) return null;
    try {
      final res = await client.from('stations').insert({
        'code': code.toUpperCase().trim(),
        'name': name.trim(),
        'address': address?.trim(),
        'phone': phone?.trim(),
        'manager_name': managerName?.trim(),
        'has_interlocked_tanks': hasInterlockedTanks,
        'is_active': true,
      }).select().single();
      return Station.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // AUTHENTICATION & PROFILES (§2.1–§2.4)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> verifyAttendantPin({
    required String stationId,
    required String profileId,
    required String pin,
  }) async {
    if (!_isConnected) {
      return {'success': false, 'message': 'Authentication service unavailable — terminal is offline'};
    }

    try {
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      String effectiveStationId = stationId;

      // If stationId was passed as a station code (e.g. 'LEKKI-01'), resolve its UUID
      if (!uuidRegex.hasMatch(effectiveStationId)) {
        try {
          final st = await client
              .from('stations')
              .select('id')
              .ilike('code', stationId.trim())
              .maybeSingle();
          if (st != null && st['id'] != null) {
            effectiveStationId = st['id'] as String;
          } else {
            // Default Lekki Road Station UUID
            effectiveStationId = '4c960eed-2f2e-461a-a27e-00a41f5f7bd1';
          }
        } catch (_) {
          effectiveStationId = '4c960eed-2f2e-461a-a27e-00a41f5f7bd1';
        }
      }

      // 1. Try PostgreSQL RPC attendant_pin_login if profileId is a UUID
      if (uuidRegex.hasMatch(profileId) && uuidRegex.hasMatch(effectiveStationId)) {
        try {
          final res = await client.rpc('attendant_pin_login', params: {
            'p_station_id': effectiveStationId,
            'p_profile_id': profileId,
            'p_pin': pin,
          });
          final map = Map<String, dynamic>.from(res as Map);
          if (map['success'] == true) {
            return map;
          }
        } catch (rpcErr) {
          // Log RPC failure and proceed to direct profile verification fallback
        }
      }

      // 2. Direct database query fallback against profiles table
      try {
        final Map<String, dynamic>? profRow = uuidRegex.hasMatch(profileId)
            ? await client.from('profiles').select().eq('id', profileId).maybeSingle()
            : await client
                .from('profiles')
                .select()
                .or('display_name.ilike.%$profileId%,full_name.ilike.%$profileId%')
                .maybeSingle();

        if (profRow != null) {
          final storedPin = profRow['pin_hash']?.toString().trim();
          if (storedPin != null && storedPin.isNotEmpty && storedPin == pin) {
            return {
              'success': true,
              'user': profRow,
            };
          }
        }
      } catch (_) {}

      return {'success': false, 'message': 'Invalid PIN'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<UserProfile>> fetchStationStaff([String? stationCode]) async {
    if (!_isConnected) return [];

    try {
      final data = await client
          .from('profiles')
          .select('*, stations(name, code)')
          .order('created_at', ascending: true);

      return (data as List).map((row) {
        final roleStr = row['role'] as String;
        UserRole role;
        switch (roleStr) {
          case 'manager':
            role = UserRole.manager;
            break;
          case 'cashier':
            role = UserRole.cashier;
            break;
          case 'director':
          case 'admin':
            role = UserRole.director;
            break;
          default:
            role = UserRole.attendant;
        }

        final stationMap = row['stations'] as Map?;
        final stationName = stationMap?['name'] ?? (role == UserRole.director ? 'HQ · Corporate' : 'Station');

        return UserProfile(
          id: row['id'] as String,
          displayName: row['display_name'] as String,
          fullName: row['full_name'] as String,
          role: role,
          stationName: stationName,
          stationId: row['station_id'],
          phone: row['phone'],
          address: row['address'],
          suretyName: row['surety_name'],
          suretyPhone: row['surety_phone'],
          suretyAddress: row['surety_address'],
          baseSalary: (row['base_salary'] as num?)?.toDouble() ?? 0.0,
          isActive: row['is_active'] ?? true,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Onboard a new pump attendant, cashier, or manager (§2.2)
  Future<UserProfile?> createStaffProfile({
    required String fullName,
    required String displayName,
    required UserRole role,
    required String pin,
    required String stationCode,
    String? phone,
    String? address,
    String? suretyName,
    String? suretyPhone,
    String? suretyAddress,
    double baseSalary = 0.0,
  }) async {
    if (!_isConnected) {
      return UserProfile(
        id: 'staff-${DateTime.now().millisecondsSinceEpoch}',
        displayName: displayName,
        fullName: fullName,
        role: role,
        stationName: stationCode,
        phone: phone,
        address: address,
        suretyName: suretyName,
        suretyPhone: suretyPhone,
        suretyAddress: suretyAddress,
        baseSalary: baseSalary,
        isActive: true,
      );
    }

    try {
      String? stationId;
      String stationName = 'Station';
      if (role != UserRole.director) {
        final st = await client.from('stations').select('id, name').eq('code', stationCode).maybeSingle();
        stationId = st?['id'];
        stationName = st?['name'] ?? stationCode;
      } else {
        stationName = 'HQ · Corporate';
      }

      final roleStr = role.name;

      final res = await client.from('profiles').insert({
        'full_name': fullName,
        'display_name': displayName,
        'role': roleStr,
        'pin_hash': pin,
        'phone': phone,
        'address': address,
        'surety_name': suretyName,
        'surety_phone': suretyPhone,
        'surety_address': suretyAddress,
        'station_id': stationId,
        'base_salary': baseSalary,
        'is_active': true,
      }).select().single();

      return UserProfile(
        id: res['id'] as String,
        displayName: res['display_name'] as String,
        fullName: res['full_name'] as String,
        role: role,
        stationName: stationName,
        stationId: stationId,
        phone: phone,
        address: address,
        suretyName: suretyName,
        suretyPhone: suretyPhone,
        suretyAddress: suretyAddress,
        baseSalary: (res['base_salary'] as num?)?.toDouble() ?? baseSalary,
        isActive: true,
      );
    } catch (e) {
      return null;
    }
  }

  /// Director only: Update monthly base salary (§4.7, Executive Payroll)
  Future<bool> updateStaffSalary({required String profileId, required double baseSalary}) async {
    if (!_isConnected) return true;
    try {
      await client.from('profiles').update({'base_salary': baseSalary}).eq('id', profileId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reset attendant login PIN (§2.3)
  Future<bool> resetStaffPin({required String profileId, required String newPin}) async {
    if (!_isConnected) return true;
    try {
      await client.from('profiles').update({'pin_hash': newPin}).eq('id', profileId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Toggle active / inactive status (dismissal or leave)
  Future<bool> toggleStaffStatus({required String profileId, required bool isActive}) async {
    if (!_isConnected) return true;
    try {
      await client.from('profiles').update({'is_active': isActive}).eq('id', profileId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SHIFTS, READINGS & REMITTANCES (§2.5–§2.10, §4.1–§4.7)
  // ---------------------------------------------------------------------------

  Future<String?> createShift({
    required String stationId,
    required String shiftType,
    required String openedBy,
  }) async {
    if (!_isConnected) return 'SHIFT-LOCAL-01';

    try {
      final res = await client.from('shifts').insert({
        'station_id': stationId,
        'shift_type': shiftType,
        'opened_by': openedBy,
        'status': 'open',
      }).select('id').single();

      return res['id'] as String;
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveClosingReadings({
    required String shiftId,
    required List<NozzleItem> nozzles,
  }) async {
    if (!_isConnected) return true;

    try {
      for (final n in nozzles) {
        if (n.closingReading != null) {
          await client.from('shift_nozzle_assignments').upsert(
            {
              'shift_id': shiftId,
              'nozzle_id': n.nozzleNumber,
              'opening_reading': n.openingReading,
              'closing_reading': n.closingReading,
              'price_per_litre': n.pricePerLitre,
              'submitted_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'shift_id,nozzle_id',
          );
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitRemittanceRecord({
    required String shiftId,
    required String attendantId,
    required double expectedSales,
    required double cash,
    required double posCard,
    required double posTransfer,
    required double bankTransfer,
    required double credit,
    required List<String> proofUrls,
  }) async {
    if (!_isConnected) return true;

    try {
      final res = await client.from('remittances').insert({
        'shift_id': shiftId,
        'attendant_id': attendantId,
        'expected_sales_value': expectedSales,
        'cash_declared': cash,
        'pos_card_declared': posCard,
        'pos_transfer_declared': posTransfer,
        'bank_transfer_declared': bankTransfer,
        'credit_sales_declared': credit,
        'status': 'submitted',
      }).select('id').single();

      final remittanceId = res['id'] as String;

      for (var url in proofUrls) {
        await client.from('remittance_evidence').insert({
          'remittance_id': remittanceId,
          'payment_channel': 'pos_slip',
          'storage_path': url,
          'amount': posCard,
        });
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // INTRA-SHIFT CASH DROPS & IN-BETWEEN POS TRANSACTIONS (§2.6, §4.1, §4.4)
  // ---------------------------------------------------------------------------

  /// Fetch today's interim cash drops for the station
  Future<List<InterimCashDrop>> fetchInterimCashDrops([String? stationCode]) async {
    if (!_isConnected) return [];
    try {
      final res = await client
          .from('interim_cash_drops')
          .select('*, profiles(full_name, display_name)')
          .order('created_at', ascending: false);

      return (res as List)
          .map((row) => InterimCashDrop.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Attendant submits an intra-shift cash drop to Cashier
  Future<InterimCashDrop?> createInterimCashDrop({
    required String stationCode,
    required String attendantId,
    required String attendantName,
    required double amount,
    String? notes,
    String? shiftId,
  }) async {
    if (!_isConnected) {
      return InterimCashDrop(
        id: generateUuid(),
        shiftId: shiftId,
        stationId: stationCode,
        attendantId: attendantId,
        attendantName: attendantName,
        amount: amount,
        notes: notes,
        status: 'pending',
        createdAt: DateTime.now(),
      );
    }

    try {
      final res = await client.from('interim_cash_drops').insert({
        'station_id': stationCode,
        'attendant_id': attendantId,
        'amount': amount,
        'notes': notes,
        'status': 'pending',
        'shift_id': shiftId,
      }).select().single();

      return InterimCashDrop.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      return null;
    }
  }

  /// Cashier acknowledges and accepts the interim cash drop into drawer
  Future<bool> acknowledgeInterimCashDrop({
    required String dropId,
    required String cashierId,
  }) async {
    if (!_isConnected) return true;
    try {
      await client.from('interim_cash_drops').update({
        'status': 'acknowledged',
        'acknowledged_by': cashierId,
        'acknowledged_at': DateTime.now().toIso8601String(),
      }).eq('id', dropId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetch in-between POS & bank transfer transactions
  Future<List<PosTransaction>> fetchShiftPosTransactions([String? stationCode]) async {
    if (!_isConnected) return [];
    try {
      final res = await client
          .from('shift_pos_transactions')
          .select('*, profiles(full_name, display_name)')
          .order('created_at', ascending: false);

      return (res as List)
          .map((row) => PosTransaction.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Attendant logs in-between POS card or transfer sale
  Future<PosTransaction?> recordShiftPosTransaction({
    required String stationCode,
    required String attendantId,
    required String attendantName,
    required String paymentChannel,
    required double amount,
    String? terminalName,
    String? referenceNumber,
    String? storagePath,
    String? customerVehicle,
    String? shiftId,
  }) async {
    if (!_isConnected) {
      return PosTransaction(
        id: generateUuid(),
        shiftId: shiftId,
        stationId: stationCode,
        attendantId: attendantId,
        attendantName: attendantName,
        paymentChannel: paymentChannel,
        amount: amount,
        terminalName: terminalName,
        referenceNumber: referenceNumber,
        storagePath: storagePath,
        customerVehicle: customerVehicle,
        createdAt: DateTime.now(),
      );
    }

    try {
      final res = await client.from('shift_pos_transactions').insert({
        'station_id': stationCode,
        'attendant_id': attendantId,
        'payment_channel': paymentChannel,
        'amount': amount,
        'terminal_name': terminalName,
        'reference_number': referenceNumber,
        'storage_path': storagePath,
        'customer_vehicle': customerVehicle,
        'shift_id': shiftId,
      }).select().single();

      return PosTransaction.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CASHIER VERIFICATION & SAFE NOTE COUNT (§5.3–§5.5)
  // ---------------------------------------------------------------------------

  Future<bool> verifyShift({
    required String remittanceId,
    required String cashierId,
    required String comment,
  }) async {
    if (!_isConnected) return true;

    try {
      await client.from('remittances').update({
        'status': 'verified',
        'verified_by': cashierId,
        'verified_at': DateTime.now().toIso8601String(),
        'cashier_notes': comment,
      }).eq('id', remittanceId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Persist a physical cash count audit row (§5.3).
  /// [payload] keys: station_id (code or uuid), cashier_id, opening_cash,
  /// cash_receipts, cash_expenses, handed_over_for_deposit,
  /// expected_closing_cash, physical_total_counted, count_*, deposit_status.
  Future<bool> recordDailyCashAuditPayload(Map<String, dynamic> payload) async {
    if (!_isConnected) return false;

    try {
      final row = _cleanPayload(payload);
      final sid = row['station_id']?.toString();
      if (sid == null) return false;
      final stationUuid = await _resolveStationUuid(sid);
      if (stationUuid == null) return false;
      row['station_id'] = stationUuid;

      await client.from('daily_cash_counts').insert(row);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // BANK DEPOSITS & DUAL-CUSTODY AUDIT TRAIL (§4.3, §5.4, §5.5)
  // ---------------------------------------------------------------------------

  Future<List<BankDepositRecord>> fetchBankDeposits(String stationCode) async {
    if (!_isConnected) return [];

    try {
      final stRes = await client.from('stations').select('id, name').eq('code', stationCode).maybeSingle();
      final stationId = stRes?['id'];
      final stationName = stRes?['name'] ?? 'Lekki Road Station';

      var query = client.from('bank_deposits').select('*');
      if (stationId != null) {
        query = query.eq('station_id', stationId);
      }
      final data = await query.order('created_at', ascending: false);

      return (data as List).map((row) {
        final map = Map<String, dynamic>.from(row);
        map['stations'] = {'name': stationName};
        return BankDepositRecord.fromJson(map);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<BankDepositRecord?> recordBankDeposit({
    required String stationCode,
    required double amount,
    required String bankName,
    required String bearerName,
    String? tellerNumber,
    String? slipUrl,
    String? notes,
  }) async {
    if (!_isConnected) {
      return BankDepositRecord(
        id: generateUuid(),
        stationName: 'Lekki Road Station',
        amount: amount,
        cashierName: bearerName,
        bankName: bankName,
        tellerNumber: tellerNumber,
        slipUrl: slipUrl,
        notes: notes,
        handedOverAt: DateTime.now(),
        status: 'awaiting_bank',
      );
    }

    try {
      final stRes = await client.from('stations').select('id, name').eq('code', stationCode).maybeSingle();
      final stationId = stRes?['id'];
      final stationName = stRes?['name'] ?? 'Lekki Road Station';

      final res = await client.from('bank_deposits').insert({
        if (stationId != null) 'station_id': stationId,
        'amount': amount,
        'bank_name': bankName,
        'bearer_name': bearerName,
        'teller_number': tellerNumber,
        'slip_url': slipUrl,
        'notes': notes,
        'status': 'awaiting_bank',
      }).select().single();

      final map = Map<String, dynamic>.from(res);
      map['stations'] = {'name': stationName};
      return BankDepositRecord.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  Future<bool> confirmBankDeposit({
    required String depositId,
    required String directorId,
    String? directorNotes,
  }) async {
    if (!_isConnected) return true;

    try {
      await client.from('bank_deposits').update({
        'status': 'confirmed',
        'is_confirmed': true,
        'confirmed_by': directorId,
        'confirmed_at': DateTime.now().toIso8601String(),
        'director_notes': directorNotes,
      }).eq('id', depositId);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> flagBankDepositDiscrepancy({
    required String depositId,
    required String directorId,
    required String discrepancyNotes,
  }) async {
    if (!_isConnected) return true;

    try {
      await client.from('bank_deposits').update({
        'status': 'discrepancy',
        'confirmed_by': directorId,
        'confirmed_at': DateTime.now().toIso8601String(),
        'director_notes': discrepancyNotes,
      }).eq('id', depositId);

      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // CREDIT & INVENTORY LEDGERS (§4.8–§4.10, §3.2–§3.9)
  // ---------------------------------------------------------------------------

  Future<List<CreditCustomer>> fetchCreditLedger(String stationId) async {
    if (!_isConnected) return CreditCustomer.getDefaultCustomers();

    try {
      final stationUuid = await _resolveStationUuid(stationId);
      var query = client.from('credit_customers').select();
      
      if (stationUuid != null) {
        query = query.eq('station_id', stationUuid);
      }
      
      final data = await query.order('company_name');
      return (data as List).map((row) {
        final lastPayment = row['last_payment_at'] as String?;
        return CreditCustomer(
          id: row['id'] as String,
          name: row['company_name'] as String,
          outstanding: (row['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
          lastRepayment: lastPayment != null
              ? _formatDate(lastPayment)
              : 'No repayment yet',
          dueDate: '${row['payment_terms_days'] ?? 0} days',
          status: row['status'] == 'overdue'
              ? CustomerCreditStatus.overdue
              : CustomerCreditStatus.current,
        );
      }).toList();
    } catch (e) {
      return CreditCustomer.getDefaultCustomers();
    }
  }

  Future<Map<String, double>> fetchLivePrices(String stationId) async {
    if (!_isConnected) return {'PMS': 1050.0, 'AGO': 1320.0};
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      final data = await client
          .from('fuel_prices')
          .select('product_id, price_per_litre, fuel_products(code)')
          .eq('station_id', stationUuid ?? stationId)
          .order('effective_from', ascending: false);

      final Map<String, double> prices = {'PMS': 1050.0, 'AGO': 1320.0};
      for (final row in (data as List)) {
        final productMap = row['fuel_products'] as Map?;
        final code = productMap?['code'] as String?;
        if (code != null && !prices.containsKey(code)) {
          prices[code] = (row['price_per_litre'] as num).toDouble();
        }
      }
      return prices;
    } catch (e) {
      return {'PMS': 1050.0, 'AGO': 1320.0};
    }
  }

  Future<Map<String, dynamic>?> fetchStationInfo(String stationCode) async {
    if (!_isConnected) return {'has_interlocked_tanks': true, 'name': 'Lekki Road Station'};
    try {
      final res = await client
          .from('stations')
          .select('id, code, name, has_interlocked_tanks')
          .eq('code', stationCode)
          .maybeSingle();
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      return {'has_interlocked_tanks': true, 'name': 'Lekki Road Station'};
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveTanks(String stationId) async {
    if (!_isConnected) return [];
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      var query = client
          .from('tanks')
          .select('id, code, capacity_litres, current_dip_litres, calculated_stock_litres, is_interlocked, fuel_products(code)');
      
      if (stationUuid != null) {
        query = query.eq('station_id', stationUuid);
      }
      
      final data = await query.order('code');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveNozzles(String stationId) async {
    if (!_isConnected) return [];
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      var query = client
          .from('nozzles')
          .select('id, nozzle_number, latest_meter_reading, supplying_tank_id, tanks(id, code), fuel_products(code)');
      
      if (stationUuid != null) {
        query = query.eq('station_id', stationUuid);
      }
      
      final data = await query.order('nozzle_number');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      return [];
    }
  }

  /// Director / Admin: Update station interlock capability
  Future<bool> updateStationInterlockStatus(String stationCode, bool hasInterlockedTanks) async {
    if (!_isConnected) return true;
    try {
      await client
          .from('stations')
          .update({'has_interlocked_tanks': hasInterlockedTanks})
          .eq('code', stationCode);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Director / Admin: Update tank manifold twin flag
  Future<bool> updateTankInterlock(String tankCode, bool isInterlocked) async {
    if (!_isConnected) return true;
    try {
      await client
          .from('tanks')
          .update({'is_interlocked': isInterlocked})
          .eq('code', tankCode);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update nozzle supplying tank (used for plumbing mapping and manifold switches)
  Future<bool> updateNozzleSupplyingTank(int nozzleNumber, String targetTankCode) async {
    if (!_isConnected) return true;
    try {
      final targetTank = await client
          .from('tanks')
          .select('id')
          .eq('code', targetTankCode)
          .single();
      final targetTankId = targetTank['id'];

      await client
          .from('nozzles')
          .update({'supplying_tank_id': targetTankId})
          .eq('nozzle_number', nozzleNumber);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Record full manifold changeover audit event (§3.1, §7)
  Future<bool> recordTankChangeover({
    required String stationCode,
    required String productCode,
    required String fromTankCode,
    required String toTankCode,
    required Map<String, double> switchReadings,
    double? fromTankDip,
    double? toTankDip,
    String? notes,
    String? switchedBy,
  }) async {
    if (!_isConnected) return true;
    try {
      // 1. Get station ID
      final station = await client.from('stations').select('id').eq('code', stationCode).single();
      final stationId = station['id'];

      // 2. Insert audit log
      await client.from('tank_changeovers').insert({
        'station_id': stationId,
        'product_code': productCode,
        'from_tank_code': fromTankCode,
        'to_tank_code': toTankCode,
        'switch_readings': switchReadings,
        'from_tank_dip_litres': fromTankDip,
        'to_tank_dip_litres': toTankDip,
        'notes': notes,
        'switched_by': switchedBy,
      });

      // 3. Update active nozzle supplying_tank_id
      final targetTank = await client.from('tanks').select('id').eq('code', toTankCode).single();
      final targetTankId = targetTank['id'];

      for (final nozzleStr in switchReadings.keys) {
        final nozzleNum = int.tryParse(nozzleStr.replaceAll(RegExp(r'[^0-9]'), ''));
        if (nozzleNum != null) {
          await client.from('nozzles').update({
            'supplying_tank_id': targetTankId,
            'latest_meter_reading': switchReadings[nozzleStr],
          }).eq('nozzle_number', nozzleNum);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveExpenses(String stationId) async {
    if (!_isConnected) return [];
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      var query = client.from('branch_expenses').select();
      
      if (stationUuid != null) {
        query = query.eq('station_id', stationUuid);
      }
      
      final data = await query.order('created_at', ascending: false).limit(30);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveSalaryAdjustments(String stationId) async {
    if (!_isConnected) return [];
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      var query = client.from('attendant_salary_adjustments').select();
      
      if (stationUuid != null) {
        query = query.eq('station_id', stationUuid);
      }
      
      final data = await query.order('created_at', ascending: false).limit(30);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // OFFLINE QUEUE PAYLOAD DISPATCH DISPATCHERS (PHASE 2)
  // ---------------------------------------------------------------------------

  Future<bool> syncClosingReadingsPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true; // Handled gracefully offline
    try {
      final shiftId = p['shiftId'] as String;
      final readings = p['readings'] as List;
      final stationCode = p['stationCode']?.toString() ?? _defaultStationCode;
      final stationUuid = await _resolveStationUuid(stationCode);
      for (final r in readings) {
        await client.from('shift_nozzle_assignments').upsert(
          {
            'shift_id': shiftId,
            'nozzle_id': r['nozzleNumber'],
            'opening_reading': r['openingReading'],
            'closing_reading': r['closingReading'],
            'price_per_litre': r['pricePerLitre'],
            'submitted_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'shift_id,nozzle_id',
        );

        // Roll the closing meter forward so the NEXT session's opening
        // reading starts where this one ended (otherwise every shift
        // re-opens at stale numbers and litres-sold is wrong).
        final closing = (r['closingReading'] as num?)?.toDouble();
        if (closing != null) {
          var meter = client
              .from('nozzles')
              .update({'latest_meter_reading': closing})
              .eq('nozzle_number', r['nozzleNumber'] as int);
          if (stationUuid != null) {
            meter = meter.eq('station_id', stationUuid);
          }
          await meter;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncRemittancePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      // Client-generated uuid keeps retries idempotent and lets the state
      // layer reference this submission before/after sync.
      final remittanceId = p['id']?.toString() ?? generateUuid();
      try {
        await client.from('remittances').insert({
          'id': remittanceId,
          'shift_id': p['shiftId'] ?? 'SHIFT-01',
          'attendant_id': p['attendantId'] ?? 'ATT-01',
          'expected_sales_value': p['expectedSalesValue'] ?? 0.0,
          'cash_declared': p['cashDeclared'] ?? 0.0,
          'pos_card_declared': p['posCardDeclared'] ?? 0.0,
          'pos_transfer_declared': p['posTransferDeclared'] ?? 0.0,
          'bank_transfer_declared': p['bankTransferDeclared'] ?? 0.0,
          'credit_sales_declared': p['creditSalesDeclared'] ?? 0.0,
          'status': 'submitted',
        });
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // already persisted on a retry
      }

      // Persist the attendant's evidence photos against this remittance so
      // the cashier on ANY device can open them during verification.
      final photos = p['evidencePhotos'];
      if (photos is List) {
        for (final url in photos.whereType<String>()) {
          try {
            await client.from('remittance_evidence').insert({
              'remittance_id': remittanceId,
              'storage_path': url,
              'payment_channel': 'pos_slip',
              'created_at': DateTime.now().toIso8601String(),
            });
          } on PostgrestException catch (e) {
            if (e.code != '23505') rethrow;
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cashier verification result for a remittance (status is plain text
  /// after the migration, so 'verified' / 'flagged_unresolved' are free-form).
  Future<bool> syncRemittanceVerificationPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      final id = p['id']?.toString();
      if (id == null) return false;
      await client.from('remittances').update({
        'status': p['status'],
        'cashier_notes': p['cashierNotes'],
        'verified_by': p['verifiedBy'],
        'verified_at': p['verifiedAt'] ?? DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncCreditSalePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      final saleId = p['id']?.toString();
      final row = {
        if (saleId != null) 'id': saleId,
        'customer_id': p['customerId'],
        'driver_name': p['driverName'],
        'vehicle_reg': p['vehicleReg'],
        'litres': p['litres'],
        'total_amount': p['totalAmount'],
        'nozzle_number': p['nozzleNumber'],
        'attendant_id': p['attendantId'],
        'recorded_at': DateTime.now().toIso8601String(),
      };
      try {
        await client.from('credit_sales').insert(row);
      } on PostgrestException catch (e) {
        // Retried after a partial success - the row already exists.
        if (e.code != '23505') rethrow;
      }

      // The ledger balance lives in credit_customers - bump it so every
      // device (and every restart) sees the same outstanding amount.
      final customerId = p['customerId']?.toString();
      final amount = (p['totalAmount'] as num?)?.toDouble() ?? 0.0;
      if (customerId != null && amount != 0) {
        try {
          await client.rpc('app_add_credit_outstanding', params: {
            'p_customer_id': customerId,
            'p_delta': amount,
          });
        } catch (_) {
          // Best effort: the sale row above is the source of truth for audit.
        }
      }

      // Link requisition-slip evidence to this sale.
      final photos = p['evidencePhotos'];
      if (saleId != null && photos is List) {
        for (final url in photos.whereType<String>()) {
          try {
            await client.from('remittance_evidence').insert({
              'credit_sale_id': saleId,
              'storage_path': url,
              'payment_channel': 'credit_requisition',
              'created_at': DateTime.now().toIso8601String(),
            });
          } on PostgrestException catch (e) {
            if (e.code != '23505') rethrow;
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncFuelReturnPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      final returnId = p['id']?.toString();
      try {
        await client.from('fuel_returns').insert({
          if (returnId != null) 'id': returnId,
          'tank_id': p['tankCode'],
          'reason': p['reason'],
          'litres': p['litres'],
          'attendant_id': p['attendantId'],
          'status': 'verified',
        });
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }

      final photos = p['evidencePhotos'];
      if (returnId != null && photos is List) {
        for (final url in photos.whereType<String>()) {
          try {
            await client.from('remittance_evidence').insert({
              'fuel_return_id': returnId,
              'storage_path': url,
              'payment_channel': 'fuel_return_evidence',
              'created_at': DateTime.now().toIso8601String(),
            });
          } on PostgrestException catch (e) {
            if (e.code != '23505') rethrow;
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncDailyCashAuditPayload(Map<String, dynamic> p) async {
    return await recordDailyCashAuditPayload(p);
  }

  Future<bool> syncBranchExpensePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      // Upsert: create payloads carry full rows, approve/waive payloads are
      // {id, status, ...} updates — a plain insert would conflict on the PK.
      await client.from('branch_expenses').upsert(p, onConflict: 'id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncTankDipPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('tank_dips').insert(p);

      // Mirror the dip into the tanks read-model so every device's gauge
      // shows the fresh physical/book numbers after a restart.
      final tankCode = p['tank_id'] ?? p['tankCode'];
      if (tankCode != null) {
        await client.from('tanks').update({
          if (p['physical_dip_litres'] != null)
            'current_dip_litres': p['physical_dip_litres'],
          if (p['book_stock_litres'] != null)
            'calculated_stock_litres': p['book_stock_litres'],
        }).eq('code', tankCode);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncFuelDeliveryPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      try {
        await client.from('tank_deliveries').insert(p);
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }
      // Tank book-stock is persisted separately as an absolute value via
      // SyncActionType.tankStock (state enqueues it after every mutation).
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncPriceChangePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('fuel_prices').insert(p);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncSalaryAdjustmentPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      // Upsert: settlement creation inserts a full row; approve/waive queue
      // {id, status, ...} updates that must not conflict on the PK.
      await client.from('attendant_shortages').upsert(p, onConflict: 'id');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Per-shift shortage/excess adjustments live in the salary ledger table
  /// (attendant_salary_adjustments) - the table the ledger screen reads.
  Future<bool> syncShortageAdjustmentPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client
          .from('attendant_salary_adjustments')
          .upsert(_cleanPayload(p), onConflict: 'id');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Monthly payroll settlements (history + double-settlement guard).
  Future<List<MonthlyPayrollSettlement>> fetchPayrollSettlements() async {
    if (!_isConnected) return [];
    try {
      final data = await client
          .from('attendant_shortages')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
      return (data as List)
          .map((row) => MonthlyPayrollSettlement.fromJson(
              Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Remittances read back for the cashier verification queue: each row is
  /// returned raw (plus embedded profile name and evidence photos) so the
  /// state layer can map it onto ShiftSubmission.
  Future<List<Map<String, dynamic>>> fetchRemittanceRecords(
      {int limit = 30}) async {
    if (!_isConnected) return [];
    try {
      final data = await client
          .from('remittances')
          .select(
              '*, profiles!remittances_attendant_id_fkey(full_name, display_name), remittance_evidence(storage_path, payment_channel)')
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Credit repayment: decrements the customer's outstanding balance
  /// atomically (floors at zero, stamps last_payment_at).
  Future<bool> syncCreditRepaymentPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      final customerId = p['customerId']?.toString();
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      if (customerId == null || amount <= 0) return false;
      await client.rpc('app_add_credit_outstanding', params: {
        'p_customer_id': customerId,
        'p_delta': -amount,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncCreditCustomerCreatePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      final row = _cleanPayload(p);
      final stationCode = row.remove('station_code')?.toString();
      if (stationCode != null) {
        final uuid = await _resolveStationUuid(stationCode);
        if (uuid != null) row['station_id'] = uuid;
      }
      row.removeWhere((k, _) => k == 'product_code' || k == 'tank_code');
      await client.from('credit_customers').insert(row);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Onboard a credit customer directly (online path).
  Future<bool> createCreditCustomer({
    required String id,
    required String companyName,
    required String contactPerson,
    required int paymentTermsDays,
    required String stationCode,
  }) async {
    if (!_isConnected) return false;
    try {
      final stationUuid = await _resolveStationUuid(stationCode);
      await client.from('credit_customers').insert({
        'id': id,
        'company_name': companyName,
        'contact_person': contactPerson,
        'payment_terms_days': paymentTermsDays,
        'outstanding_balance': 0,
        'status': 'current',
        if (stationUuid != null) 'station_id': stationUuid,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncTankCreatePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      final row = _cleanPayload(p);
      final productCode = row.remove('product_code')?.toString();
      final stationCode = row.remove('station_code')?.toString();
      if (productCode != null) {
        final product = await client
            .from('fuel_products')
            .select('id')
            .ilike('code', productCode)
            .limit(1)
            .maybeSingle();
        if (product != null) row['fuel_product_id'] = product['id'];
      }
      if (stationCode != null) {
        final uuid = await _resolveStationUuid(stationCode);
        if (uuid != null) row['station_id'] = uuid;
      }
      await client.from('tanks').insert(row);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Add a tank from Station Setup (online path).
  Future<bool> createTank({
    required String id,
    required String code,
    required String productCode,
    required double capacityLitres,
    required double initialStockLitres,
    required String stationCode,
  }) async {
    if (!_isConnected) return false;
    try {
      final product = await client
          .from('fuel_products')
          .select('id')
          .ilike('code', productCode)
          .limit(1)
          .maybeSingle();
      final stationUuid = await _resolveStationUuid(stationCode);
      await client.from('tanks').insert({
        'id': id,
        'code': code,
        'name': '$productCode Tank $code',
        'capacity_litres': capacityLitres,
        'current_dip_litres': initialStockLitres,
        'calculated_stock_litres': initialStockLitres,
        'is_interlocked': false,
        if (product != null) 'fuel_product_id': product['id'],
        if (stationUuid != null) 'station_id': stationUuid,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncNozzleCreatePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      final row = _cleanPayload(p);
      final productCode = row.remove('product_code')?.toString();
      final tankCode = row.remove('tank_code')?.toString();
      final stationCode = row.remove('station_code')?.toString();
      if (productCode != null) {
        final product = await client
            .from('fuel_products')
            .select('id')
            .ilike('code', productCode)
            .limit(1)
            .maybeSingle();
        if (product != null) row['product_id'] = product['id'];
      }
      if (tankCode != null) {
        final tank = await client
            .from('tanks')
            .select('id')
            .eq('code', tankCode)
            .limit(1)
            .maybeSingle();
        if (tank != null) row['supplying_tank_id'] = tank['id'];
      }
      if (stationCode != null) {
        final uuid = await _resolveStationUuid(stationCode);
        if (uuid != null) row['station_id'] = uuid;
      }
      await client.from('nozzles').insert(row);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Add a pump nozzle from Station Setup (online path).
  Future<bool> createNozzle({
    required String id,
    required int nozzleNumber,
    required String productCode,
    required String tankCode,
    required double latestMeterReading,
    required String stationCode,
  }) async {
    if (!_isConnected) return false;
    try {
      final product = await client
          .from('fuel_products')
          .select('id')
          .ilike('code', productCode)
          .limit(1)
          .maybeSingle();
      final tank = await client
          .from('tanks')
          .select('id')
          .eq('code', tankCode)
          .limit(1)
          .maybeSingle();
      final stationUuid = await _resolveStationUuid(stationCode);
      await client.from('nozzles').insert({
        'id': id,
        'nozzle_number': nozzleNumber,
        'latest_meter_reading': latestMeterReading,
        if (product != null) 'product_id': product['id'],
        if (tank != null) 'supplying_tank_id': tank['id'],
        if (stationUuid != null) 'station_id': stationUuid,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Absolute tank book-stock/physical-dip sync (state enqueues after every
  /// stock mutation so all devices converge on the same numbers).
  Future<bool> syncTankStockPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      final tankCode = p['tankCode']?.toString();
      if (tankCode == null) return false;
      await client.from('tanks').update({
        if (p['bookStock'] != null)
          'calculated_stock_litres': (p['bookStock'] as num).toDouble(),
        if (p['physicalDip'] != null)
          'current_dip_litres': (p['physicalDip'] as num).toDouble(),
      }).eq('code', tankCode);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncNotificationPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      try {
        await client.from('app_notifications').insert(_cleanPayload(p));
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Operational notifications read back after a restart.
  Future<List<ForecourtNotification>> fetchNotifications({int limit = 50}) async {
    if (!_isConnected) return [];
    try {
      final data = await client
          .from('app_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((row) {
        final m = Map<String, dynamic>.from(row as Map);
        return ForecourtNotification(
          id: (m['id'] as String?) ?? generateUuid(),
          title: (m['title'] as String?) ?? '',
          message: (m['message'] as String?) ?? '',
          type: notificationTypeFromString(m['type'] as String?),
          timestamp: DateTime.tryParse(m['created_at'] as String? ?? '') ??
              DateTime.now(),
          targetRole: m['target_role'] != null
              ? _roleFromString(m['target_role'] as String)
              : null,
          actionRouteName: m['action_route'] as String?,
          isRead: m['is_read'] == true,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static NotificationType notificationTypeFromString(String? raw) {
    switch (raw) {
      case 'success':
        return NotificationType.success;
      case 'warning':
        return NotificationType.warning;
      case 'critical':
        return NotificationType.critical;
      default:
        return NotificationType.info;
    }
  }

  static UserRole? _roleFromString(String raw) {
    switch (raw) {
      case 'attendant':
        return UserRole.attendant;
      case 'cashier':
        return UserRole.cashier;
      case 'manager':
        return UserRole.manager;
      case 'director':
        return UserRole.director;
      default:
        return null;
    }
  }

  /// Persist the shift session row (the shared shift id every payload uses).
  Future<bool> syncShiftSessionPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      // shifts.station_id is text after the migration (station code).
      try {
        await client.from('shifts').insert(_cleanPayload(p));
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // same shift already opened
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncBankDepositRecordPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      final row = _cleanPayload(p);
      final sid = row['station_id']?.toString();
      if (sid == null) return false;
      // bank_deposits.station_id stays a uuid FK — resolve the code first.
      final stationUuid = await _resolveStationUuid(sid);
      if (stationUuid == null) return false;
      row['station_id'] = stationUuid;

      await client.from('bank_deposits').insert(row);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncInterimCashDropPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      // station_id / shift_id are text (station code, 'SHIFT-...' ids).
      await client.from('interim_cash_drops').insert(_cleanPayload(p));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncPosTransactionPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      // station_id / shift_id are text (station code, 'SHIFT-...' ids).
      await client.from('shift_pos_transactions').insert(_cleanPayload(p));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncBankDepositPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('bank_deposits').update({
        'is_confirmed': true,
        'confirmed_at': p['confirmed_at'] ?? DateTime.now().toIso8601String(),
        if (p['director_notes'] != null) 'director_notes': p['director_notes'],
      }).eq('id', p['id']);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncEvidencePhotoPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      String? storagePath = p['path']?.toString();
      final bucket = p['bucket']?.toString() ?? 'remittance-evidence';
      final b64 = p['imageBase64']?.toString();

      // Real upload of the queued image bytes — no metadata-only records
      if (b64 == null || b64.isEmpty || storagePath == null) return false;
      final uploadedUrl = await uploadStorageFile(
        bucket: bucket,
        path: storagePath,
        fileBytes: base64Decode(b64),
      );
      if (uploadedUrl == null) return false; // keep queued, retry later
      storagePath = uploadedUrl;

      await client.from('remittance_evidence').insert({
        'storage_path': storagePath,
        'payment_channel': p['payment_channel'] ?? 'pos_slip',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SUPABASE STORAGE UPLOADS (PHASE 3)
  // ---------------------------------------------------------------------------

  Future<String?> uploadStorageFile({
    required String bucket,
    required String path,
    required Uint8List fileBytes,
  }) async {
    if (!_isConnected) return null;

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );

      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }
}
