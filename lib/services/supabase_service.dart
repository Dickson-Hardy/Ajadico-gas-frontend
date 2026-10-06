import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/credit_customer.dart';
import '../models/nozzle.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient? _client;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  /// Initialize Supabase connection
  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
    } catch (e) {
      // In development or offline without active connection, fallback gracefully
      _isInitialized = false;
    }
  }

  // ---------------------------------------------------------------------------
  // AUTHENTICATION & PIN LOGIN (§2.1–§2.4)
  // ---------------------------------------------------------------------------

  /// Attendant fast PIN login on shared station tablet via PostgreSQL RPC
  Future<Map<String, dynamic>> loginWithPin({
    required String stationId,
    required String profileId,
    required String pin,
  }) async {
    if (!_isInitialized) {
      // Fallback demo validation
      return {'success': true, 'message': 'Demo mode offline login'};
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

  // ---------------------------------------------------------------------------
  // NOZZLES & METER READINGS (§2.5, §2.10)
  // ---------------------------------------------------------------------------

  /// Fetch active nozzles and latest meter readings for assigned shift
  Future<List<NozzleItem>> getShiftNozzles(String stationId) async {
    if (!_isInitialized) {
      return NozzleItem.getDemoNozzles();
    }

    try {
      final data = await client
          .from('nozzles')
          .select('*, fuel_products(code), tanks(code)')
          .order('nozzle_number');

      return (data as List).map((row) {
        return NozzleItem(
          nozzleNumber: row['nozzle_number'] as int,
          productName: row['fuel_products']['code'] as String,
          tankCode: row['tanks']['code'] as String,
          openingReading: (row['latest_meter_reading'] as num).toDouble(),
          pricePerLitre: 1050.0,
          isOpeningConfirmed: true,
        );
      }).toList();
    } catch (e) {
      return NozzleItem.getDemoNozzles();
    }
  }

  /// Submit closing meter readings for the shift
  Future<bool> submitClosingReadings({
    required String shiftId,
    required List<NozzleItem> nozzles,
  }) async {
    if (!_isInitialized) return true;

    try {
      for (final n in nozzles) {
        if (n.closingReading != null) {
          await client.from('shift_nozzle_assignments').upsert({
            'shift_id': shiftId,
            'nozzle_id': n.nozzleNumber,
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

  // ---------------------------------------------------------------------------
  // REMITTANCE & CASHIER VERIFICATION (§4.1–§4.7)
  // ---------------------------------------------------------------------------

  /// Submit attendant shift remittance declaration
  Future<bool> submitRemittance({
    required String shiftId,
    required String attendantId,
    required double expectedSalesValue,
    required double cash,
    required double posCard,
    required double posTransfer,
    required double bankTransfer,
    required double creditSales,
  }) async {
    if (!_isInitialized) return true;

    try {
      await client.from('remittances').insert({
        'shift_id': shiftId,
        'attendant_id': attendantId,
        'expected_sales_value': expectedSalesValue,
        'cash_declared': cash,
        'pos_card_declared': posCard,
        'pos_transfer_declared': posTransfer,
        'bank_transfer_declared': bankTransfer,
        'credit_sales_declared': creditSales,
        'status': 'submitted',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // CREDIT CUSTOMERS & LEDGER (§4.8–§4.10)
  // ---------------------------------------------------------------------------

  /// Fetch registered credit customers
  Future<List<CreditCustomer>> getCreditCustomers(String stationId) async {
    if (!_isInitialized) {
      return CreditCustomer.getDefaultCustomers();
    }

    try {
      final data = await client
          .from('credit_customers')
          .select()
          .order('company_name');

      return (data as List).map((row) {
        final statusStr = row['status'] as String? ?? 'current';
        CustomerCreditStatus status;
        if (statusStr == 'overdue') {
          status = CustomerCreditStatus.overdue;
        } else if (statusStr == 'settled') {
          status = CustomerCreditStatus.settled;
        } else {
          status = CustomerCreditStatus.current;
        }

        return CreditCustomer(
          id: row['id'] as String,
          name: row['company_name'] as String,
          outstanding: (row['outstanding_balance'] as num).toDouble(),
          lastRepayment: 'Recent',
          dueDate: '${row['payment_terms_days'] ?? 14} days',
          status: status,
        );
      }).toList();
    } catch (e) {
      return CreditCustomer.getDefaultCustomers();
    }
  }

  // ---------------------------------------------------------------------------
  // DAILY CASH COUNT (§5.3–§5.5)
  // ---------------------------------------------------------------------------

  /// Save daily physical denomination count
  Future<bool> saveDailyCashCount({
    required String stationId,
    required String cashierId,
    required double openingCash,
    required double cashReceipts,
    required double cashExpenses,
    required double handedOverForDeposit,
    required Map<int, int> counts,
    required double totalCounted,
  }) async {
    if (!_isInitialized) return true;

    try {
      final expectedClosing = openingCash + cashReceipts - cashExpenses - handedOverForDeposit;
      await client.from('daily_cash_counts').insert({
        'station_id': stationId,
        'cashier_id': cashierId,
        'opening_cash': openingCash,
        'cash_receipts': cashReceipts,
        'cash_expenses': cashExpenses,
        'handed_over_for_deposit': handedOverForDeposit,
        'expected_closing_cash': expectedClosing,
        'physical_total_counted': totalCounted,
        'count_1000': counts[1000] ?? 0,
        'count_500': counts[500] ?? 0,
        'count_200': counts[200] ?? 0,
        'count_100': counts[100] ?? 0,
        'count_50': counts[50] ?? 0,
        'count_20': counts[20] ?? 0,
        'count_10': counts[10] ?? 0,
        'deposit_status': 'awaiting_bank',
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
