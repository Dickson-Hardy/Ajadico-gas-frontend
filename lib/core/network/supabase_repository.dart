import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/credit_customer.dart';
import '../../models/nozzle.dart';
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

  Future<List<UserProfile>> fetchStationStaff(String stationId) async {
    if (!_isConnected) return UserProfile.demoStaff;

    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('station_id', stationId)
          .eq('is_active', true);

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
            role = UserRole.director;
            break;
          default:
            role = UserRole.attendant;
        }

        return UserProfile(
          id: row['id'] as String,
          displayName: row['display_name'] as String,
          fullName: row['full_name'] as String,
          role: role,
          stationName: 'Lekki Road Station',
        );
      }).toList();
    } catch (e) {
      return UserProfile.demoStaff;
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
    if (!_isConnected) return CreditCustomer.getDemoCustomers();

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
      return CreditCustomer.getDemoCustomers();
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
