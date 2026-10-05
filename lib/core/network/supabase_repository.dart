import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/credit_customer.dart';
import '../../models/interim_cash_drop.dart';
import '../../models/nozzle.dart';
import '../../models/pos_transaction.dart';
import '../../models/station.dart';
import '../../models/user_profile.dart';
import '../config/supabase_config.dart';

class SupabaseRepository {
  static final SupabaseRepository instance = SupabaseRepository._internal();
  SupabaseRepository._internal();

  SupabaseClient? _client;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  /// Initialize Supabase connection
  Future<bool> initialize() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
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
      return {'success': true, 'message': 'Demo offline validation'};
    }

    try {
      final res = await client.rpc('attendant_pin_login', params: {
        'p_station_id': stationId,
        'p_profile_id': profileId,
        'p_pin': pin,
      });
      return Map<String, dynamic>.from(res as Map);
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
          await client.from('shift_nozzle_assignments').upsert({
            'shift_id': shiftId,
            'nozzle_id': n.nozzleNumber,
            'opening_reading': n.openingReading,
            'closing_reading': n.closingReading,
            'price_per_litre': n.pricePerLitre,
            'submitted_at': DateTime.now().toIso8601String(),
          });
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
        id: 'drop-${DateTime.now().millisecondsSinceEpoch}',
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
        id: 'pos-${DateTime.now().millisecondsSinceEpoch}',
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

  Future<bool> recordDailyCashAudit({
    required String stationId,
    required String cashierId,
    required double openingCash,
    required double cashReceipts,
    required double cashExpenses,
    required double handedOver,
    required double countedCash,
    required Map<int, int> denominations,
  }) async {
    if (!_isConnected) return true;

    try {
      final expected = openingCash + cashReceipts - cashExpenses - handedOver;
      await client.from('daily_cash_counts').insert({
        'station_id': stationId,
        'cashier_id': cashierId,
        'opening_cash': openingCash,
        'cash_receipts': cashReceipts,
        'cash_expenses': cashExpenses,
        'handed_over_for_deposit': handedOver,
        'expected_closing_cash': expected,
        'physical_total_counted': countedCash,
        'count_1000': denominations[1000] ?? 0,
        'count_500': denominations[500] ?? 0,
        'count_200': denominations[200] ?? 0,
        'count_100': denominations[100] ?? 0,
        'count_50': denominations[50] ?? 0,
        'count_20': denominations[20] ?? 0,
        'count_10': denominations[10] ?? 0,
        'deposit_status': 'awaiting_bank',
      });
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
      final data = await client.from('credit_customers').select().order('company_name');
      return (data as List).map((row) {
        return CreditCustomer(
          id: row['id'] as String,
          name: row['company_name'] as String,
          outstanding: (row['outstanding_balance'] as num).toDouble(),
          lastRepayment: 'Recent',
          dueDate: '${row['payment_terms_days']} days',
          status: row['status'] == 'overdue' ? CustomerCreditStatus.overdue : CustomerCreditStatus.current,
        );
      }).toList();
    } catch (e) {
      return CreditCustomer.getDefaultCustomers();
    }
  }

  Future<Map<String, double>> fetchLivePrices(String stationId) async {
    if (!_isConnected) return {'PMS': 1050.0, 'AGO': 1320.0};
    try {
      final data = await client
          .from('fuel_prices')
          .select('product_id, price_per_litre, fuel_products(code)')
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
      final data = await client
          .from('tanks')
          .select('id, code, capacity_litres, current_dip_litres, calculated_stock_litres, is_interlocked, fuel_products(code)')
          .order('code');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveNozzles(String stationId) async {
    if (!_isConnected) return [];
    try {
      final data = await client
          .from('nozzles')
          .select('id, nozzle_number, latest_meter_reading, supplying_tank_id, tanks(id, code), fuel_products(code)')
          .order('nozzle_number');
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
      final data = await client
          .from('expenses')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveSalaryAdjustments(String stationId) async {
    if (!_isConnected) return [];
    try {
      final data = await client
          .from('attendant_salary_adjustments')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
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
      for (final r in readings) {
        await client.from('shift_nozzle_assignments').upsert({
          'shift_id': shiftId,
          'nozzle_id': r['nozzleNumber'],
          'opening_reading': r['openingReading'],
          'closing_reading': r['closingReading'],
          'price_per_litre': r['pricePerLitre'],
          'submitted_at': DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncRemittancePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('remittances').insert({
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
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncCreditSalePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('credit_sales').insert({
        'customer_id': p['customerId'],
        'driver_name': p['driverName'],
        'vehicle_reg': p['vehicleReg'],
        'litres': p['litres'],
        'total_amount': p['totalAmount'],
        'recorded_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncFuelReturnPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('fuel_returns').insert({
        'tank_id': p['tankCode'],
        'reason': p['reason'],
        'litres': p['litres'],
        'attendant_id': p['attendantId'],
        'status': 'verified',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncDailyCashAuditPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('daily_cash_counts').insert(p);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncBranchExpensePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('branch_expenses').insert(p);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncTankDipPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('tank_dips').insert(p);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncFuelDeliveryPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('tank_deliveries').insert(p);
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
      await client.from('attendant_shortages').insert(p);
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
        'confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', p['id']);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncEvidencePhotoPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return true;
    try {
      await client.from('remittance_evidence').insert({
        'storage_path': p['path'],
        'payment_channel': 'pos_slip',
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
