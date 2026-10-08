import 'package:flutter/material.dart';
import '../core/network/supabase_repository.dart';
import '../core/notifications/forecourt_notification.dart';
import '../core/notifications/notification_service.dart';
import '../core/offline/offline_sync_service.dart';
import '../core/offline/sync_queue_item.dart';
import '../core/utils/currency_formatter.dart';
import '../models/bank_deposit.dart';
import '../models/credit_customer.dart';
import '../models/interim_cash_drop.dart';
import '../models/monthly_payroll_settlement.dart';
import '../models/nozzle.dart';
import '../models/pos_transaction.dart';
import '../models/station.dart';
import '../models/user_profile.dart';

/// Models for real-time forecourt operations
class ShiftSubmission {
  final String id;
  final String shiftId;
  final String attendantName;
  final String attendantId;
  final String shiftType; // 'Morning' or 'Evening'
  final DateTime submittedAt;
  final List<NozzleItem> nozzles;
  final double expectedSalesValue;
  final double cashDeclared;
  final double posCardDeclared;
  final double posTransferDeclared;
  final double bankTransferDeclared;
  final double creditSalesDeclared;
  final List<String> evidencePhotos;
  final List<InterimCashDrop> cashDrops;
  final List<PosTransaction> posTransactions;
  final double finalCashHandover;
  String status; // 'Pending Verification', 'Verified', 'Flagged Unresolved'
  String? cashierComment;
  DateTime? verifiedAt;

  ShiftSubmission({
    required String id,
    String? shiftId,
    required this.attendantName,
    required this.attendantId,
    required this.shiftType,
    required this.submittedAt,
    required this.nozzles,
    required this.expectedSalesValue,
    required this.cashDeclared,
    required this.posCardDeclared,
    required this.posTransferDeclared,
    required this.bankTransferDeclared,
    required this.creditSalesDeclared,
    required this.evidencePhotos,
    this.cashDrops = const [],
    this.posTransactions = const [],
    this.finalCashHandover = 0.0,
    this.status = 'Pending Verification',
    this.cashierComment,
    this.verifiedAt,
  }) : id = id, shiftId = shiftId ?? id;

  double get totalMoneyDeclared =>
      cashDeclared + posCardDeclared + posTransferDeclared + bankTransferDeclared;

  double get variance =>
      (totalMoneyDeclared + creditSalesDeclared) - expectedSalesValue;

  bool get isBalanced => variance.abs() < 1.0;
  bool get isShortage => variance < -1.0;
}

class LiveTankStock {
  final String code;
  final String product;
  final double capacity;
  double bookStock;
  double physicalDip;
  DateTime lastDipTime;
  bool isInterlocked;
  bool isActiveSupply;

  LiveTankStock({
    required this.code,
    required this.product,
    required this.capacity,
    required this.bookStock,
    required this.physicalDip,
    required this.lastDipTime,
    this.isInterlocked = false,
    this.isActiveSupply = true,
  });

  double get variance => physicalDip - bookStock;
  double get variancePercent => (bookStock > 0) ? (variance / bookStock) * 100 : 0.0;
  bool get hasDeficit => variance < -50.0;
  bool get isLowStock => physicalDip < (capacity * 0.20);
}

class BranchExpense {
  final String id;
  final String category;
  final double amount;
  final String paymentSource; // 'Cash Drawer' or 'Direct Bank Transfer'
  final String description;
  final String recordedBy;
  final String recordedByRole; // 'cashier', 'manager', 'director'
  String status; // 'Approved', 'Pending Approval', 'Rejected'
  String? approvedBy;
  DateTime? approvedAt;
  final String? receiptUrl;
  final DateTime recordedAt;

  BranchExpense({
    required this.id,
    required this.category,
    required this.amount,
    required this.paymentSource,
    required this.description,
    required this.recordedBy,
    this.recordedByRole = 'manager',
    this.status = 'Approved',
    this.approvedBy,
    this.approvedAt,
    this.receiptUrl,
    required this.recordedAt,
  });

  bool get isApproved => status == 'Approved';
  bool get isPending => status == 'Pending Approval';
  bool get isRejected => status == 'Rejected';
}

class FuelDeliveryRecord {
  final String id;
  final String tankCode;
  final String supplier;
  final String waybillNumber;
  final double statedLitres;
  final double dipBefore;
  final double dipAfter;
  final double receivedLitres;
  final double discrepancy;
  final double purchasePricePerLitre;
  final DateTime deliveredAt;

  FuelDeliveryRecord({
    required this.id,
    required this.tankCode,
    required this.supplier,
    required this.waybillNumber,
    required this.statedLitres,
    required this.dipBefore,
    required this.dipAfter,
    required this.receivedLitres,
    required this.discrepancy,
    required this.purchasePricePerLitre,
    required this.deliveredAt,
  });
}

class SalaryAdjustment {
  final String id;
  final String attendantName;
  final String station;
  final String shiftRef;
  final double amount; // negative for shortage
  String status; // 'Pending Review', 'Salary Deduction Approved', 'Waived by Director'
  final DateTime recordedAt;

  SalaryAdjustment({
    required this.id,
    required this.attendantName,
    required this.station,
    required this.shiftRef,
    required this.amount,
    this.status = 'Pending Review',
    required this.recordedAt,
  });
}

class ShiftCreditSaleRecord {
  final String id;
  final String attendantId;
  final String customerId;
  final String customerName;
  final int nozzleNumber;
  final double litres;
  final double amount;
  final String vehiclePlate;
  final String driverName;
  final DateTime recordedAt;

  ShiftCreditSaleRecord({
    required this.id,
    required this.attendantId,
    required this.customerId,
    required this.customerName,
    required this.nozzleNumber,
    required this.litres,
    required this.amount,
    required this.vehiclePlate,
    required this.driverName,
    required this.recordedAt,
  });
}

/// Central Reactive State Store for the entire Filling Station System
/// Integrates with OfflineSyncService (Phase 2), Camera (Phase 3), and Kiosk (Phase 4)
class StationAppState extends ChangeNotifier {
  static final StationAppState instance = StationAppState._internal();
  StationAppState._internal() {
    _initDefaultState();
    _wireNotificationPersistence();
  }

  final _syncService = OfflineSyncService.instance;
  final _notifService = NotificationService.instance;

  // 1. Current Session
  UserProfile _currentUser = UserProfile.defaultDirector;
  UserProfile get currentUser => _currentUser;

  void setCurrentUser(UserProfile user) {
    _currentUser = user;
    if (user.role == UserRole.attendant) {
      openShiftSession();
    }
    notifyListeners();
  }

  // 1d. Shift Session (one shared id per attendant session — closing
  // readings, remittance, drops and POS all reference it)
  String? _currentShiftId;
  bool _shiftSessionRowCreated = false;

  String get currentShiftId =>
      _currentShiftId ??= SupabaseRepository.instance.generateUuid();

  String _shiftTypeNow() => DateTime.now().hour < 14 ? 'Morning' : 'Evening';

  /// Queue the shift_sessions row once per opened session
  void openShiftSession() {
    if (_shiftSessionRowCreated) return;
    _shiftSessionRowCreated = true;
    _syncService.enqueue(
      actionType: SyncActionType.shiftSession,
      payload: {
        'id': currentShiftId,
        'station_id': _currentStationCode,
        'attendant_id': _currentUser.id,
        'shift_type': _shiftTypeNow(),
        'status': 'open',
        'opened_at': DateTime.now().toIso8601String(),
      },
    );
  }

  bool _notifPersistenceWired = false;

  /// Persist every posted notification through the offline outbox (A4)
  void _wireNotificationPersistence() {
    if (_notifPersistenceWired) return;
    _notifPersistenceWired = true;
    _notifService.onPosted = (n) {
      _syncService.enqueue(
        actionType: SyncActionType.notification,
        payload: {
          'id': n.id,
          'title': n.title,
          'message': n.message,
          'type': n.type.name,
          'target_role': n.targetRole?.name,
          'action_route': n.actionRouteName,
          'is_read': n.isRead,
          'created_at': n.timestamp.toIso8601String(),
        },
      );
    };
  }

  // 1c. Forecourt Theme Mode (Night Shift / Sunlight Mode)
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // 1b. Attendant shift progress (drives home checklist & flow ordering)
  bool _closingReadingsSubmitted = false;
  bool get closingReadingsSubmitted => _closingReadingsSubmitted;
  bool _remittanceSubmitted = false;
  bool get remittanceSubmitted => _remittanceSubmitted;

  void markClosingReadingsSubmitted() {
    _closingReadingsSubmitted = true;
    notifyListeners();
  }

  void markRemittanceSubmitted() {
    _remittanceSubmitted = true;
    notifyListeners();
  }

  void resetShiftProgress() {
    _closingReadingsSubmitted = false;
    _remittanceSubmitted = false;
    notifyListeners();
  }

  // 2. Active Fuel Prices
  double _pmsPrice = 1050.0;
  double _agoPrice = 1320.0;
  double get pmsPrice => _pmsPrice;
  double get agoPrice => _agoPrice;

  // Station Infrastructure Configuration (§1, §3.1)
  List<Station> _stations = [];
  List<Station> get stations => List.unmodifiable(_stations);

  String _currentStationId = '4c960eed-2f2e-461a-a27e-00a41f5f7bd1';
  String get currentStationId => _currentStationId;
  String _currentStationCode = 'LEKKI-01';
  String get currentStationCode => _currentStationCode;
  String _currentStationName = 'Lekki Road Station';
  String get currentStationName => _currentStationName;
  bool _hasInterlockedTanks = true;
  bool get hasInterlockedTanks => _hasInterlockedTanks;

  // 3. Live Nozzles for Forecourt
  late List<NozzleItem> _nozzles;
  List<NozzleItem> get nozzles => _nozzles;

  // 4. Live Tanks
  late List<LiveTankStock> _tanks;
  List<LiveTankStock> get tanks => _tanks;

  // 5. Shift Submissions Queue (for Cashier & Manager)
  final List<ShiftSubmission> _submissions = [];
  List<ShiftSubmission> get submissions => List.unmodifiable(_submissions);

  // 6. Registered Credit Customers & Sales
  late List<CreditCustomer> _creditCustomers;
  List<CreditCustomer> get creditCustomers => _creditCustomers;

  // 7. Branch Expenses
  final List<BranchExpense> _expenses = [];
  List<BranchExpense> get expenses => List.unmodifiable(_expenses);

  // 8. Deliveries
  final List<FuelDeliveryRecord> _deliveries = [];
  List<FuelDeliveryRecord> get deliveries => List.unmodifiable(_deliveries);

  // 9. Attendant Salary Ledger
  final List<SalaryAdjustment> _salaryAdjustments = [];
  List<SalaryAdjustment> get salaryAdjustments => List.unmodifiable(_salaryAdjustments);

  // 9b. Monthly Payroll Settlements (§4.7)
  final List<MonthlyPayrollSettlement> _payrollSettlements = [];
  List<MonthlyPayrollSettlement> get payrollSettlements => List.unmodifiable(_payrollSettlements);

  // 10. Bank Deposits
  final List<BankDepositRecord> _deposits = [];
  List<BankDepositRecord> get deposits => List.unmodifiable(_deposits);

  // 11. Staff & Attendants (§2.1–§2.4)
  List<UserProfile> _staff = [];
  List<UserProfile> get staff => List.unmodifiable(_staff);

  // 12. Intra-Shift Cash Drops & POS Transactions (§2.6, §4.1, §4.4)
  final List<InterimCashDrop> _cashDrops = [];
  List<InterimCashDrop> get cashDrops => List.unmodifiable(_cashDrops);

  final List<PosTransaction> _posTransactions = [];
  List<PosTransaction> get posTransactions => List.unmodifiable(_posTransactions);

  // 13. Intra-Shift Credit Sales Records (§4.8)
  final List<ShiftCreditSaleRecord> _creditSalesRecords = [];
  List<ShiftCreditSaleRecord> get creditSalesRecords => List.unmodifiable(_creditSalesRecords);

  /// Total Credit Sales logged by attendant
  double totalAttendantCreditSales([String? attendantId]) {
    final targetId = attendantId ?? _currentUser.id;
    return _creditSalesRecords
        .where((c) => c.attendantId == targetId)
        .fold(0.0, (sum, c) => sum + c.amount);
  }

  /// Total acknowledged cash drops for an attendant
  double totalAttendantAcknowledgedDrops([String? attendantId]) {
    final targetId = attendantId ?? _currentUser.id;
    return _cashDrops
        .where((d) => d.attendantId == targetId && d.isAcknowledged)
        .fold(0.0, (sum, d) => sum + d.amount);
  }

  /// Total pending cash drops awaiting Cashier acknowledgement
  double totalAttendantPendingDrops([String? attendantId]) {
    final targetId = attendantId ?? _currentUser.id;
    return _cashDrops
        .where((d) => d.attendantId == targetId && !d.isAcknowledged)
        .fold(0.0, (sum, d) => sum + d.amount);
  }

  /// Total POS Card transactions logged by attendant
  double totalAttendantPosCard([String? attendantId]) {
    final targetId = attendantId ?? _currentUser.id;
    return _posTransactions
        .where((p) => p.attendantId == targetId && p.paymentChannel == 'pos_card')
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  /// Total POS Transfer transactions logged by attendant
  double totalAttendantPosTransfer([String? attendantId]) {
    final targetId = attendantId ?? _currentUser.id;
    return _posTransactions
        .where((p) => p.attendantId == targetId && p.paymentChannel == 'pos_transfer')
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  /// Total Bank Transfer transactions logged by attendant
  double totalAttendantBankTransfer([String? attendantId]) {
    final targetId = attendantId ?? _currentUser.id;
    return _posTransactions
        .where((p) => p.attendantId == targetId && p.paymentChannel == 'bank_transfer')
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  /// Total current forecourt sales value across active nozzles
  double get currentForecourtSalesValue {
    return _nozzles.fold(0.0, (sum, n) => sum + n.salesValue);
  }

  /// Live estimated cash in attendant's pouch
  double get attendantEstimatedCashInPouch {
    final sales = currentForecourtSalesValue;
    final drops = totalAttendantAcknowledgedDrops() + totalAttendantPendingDrops();
    final nonCash = totalAttendantPosCard() +
        totalAttendantPosTransfer() +
        totalAttendantBankTransfer() +
        totalAttendantCreditSales();
    final balance = sales - (drops + nonCash);
    return balance > 0 ? balance : 0.0;
  }

  // 13. Daily Cash Drawer State
  double _openingCash = 0.0;
  double get openingCash => _openingCash;

  final Map<int, int> _cashCounts = {
    1000: 0,
    500: 0,
    200: 0,
    100: 0,
    50: 0,
    20: 0,
    10: 0,
  };
  Map<int, int> get cashCounts => Map.unmodifiable(_cashCounts);

  void _initDefaultState() {
    // Zero demo data: every live collection starts empty and is populated
    // exclusively from Supabase (see syncWithSupabase). Offline, the app
    // shows honest empty states instead of fabricated stations/meters/staff.
    _nozzles = [];
    _tanks = [];
    _creditCustomers = [];
    _staff = [];
  }

  bool _isSyncingWithRemote = false;
  bool get isSyncingWithRemote => _isSyncingWithRemote;

  /// Pull real-time master data & live records directly from Supabase PostgREST
  Future<void> syncWithSupabase() async {
    final repo = SupabaseRepository.instance;
    if (!repo.isConnected) return;

    _isSyncingWithRemote = true;
    notifyListeners();

    try {
      // 0. Fetch all active stations (§1, §2.1)
      final remoteStations = await repo.fetchAllStations();
      if (remoteStations.isNotEmpty) {
        _stations = remoteStations;
        final match = _stations.firstWhere(
          (s) => s.code.toUpperCase() == _currentStationCode.toUpperCase(),
          orElse: () => _stations.first,
        );
        _currentStationId = match.id;
        _currentStationCode = match.code;
        _currentStationName = match.name;
        _hasInterlockedTanks = match.hasInterlockedTanks;
      }

      final stationInfo = await repo.fetchStationInfo(_currentStationCode);
      if (stationInfo != null) {
        if (stationInfo['id'] != null) _currentStationId = stationInfo['id'];
        _hasInterlockedTanks = stationInfo['has_interlocked_tanks'] ?? false;
        _currentStationName = stationInfo['name'] ?? _currentStationName;
      }

      // 1. Fetch live fuel prices
      final prices = await repo.fetchLivePrices(_currentStationCode);
      if (prices.containsKey('PMS')) _pmsPrice = prices['PMS']!;
      if (prices.containsKey('AGO')) _agoPrice = prices['AGO']!;

      // 2. Fetch live tanks
      final remoteTanks = await repo.fetchLiveTanks(_currentStationCode);
      if (remoteTanks.isNotEmpty) {
        _tanks = remoteTanks.map((r) {
          final prodMap = r['fuel_products'] as Map?;
          final prod = prodMap?['code'] ?? 'PMS';
          final code = r['code'] as String;
          final isInterlocked = r['is_interlocked'] == true;
          return LiveTankStock(
            code: code,
            product: prod as String,
            capacity: (r['capacity_litres'] as num).toDouble(),
            bookStock: (r['calculated_stock_litres'] as num).toDouble(),
            physicalDip: (r['current_dip_litres'] as num).toDouble(),
            lastDipTime: DateTime.now(),
            isInterlocked: isInterlocked,
            isActiveSupply: true,
          );
        }).toList();
      }

      // 3. Fetch live nozzles & reconcile active supply
      final remoteNozzles = await repo.fetchLiveNozzles(_currentStationCode);
      if (remoteNozzles.isNotEmpty) {
        final activeTankCodes = <String>{};
        _nozzles = remoteNozzles.map((r) {
          final prodMap = r['fuel_products'] as Map?;
          final prod = prodMap?['code'] ?? 'PMS';
          final tankMap = r['tanks'] as Map?;
          final tankCode = tankMap?['code'] ?? 'T1';
          activeTankCodes.add(tankCode);
          final numVal = r['nozzle_number'] as int;
          final price = prod == 'PMS' ? _pmsPrice : _agoPrice;

          return NozzleItem(
            nozzleNumber: numVal,
            productName: prod as String,
            tankCode: tankCode as String,
            openingReading: (r['latest_meter_reading'] as num).toDouble(),
            pricePerLitre: price,
            isOpeningConfirmed: false,
          );
        }).toList();

        // Reconcile active supply on interlocked tanks
        for (final t in _tanks) {
          t.isActiveSupply = activeTankCodes.contains(t.code);
        }
      }

      // 4. Fetch live credit customers
      final remoteCustomers = await repo.fetchCreditLedger(_currentStationCode);
      if (remoteCustomers.isNotEmpty) {
        _creditCustomers = remoteCustomers;
      }

      // 5. Fetch live expenses
      final remoteExpenses = await repo.fetchLiveExpenses(_currentStationCode);
      _expenses.clear();
      for (final e in remoteExpenses) {
        _expenses.add(
          BranchExpense(
            id: e['id'] as String,
            category: e['category'] as String,
            amount: (e['amount'] as num).toDouble(),
            paymentSource: e['payment_source'] ?? 'Cash Drawer',
            description: e['description'] ?? '',
            recordedBy: e['recorded_by_name'] ?? 'Branch Staff',
            recordedByRole: e['recorded_by_role'] ?? 'manager',
            status: e['status'] ?? 'Approved',
            approvedBy: e['approved_by_name'],
            approvedAt: e['approved_at'] != null ? DateTime.tryParse(e['approved_at']) : null,
            receiptUrl: e['receipt_url'],
            recordedAt: DateTime.tryParse(e['created_at'] ?? '') ?? DateTime.now(),
          ),
        );
      }

      // 6. Fetch live salary adjustments
      final remoteSalary = await repo.fetchLiveSalaryAdjustments(_currentStationCode);
      _salaryAdjustments.clear();
      for (final s in remoteSalary) {
        _salaryAdjustments.add(
          SalaryAdjustment(
            id: s['id'] as String,
            attendantName: s['attendant_name'] ?? 'Attendant',
            station: s['station_name'] ?? _currentStationName,
            shiftRef: s['shift_ref'] ?? 'Shift',
            amount: (s['amount'] as num).toDouble(),
            status: s['status'] ?? 'Pending Review',
            recordedAt: DateTime.tryParse(s['created_at'] ?? '') ?? DateTime.now(),
          ),
        );
      }

      // 7. Fetch live staff profiles (§2.1–§2.4)
      final remoteStaff = await repo.fetchStationStaff(_currentStationCode);
      if (remoteStaff.isNotEmpty) {
        _staff = remoteStaff;
      }

      // 8. Fetch live interim cash drops (§2.6)
      final remoteDrops = await repo.fetchInterimCashDrops(_currentStationCode);
      _cashDrops.clear();
      _cashDrops.addAll(remoteDrops);

      // 9. Fetch live in-between POS & bank transfer sales (§4.4)
      final remotePos = await repo.fetchShiftPosTransactions(_currentStationCode);
      _posTransactions.clear();
      _posTransactions.addAll(remotePos);

      // 10. Fetch live bank deposits (§4.3, §5.5)
      final remoteDeposits = await repo.fetchBankDeposits(_currentStationCode);
      _deposits.clear();
      _deposits.addAll(remoteDeposits);

      // 11. Fetch remittances read back for the cashier verification queue
      final remoteRemittances = await repo.fetchRemittanceRecords();
      final mergedRemittances = <ShiftSubmission>[];
      for (final row in remoteRemittances) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        if (_submissions.any((s) => s.id == id)) continue;

        final profile = row['profiles'] is Map
            ? Map<String, dynamic>.from(row['profiles'] as Map)
            : null;
        final createdAt =
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now();
        final shiftId = row['shift_id']?.toString() ?? id;

        final photos = <String>[];
        final evidence = row['remittance_evidence'];
        if (evidence is List) {
          for (final e in evidence) {
            final ev = e is Map ? Map<String, dynamic>.from(e) : null;
            final channel = ev?['payment_channel']?.toString();
            if (channel == 'credit_requisition' ||
                channel == 'fuel_return_evidence') {
              continue;
            }
            final path = ev?['storage_path']?.toString();
            if (path != null && path.isNotEmpty) photos.add(path);
          }
        }

        mergedRemittances.add(
          ShiftSubmission(
            id: id,
            shiftId: shiftId,
            attendantId: row['attendant_id']?.toString() ?? '',
            attendantName: (profile?['display_name'] ??
                    profile?['full_name'] ??
                    'Attendant')
                .toString(),
            shiftType:
                createdAt.toLocal().hour < 14 ? 'Morning' : 'Evening',
            submittedAt: createdAt,
            nozzles: const [],
            expectedSalesValue:
                (row['expected_sales_value'] as num?)?.toDouble() ?? 0,
            cashDeclared: (row['cash_declared'] as num?)?.toDouble() ?? 0,
            posCardDeclared:
                (row['pos_card_declared'] as num?)?.toDouble() ?? 0,
            posTransferDeclared:
                (row['pos_transfer_declared'] as num?)?.toDouble() ?? 0,
            bankTransferDeclared:
                (row['bank_transfer_declared'] as num?)?.toDouble() ?? 0,
            creditSalesDeclared:
                (row['credit_sales_declared'] as num?)?.toDouble() ?? 0,
            evidencePhotos: photos,
            cashDrops: _cashDrops.where((d) => d.shiftId == shiftId).toList(),
            posTransactions:
                _posTransactions.where((p) => p.shiftId == shiftId).toList(),
            finalCashHandover:
                (row['cash_declared'] as num?)?.toDouble() ?? 0,
            status: _remittanceStatusFromRemote(row['status']?.toString()),
            cashierComment: row['cashier_notes']?.toString() ?? '',
            verifiedAt: row['verified_at'] != null
                ? DateTime.tryParse(row['verified_at'].toString())
                : null,
          ),
        );
      }
      if (mergedRemittances.isNotEmpty) {
        _submissions.insertAll(0, mergedRemittances);
      }

      // 12. Fetch monthly payroll settlements (§4.7)
      final remoteSets = await repo.fetchPayrollSettlements();
      for (final s in remoteSets) {
        if (!_payrollSettlements.any((e) => e.id == s.id)) {
          _payrollSettlements.add(s);
        }
      }

      // 13. Fetch operational notifications
      final remoteNotifications = await repo.fetchNotifications();
      if (remoteNotifications.isNotEmpty) {
        _notifService.replaceAll(remoteNotifications);
      }
    } catch (e) {
      debugPrint('[Supabase Sync Error]: $e');
    } finally {
      _isSyncingWithRemote = false;
      notifyListeners();
    }
  }

  String _remittanceStatusFromRemote(String? raw) {
    switch (raw) {
      case 'submitted':
        return 'Pending Verification';
      case 'verified':
        return 'Verified';
      case 'flagged_unresolved':
        return 'Flagged Unresolved';
      default:
        return raw ?? 'Pending Verification';
    }
  }

  /// '08 Oct 2026' — mirrors SupabaseRepository date formatting
  String _formatRepaymentDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  // ---------------------------------------------------------------------------
  // REAL-TIME ACTIONS & RECONCILIATION LOGIC (PHASE 1 & PHASE 2 QUEUING)
  // ---------------------------------------------------------------------------

  /// Persist absolute tank stock after every local mutation (C9)
  void _enqueueTankStock(LiveTankStock t) {
    _syncService.enqueue(
      actionType: SyncActionType.tankStock,
      payload: {
        'tankCode': t.code,
        'bookStock': t.bookStock,
        'physicalDip': t.physicalDip,
      },
    );
  }

  /// Attendant confirms opening reading on nozzle
  void confirmOpeningReading(int nozzleNumber) {
    final idx = _nozzles.indexWhere((n) => n.nozzleNumber == nozzleNumber);
    if (idx != -1) {
      _nozzles[idx].isOpeningConfirmed = true;
      notifyListeners();
    }
  }

  /// Record closing readings for current attendant shift
  void recordClosingReadings(Map<int, double> closingReadings) {
    final List<Map<String, dynamic>> readingsPayload = [];

    for (var entry in closingReadings.entries) {
      final idx = _nozzles.indexWhere((n) => n.nozzleNumber == entry.key);
      if (idx != -1) {
        _nozzles[idx].closingReading = entry.value;
        readingsPayload.add({
          'nozzleNumber': entry.key,
          'openingReading': _nozzles[idx].openingReading,
          'closingReading': entry.value,
          'pricePerLitre': _nozzles[idx].pricePerLitre,
        });
      }
    }

    // Queue in Offline Sync Engine
    _syncService.enqueue(
      actionType: SyncActionType.closingReadings,
      payload: {
        'shiftId': currentShiftId,
        'stationCode': _currentStationCode,
        'readings': readingsPayload,
        'attendantId': _currentUser.id,
      },
    );

    notifyListeners();
  }

  /// Submit shift remittance declaration (Pushes directly into Cashier verification queue + Offline Queue)
  void submitRemittance({
    required double cash,
    required double posCard,
    required double posTransfer,
    required double bankTransfer,
    required double credit,
    required List<String> evidencePhotos,
    List<InterimCashDrop>? drops,
    List<PosTransaction>? posTransactions,
    double finalCashHandover = 0.0,
  }) {
    final expectedSales = _nozzles.fold(0.0, (s, n) => s + n.salesValue);
    final totalExpected = expectedSales;
    final submissionId = SupabaseRepository.instance.generateUuid();
    final shiftId = currentShiftId;

    final attendantDrops = drops ?? _cashDrops.where((d) => d.attendantId == _currentUser.id).toList();
    final attendantPos = posTransactions ?? _posTransactions.where((p) => p.attendantId == _currentUser.id).toList();

    final sub = ShiftSubmission(
      id: submissionId,
      shiftId: shiftId,
      attendantName: _currentUser.displayName,
      attendantId: _currentUser.id,
      shiftType: 'Morning',
      submittedAt: DateTime.now(),
      nozzles: List.from(_nozzles),
      expectedSalesValue: totalExpected,
      cashDeclared: cash,
      posCardDeclared: posCard,
      posTransferDeclared: posTransfer,
      bankTransferDeclared: bankTransfer,
      creditSalesDeclared: credit,
      evidencePhotos: evidencePhotos,
      cashDrops: attendantDrops,
      posTransactions: attendantPos,
      finalCashHandover: finalCashHandover > 0 ? finalCashHandover : cash,
      status: 'Pending Verification',
    );

    _submissions.insert(0, sub);

    // Deduct metered sales from tank stock
    for (var n in _nozzles) {
      if (n.litresSold > 0) {
        final tank = _tanks.firstWhere(
          (t) => t.code == n.tankCode,
          orElse: () => _tanks.first,
        );
        tank.bookStock -= n.litresSold;
        _enqueueTankStock(tank);
      }
    }

    // Dispatch to Offline Sync Service
    _syncService.enqueue(
      actionType: SyncActionType.remittanceSubmission,
      payload: {
        'id': submissionId,
        'shiftId': shiftId,
        'stationCode': _currentStationCode,
        'attendantId': _currentUser.id,
        'expectedSalesValue': totalExpected,
        'cashDeclared': cash,
        'posCardDeclared': posCard,
        'posTransferDeclared': posTransfer,
        'bankTransferDeclared': bankTransfer,
        'creditSalesDeclared': credit,
        'evidencePhotos': sub.evidencePhotos,
      },
    );

    // In-app alert for Cashier
    _notifService.postNotification(
      title: 'New Shift Remittance',
      message: '${_currentUser.displayName} submitted Morning shift remittance (${CurrencyFormatter.formatNaira(totalExpected)}).',
      type: NotificationType.info,
      targetRole: UserRole.cashier,
      actionRouteName: '09 Verify Submission',
    );

    notifyListeners();
  }

  /// Cashier verifies a shift submission
  void verifyShiftSubmission({
    required String submissionId,
    required String cashierComment,
  }) {
    final sub = _submissions.firstWhere((s) => s.id == submissionId);
    sub.status = 'Verified';
    sub.cashierComment = cashierComment;
    sub.verifiedAt = DateTime.now();

    _syncService.enqueue(
      actionType: SyncActionType.remittanceVerification,
      payload: {
        'id': submissionId,
        'status': 'verified',
        'cashierNotes': cashierComment,
        'verifiedBy': _currentUser.id,
        'verifiedAt': DateTime.now().toIso8601String(),
      },
    );

    // If there is any shortage or excess, immediately log to Attendant Salary Ledger (§4.6)
    if (!sub.isBalanced) {
      final adj = SalaryAdjustment(
        id: SupabaseRepository.instance.generateUuid(),
        attendantName: sub.attendantName,
        station: 'Lekki Road',
        shiftRef: '${sub.shiftType} Shift (${sub.id})',
        amount: sub.variance,
        status: 'Pending Review',
        recordedAt: DateTime.now(),
      );
      _salaryAdjustments.insert(0, adj);

      _syncService.enqueue(
        actionType: SyncActionType.shortageAdjustment,
        payload: {
          'id': adj.id,
          'attendant_name': adj.attendantName,
          'station': adj.station,
          'shift_ref': adj.shiftRef,
          'amount': adj.amount,
          'status': adj.status,
          'recorded_at': DateTime.now().toIso8601String(),
        },
      );
    }

    _notifService.postNotification(
      title: 'Shift Remittance Verified',
      message: 'Cashier verified ${sub.attendantName}\'s shift. ${CurrencyFormatter.formatNaira(sub.cashDeclared)} added to cash drawer.',
      type: NotificationType.success,
      targetRole: UserRole.manager,
      actionRouteName: '10 Cash Count',
    );

    notifyListeners();
  }

  /// Cashier flags shift submission as unresolved
  void flagShiftUnresolved({
    required String submissionId,
    required String cashierComment,
  }) {
    final sub = _submissions.firstWhere((s) => s.id == submissionId);
    sub.status = 'Flagged Unresolved';
    sub.cashierComment = cashierComment;

    _syncService.enqueue(
      actionType: SyncActionType.remittanceVerification,
      payload: {
        'id': submissionId,
        'status': 'flagged_unresolved',
        'cashierNotes': cashierComment,
        'verifiedBy': _currentUser.id,
        'verifiedAt': DateTime.now().toIso8601String(),
      },
    );

    final flaggedAdj = SalaryAdjustment(
      id: SupabaseRepository.instance.generateUuid(),
      attendantName: sub.attendantName,
      station: 'Lekki Road',
      shiftRef: '${sub.shiftType} Shift (${sub.id})',
      amount: sub.variance,
      status: 'Pending Review',
      recordedAt: DateTime.now(),
    );
    _salaryAdjustments.insert(0, flaggedAdj);

    _syncService.enqueue(
      actionType: SyncActionType.shortageAdjustment,
      payload: {
        'id': flaggedAdj.id,
        'attendant_name': flaggedAdj.attendantName,
        'station': flaggedAdj.station,
        'shift_ref': flaggedAdj.shiftRef,
        'amount': flaggedAdj.amount,
        'status': flaggedAdj.status,
        'recorded_at': DateTime.now().toIso8601String(),
      },
    );

    _notifService.postNotification(
      title: 'Shift Shortage Flagged',
      message: 'Shortfall of ${CurrencyFormatter.formatVariance(sub.variance)} flagged on ${sub.attendantName}\'s shift. Awaiting Director review.',
      type: NotificationType.critical,
      targetRole: UserRole.director,
      actionRouteName: '19 Salary Deductions',
    );

    notifyListeners();
  }

  /// Add Credit Sale at pump (§4.8)
  void recordCreditSale({
    required String customerId,
    required int nozzleNumber,
    required double litres,
    required String vehiclePlate,
    required String driverName,
    List<String> evidencePhotos = const [],
  }) {
    final customer = _creditCustomers.firstWhere((c) => c.id == customerId);
    final nozzle = _nozzles.firstWhere((n) => n.nozzleNumber == nozzleNumber);
    final saleValue = litres * nozzle.pricePerLitre;

    // Update customer's outstanding balance
    final idx = _creditCustomers.indexWhere((c) => c.id == customerId);
    _creditCustomers[idx] = CreditCustomer(
      id: customer.id,
      name: customer.name,
      outstanding: customer.outstanding + saleValue,
      lastRepayment: customer.lastRepayment,
      dueDate: customer.dueDate,
      status: CustomerCreditStatus.current,
    );

    // Record intra-shift credit sale for attendant reconciliation (§4.8)
    _creditSalesRecords.insert(
      0,
      ShiftCreditSaleRecord(
        id: 'CS-${DateTime.now().millisecondsSinceEpoch}',
        attendantId: _currentUser.id,
        customerId: customerId,
        customerName: customer.name,
        nozzleNumber: nozzleNumber,
        litres: litres,
        amount: saleValue,
        vehiclePlate: vehiclePlate,
        driverName: driverName,
        recordedAt: DateTime.now(),
      ),
    );

    // Queue in Offline Sync Engine
    _syncService.enqueue(
      actionType: SyncActionType.creditSale,
      payload: {
        'id': SupabaseRepository.instance.generateUuid(),
        'attendantId': _currentUser.id,
        'customerId': customerId,
        'customerName': customer.name,
        'nozzleNumber': nozzleNumber,
        'litres': litres,
        'totalAmount': saleValue,
        'vehicleReg': vehiclePlate,
        'driverName': driverName,
        'evidencePhotos': evidencePhotos,
      },
    );

    notifyListeners();
  }

  /// Record a credit repayment against a customer's outstanding balance (§4.8)
  void recordCreditRepayment({
    required String customerId,
    required double amount,
  }) {
    if (amount <= 0) return;

    final idx = _creditCustomers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      final c = _creditCustomers[idx];
      _creditCustomers[idx] = CreditCustomer(
        id: c.id,
        name: c.name,
        outstanding:
            (c.outstanding - amount).clamp(0, double.infinity).toDouble(),
        lastRepayment: _formatRepaymentDate(DateTime.now()),
        dueDate: c.dueDate,
        status: c.status,
      );
    }

    _syncService.enqueue(
      actionType: SyncActionType.creditRepayment,
      payload: {
        'customerId': customerId,
        'amount': amount,
      },
    );

    notifyListeners();
  }

  /// Record Branch Expense with Cashier/Manager Approval Workflow (§5.1, §5.2)
  void recordExpense({
    required String category,
    required double amount,
    required String paymentSource,
    required String description,
    String? receiptUrl,
    bool requiresApproval = false,
  }) {
    final expId = 'EXP-${DateTime.now().millisecondsSinceEpoch}';
    final isCashier = _currentUser.role == UserRole.cashier;
    final isDirector = _currentUser.role == UserRole.director;

    String initialStatus;
    String? approver;
    DateTime? approvedTime;

    if (isDirector) {
      initialStatus = 'Approved';
      approver = _currentUser.displayName;
      approvedTime = DateTime.now();
    } else if (isCashier) {
      if (requiresApproval || amount > 10000) {
        initialStatus = 'Pending Approval';
      } else {
        initialStatus = 'Approved';
        approver = 'Pre-Approved by Manager';
        approvedTime = DateTime.now();
      }
    } else { // Manager
      if (amount > 50000) {
        initialStatus = 'Pending Approval'; // High-value branch expense requires Admin/Director sign-off
      } else {
        initialStatus = 'Approved';
        approver = _currentUser.displayName;
        approvedTime = DateTime.now();
      }
    }

    final newExpense = BranchExpense(
      id: expId,
      category: category,
      amount: amount,
      paymentSource: paymentSource,
      description: description,
      recordedBy: _currentUser.displayName,
      recordedByRole: _currentUser.role.name,
      status: initialStatus,
      approvedBy: approver,
      approvedAt: approvedTime,
      receiptUrl: receiptUrl,
      recordedAt: DateTime.now(),
    );

    _expenses.insert(0, newExpense);

    // Queue in Offline Sync Engine
    _syncService.enqueue(
      actionType: SyncActionType.branchExpense,
      payload: {
        'id': expId,
        'category': category,
        'amount': amount,
        'payment_source': (paymentSource == 'Cash Drawer' || paymentSource == 'sales_cash') ? 'sales_cash' : 'bank_transfer',
        'description': description,
        'status': initialStatus,
        'recorded_by': _currentUser.displayName,
        'approved_by': approver,
        'receipt_url': receiptUrl,
        'station_id': _currentStationCode,
      },
    );

    if (initialStatus == 'Pending Approval') {
      _notifService.postNotification(
        title: 'EXPENSE APPROVAL REQUIRED',
        message: '${_currentUser.displayName} recorded ${CurrencyFormatter.formatNaira(amount)} for $category requiring approval.',
        type: NotificationType.warning,
        actionRouteName: '17 Manager Dashboard',
      );
    }

    notifyListeners();
  }

  void approveExpense({
    required String expenseId,
    String? approverNotes,
  }) {
    final idx = _expenses.indexWhere((e) => e.id == expenseId);
    if (idx != -1) {
      _expenses[idx].status = 'Approved';
      _expenses[idx].approvedBy = _currentUser.displayName;
      _expenses[idx].approvedAt = DateTime.now();

      _syncService.enqueue(
        actionType: SyncActionType.branchExpense,
        payload: {
          'id': expenseId,
          'status': 'Approved',
          'approved_by': _currentUser.displayName,
          'approved_at': DateTime.now().toIso8601String(),
          'notes': approverNotes,
        },
      );

      _notifService.postNotification(
        title: 'EXPENSE APPROVED',
        message: 'Expense of ${CurrencyFormatter.formatNaira(_expenses[idx].amount)} approved by ${_currentUser.displayName}.',
        type: NotificationType.info,
      );

      notifyListeners();
    }
  }

  void rejectExpense({
    required String expenseId,
    required String reason,
  }) {
    final idx = _expenses.indexWhere((e) => e.id == expenseId);
    if (idx != -1) {
      _expenses[idx].status = 'Rejected';
      _expenses[idx].approvedBy = 'Rejected by ${_currentUser.displayName}: $reason';
      _expenses[idx].approvedAt = DateTime.now();

      _notifService.postNotification(
        title: 'EXPENSE REJECTED',
        message: 'Expense of ${CurrencyFormatter.formatNaira(_expenses[idx].amount)} rejected: $reason.',
        type: NotificationType.critical,
      );

      notifyListeners();
    }
  }

  /// Record Fuel Delivery (§3.7)
  void recordFuelDelivery({
    required String tankCode,
    required String supplier,
    required String waybillNumber,
    required double statedLitres,
    required double dipBefore,
    required double dipAfter,
    required double purchasePrice,
  }) {
    final received = (dipAfter > dipBefore) ? (dipAfter - dipBefore) : 0.0;
    final discrepancy = received - statedLitres;
    final delId = 'DEL-${DateTime.now().millisecondsSinceEpoch}';

    _deliveries.insert(
      0,
      FuelDeliveryRecord(
        id: delId,
        tankCode: tankCode,
        supplier: supplier,
        waybillNumber: waybillNumber,
        statedLitres: statedLitres,
        dipBefore: dipBefore,
        dipAfter: dipAfter,
        receivedLitres: received,
        discrepancy: discrepancy,
        purchasePricePerLitre: purchasePrice,
        deliveredAt: DateTime.now(),
      ),
    );

    // Update tank book stock and physical dip
    final tank = _tanks.firstWhere((t) => t.code == tankCode);
    tank.bookStock += received;
    tank.physicalDip = dipAfter;
    tank.lastDipTime = DateTime.now();
    _enqueueTankStock(tank);

    // Queue in Offline Sync Engine
    _syncService.enqueue(
      actionType: SyncActionType.fuelDelivery,
      payload: {
        'id': delId,
        'tank_code': tankCode,
        'supplier': supplier,
        'waybill_number': waybillNumber,
        'stated_litres': statedLitres,
        'dip_before': dipBefore,
        'dip_after': dipAfter,
        'received_litres': received,
        'discrepancy': discrepancy,
        'purchase_price': purchasePrice,
      },
    );

    _notifService.postNotification(
      title: 'Tanker Fuel Discharged',
      message: '${CurrencyFormatter.formatLitres(received)} delivered to Tank $tankCode from $supplier (Waybill: $waybillNumber).',
      type: NotificationType.info,
      targetRole: UserRole.director,
      actionRouteName: '13 Fuel Delivery (Waybill)',
    );

    notifyListeners();
  }

  /// Record Tank Dip Audit (§3.2, §3.3)
  void recordTankDipAudit({
    required String tankCode,
    required double physicalDipLitres,
    required double dipStickCm,
  }) {
    final tank = _tanks.firstWhere((t) => t.code == tankCode);
    tank.physicalDip = physicalDipLitres;
    tank.lastDipTime = DateTime.now();
    _enqueueTankStock(tank);

    _syncService.enqueue(
      actionType: SyncActionType.tankDipAudit,
      payload: {
        'id': SupabaseRepository.instance.generateUuid(),
        'tank_id': tankCode,
        'physical_dip_litres': physicalDipLitres,
        'dip_stick_cm': dipStickCm,
        'book_stock_litres': tank.bookStock,
        'variance_litres': physicalDipLitres - tank.bookStock,
        'recorded_at': DateTime.now().toIso8601String(),
      },
    );

    if (physicalDipLitres < tank.bookStock - 50) {
      _notifService.postNotification(
        title: 'Tank Stock Deficit Warning',
        message: 'Tank $tankCode physical dip has deficit of ${(physicalDipLitres - tank.bookStock).toStringAsFixed(1)}L vs book stock.',
        type: NotificationType.warning,
        targetRole: UserRole.manager,
        actionRouteName: '12 Tank Dip Audit',
      );
    }

    notifyListeners();
  }

  /// Record Fuel Return to Tank (§3.5)
  void recordFuelReturn({
    required String tankCode,
    required double litres,
    required String reason,
    List<String> evidencePhotos = const [],
  }) {
    final tank = _tanks.firstWhere((t) => t.code == tankCode);
    tank.bookStock += litres;
    tank.physicalDip += litres;
    _enqueueTankStock(tank);

    _syncService.enqueue(
      actionType: SyncActionType.fuelReturn,
      payload: {
        'id': SupabaseRepository.instance.generateUuid(),
        'tankCode': tankCode,
        'litres': litres,
        'reason': reason,
        'attendantId': _currentUser.id,
        'evidencePhotos': evidencePhotos,
      },
    );

    notifyListeners();
  }

  /// Authorize Retail Price Change & Capture Meter Snapshots (§2.8, §2.9)
  void authorizePriceChange({
    required String product,
    required double newPrice,
    required String reason,
    required Map<int, double> meterSnapshots,
  }) {
    if (product == 'PMS') {
      _pmsPrice = newPrice;
    } else {
      _agoPrice = newPrice;
    }

    // Update active prices on nozzles and record snapshot as carry-forward baseline
    for (var n in _nozzles) {
      if (n.productName == product) {
        if (meterSnapshots.containsKey(n.nozzleNumber)) {
          n.openingReading = meterSnapshots[n.nozzleNumber]!;
          n.closingReading = null;
        }
      }
    }

    _syncService.enqueue(
      actionType: SyncActionType.priceChange,
      payload: {
        'id': SupabaseRepository.instance.generateUuid(),
        'product': product,
        'new_price': newPrice,
        'reason': reason,
        'meter_snapshots': meterSnapshots.map((k, v) => MapEntry(k.toString(), v)),
        'authorized_at': DateTime.now().toIso8601String(),
      },
    );

    // High-priority broadcast to all staff
    _notifService.postNotification(
      title: 'PRICE CHANGE DIRECTIVE',
      message: '$product retail price set to ${CurrencyFormatter.formatNaira(newPrice)}/L across all 5 branches.',
      type: NotificationType.critical,
      actionRouteName: '18 Retail Fuel Prices',
    );

    notifyListeners();
  }

  /// Legacy local ids ('DISC-…') have no uuid row in
  /// attendant_salary_adjustments — never queue those for sync.
  static final RegExp _uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  void _enqueueShortageStatusUpdate(SalaryAdjustment adj) {
    if (!_uuidPattern.hasMatch(adj.id)) return;
    _syncService.enqueue(
      actionType: SyncActionType.shortageAdjustment,
      payload: {
        'id': adj.id,
        'attendant_name': adj.attendantName,
        'station': adj.station,
        'shift_ref': adj.shiftRef,
        'amount': adj.amount,
        'status': adj.status,
        'recorded_at': adj.recordedAt.toIso8601String(),
      },
    );
  }

  /// Director approves salary deduction
  void approveSalaryDeduction(String adjustmentId) {
    final adj = _salaryAdjustments.firstWhere((a) => a.id == adjustmentId);
    adj.status = 'Salary Deduction Approved';

    _enqueueShortageStatusUpdate(adj);

    notifyListeners();
  }

  /// Director waives attendant shortage
  void waiveShortage(String adjustmentId) {
    final adj = _salaryAdjustments.firstWhere((a) => a.id == adjustmentId);
    adj.status = 'Waived by Director';

    _enqueueShortageStatusUpdate(adj);

    notifyListeners();
  }

  /// Process Monthly Payroll Settlement for an Attendant (§4.6, §4.7)
  MonthlyPayrollSettlement processMonthlyPayrollSettlement({
    required String attendantId,
    required String attendantName,
    required String stationName,
    required String monthYear,
    required double baseSalary,
    required String settledBy,
  }) {
    // Find all adjustments for this attendant that are approved ('Salary Deduction Approved')
    final approvedAdjustments = _salaryAdjustments.where((adj) {
      final nameMatches = adj.attendantName.trim().toLowerCase() == attendantName.trim().toLowerCase();
      final isApprovedShortage = adj.status == 'Salary Deduction Approved';
      return nameMatches && isApprovedShortage;
    }).toList();

    double totalShortages = 0.0;
    double totalExcesses = 0.0;
    for (var adj in approvedAdjustments) {
      if (adj.amount < 0) {
        totalShortages += adj.amount.abs();
      } else {
        totalExcesses += adj.amount;
      }
      adj.status = 'Settled in Payroll ($monthYear)';
    }

    final netCalculated = (baseSalary - totalShortages + totalExcesses);
    final netPayable = netCalculated > 0 ? netCalculated : 0.0;
    final carriedDeficit = netCalculated < 0 ? netCalculated.abs() : 0.0;

    final settlement = MonthlyPayrollSettlement(
      id: 'settlement-${DateTime.now().millisecondsSinceEpoch}-${attendantName.hashCode.abs()}',
      attendantId: attendantId,
      attendantName: attendantName,
      stationName: stationName,
      monthYear: monthYear,
      baseSalary: baseSalary,
      totalShortagesDeducted: totalShortages,
      totalExcessesCredited: totalExcesses,
      netPayable: netPayable,
      carriedDeficit: carriedDeficit,
      shortfallShiftCount: approvedAdjustments.length,
      settledBy: settledBy,
      settledAt: DateTime.now(),
    );

    _payrollSettlements.insert(0, settlement);

    _syncService.enqueue(
      actionType: SyncActionType.salaryAdjustment,
      payload: settlement.toJson(),
    );

    _notifService.postNotification(
      title: 'Monthly Payroll Settled ($monthYear)',
      message: 'Attendant $attendantName settled. Base: ${CurrencyFormatter.formatNaira(baseSalary)} | Shortages: -${CurrencyFormatter.formatNaira(totalShortages)} | Net: ${CurrencyFormatter.formatNaira(netPayable)}',
      type: NotificationType.success,
      targetRole: UserRole.director,
      actionRouteName: '19 Salary Ledger',
    );

    notifyListeners();
    return settlement;
  }

  /// Bulk Process Monthly Payroll Settlement for all Attendants (§4.7)
  List<MonthlyPayrollSettlement> processAllAttendantsPayroll({
    required String monthYear,
    required String settledBy,
  }) {
    final attendantStaff = _staff.where((s) => s.role == UserRole.attendant).toList();
    final List<MonthlyPayrollSettlement> results = [];

    // Process attendants with a Director-configured base salary (no fabricated fallback)
    for (var att in attendantStaff) {
      if (att.baseSalary <= 0) continue; // Awaiting Director — base salary not set yet
      final settlement = processMonthlyPayrollSettlement(
        attendantId: att.id,
        attendantName: att.displayName,
        stationName: att.stationName.isNotEmpty ? att.stationName : _currentStationName,
        monthYear: monthYear,
        baseSalary: att.baseSalary,
        settledBy: settledBy,
      );
      results.add(settlement);
    }

    notifyListeners();
    return results;
  }

  /// Record handover of cash for commercial bank deposit (§4.3, §5.4, §5.5)
  Future<BankDepositRecord?> recordBankDeposit({
    required double amount,
    required String bankName,
    required String bearerName,
    String? tellerNumber,
    String? slipUrl,
    String? notes,
  }) async {
    final repo = SupabaseRepository.instance;
    final dep = await repo.recordBankDeposit(
      stationCode: _currentStationCode,
      amount: amount,
      bankName: bankName,
      bearerName: bearerName,
      tellerNumber: tellerNumber,
      slipUrl: slipUrl,
      notes: notes,
    );

    if (dep != null) {
      _deposits.removeWhere((d) => d.id == dep.id);
      _deposits.insert(0, dep);

      // Offline: the repo returned a local-only record — queue the handover
      // so it lands in bank_deposits when connectivity returns.
      if (!repo.isConnected) {
        _syncService.enqueue(
          actionType: SyncActionType.bankDepositRecord,
          payload: dep.toJson(),
        );
      }

      _notifService.postNotification(
        title: 'Bank Remittance Handed Over',
        message: '$bearerName handed over ${CurrencyFormatter.formatNaira(amount)} for deposit into $bankName. Awaiting Director alert match.',
        type: NotificationType.warning,
        actionRouteName: '20 Bank Deposits',
      );

      notifyListeners();
    }
    return dep;
  }

  /// Director confirms bank deposit against commercial bank credit alert (§4.3, §5.5)
  Future<bool> confirmBankDeposit(String depositId, [String? directorNotes]) async {
    final repo = SupabaseRepository.instance;
    final ok = await repo.confirmBankDeposit(
      depositId: depositId,
      directorId: _currentUser.id,
      directorNotes: directorNotes,
    );

    final idx = _deposits.indexWhere((d) => d.id == depositId);
    if (idx != -1) {
      _deposits[idx].isConfirmed = true;
      _deposits[idx].status = 'confirmed';
      _deposits[idx].confirmedAt = DateTime.now();
      _deposits[idx].confirmedBy = _currentUser.displayName;
      _deposits[idx].directorNotes = directorNotes;

      _syncService.enqueue(
        actionType: SyncActionType.bankDepositConfirmation,
        payload: {
          'id': depositId,
          'confirmed_at': _deposits[idx].confirmedAt!.toIso8601String(),
          'director_notes': directorNotes,
        },
      );

      _notifService.postNotification(
        title: 'Bank Deposit Confirmed',
        message: 'Director confirmed commercial bank credit alert for deposit $depositId (${CurrencyFormatter.formatNaira(_deposits[idx].amount)}).',
        type: NotificationType.success,
        actionRouteName: '17 Manager Dashboard',
      );

      notifyListeners();
    }
    return ok;
  }

  /// Director flags a discrepancy on a bank deposit (§4.3, §5.5)
  Future<bool> flagBankDepositDiscrepancy(String depositId, String discrepancyNotes) async {
    final repo = SupabaseRepository.instance;
    final ok = await repo.flagBankDepositDiscrepancy(
      depositId: depositId,
      directorId: _currentUser.id,
      discrepancyNotes: discrepancyNotes,
    );

    final idx = _deposits.indexWhere((d) => d.id == depositId);
    if (idx != -1) {
      _deposits[idx].status = 'discrepancy';
      _deposits[idx].directorNotes = discrepancyNotes;

      _notifService.postNotification(
        title: 'Bank Deposit Discrepancy Flagged',
        message: 'Director flagged discrepancy on deposit of ${CurrencyFormatter.formatNaira(_deposits[idx].amount)}: $discrepancyNotes',
        type: NotificationType.warning,
        actionRouteName: '17 Manager Dashboard',
      );

      notifyListeners();
    }
    return ok;
  }

  /// Cash count calculations
  void updateCashCount(int denomination, int count) {
    if (_cashCounts.containsKey(denomination)) {
      _cashCounts[denomination] = count;
      notifyListeners();
    }
  }

  /// Persist the physical safe count to the daily_cash_counts audit table
  /// (§5.3). Returns 'saved' (written to Supabase), 'queued' (offline or
  /// write failed — handed to the Offline Engine) or 'failed'.
  Future<String> saveDailyCashAudit() async {
    final repo = SupabaseRepository.instance;
    final payload = <String, dynamic>{
      'station_id': _currentStationCode,
      'cashier_id': _currentUser.id,
      'opening_cash': _openingCash,
      'cash_receipts': totalVerifiedCashReceipts,
      'cash_expenses': totalPhysicalCashExpenses,
      'handed_over_for_deposit': totalHandedOverDeposits,
      'expected_closing_cash': expectedClosingCash,
      'physical_total_counted': totalCountedCash,
      'count_1000': _cashCounts[1000] ?? 0,
      'count_500': _cashCounts[500] ?? 0,
      'count_200': _cashCounts[200] ?? 0,
      'count_100': _cashCounts[100] ?? 0,
      'count_50': _cashCounts[50] ?? 0,
      'count_20': _cashCounts[20] ?? 0,
      'count_10': _cashCounts[10] ?? 0,
      'deposit_status': 'awaiting_bank',
    };

    if (!repo.isConnected) {
      _syncService.enqueue(
        actionType: SyncActionType.dailyCashAudit,
        payload: payload,
      );
      return 'queued';
    }

    final ok = await repo.recordDailyCashAuditPayload(payload);
    if (ok) return 'saved';

    // Online write failed — keep the count safe in the queue for retry.
    _syncService.enqueue(
      actionType: SyncActionType.dailyCashAudit,
      payload: payload,
    );
    return 'queued';
  }

  double get totalCountedCash {
    double sum = 0.0;
    _cashCounts.forEach((d, c) => sum += (d * c));
    return sum;
  }

  double get totalVerifiedCashReceipts {
    return _submissions
        .where((s) => s.status == 'Verified')
        .fold(0.0, (sum, s) => sum + s.cashDeclared);
  }

  double get totalPhysicalCashExpenses {
    return _expenses
        .where((e) =>
            (e.paymentSource == 'sales_cash' || e.paymentSource == 'Cash Drawer') &&
            e.status != 'Rejected')
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// All expenses awaiting Manager or Admin/Director approval
  List<BranchExpense> get pendingExpenses =>
      _expenses.where((e) => e.status == 'Pending Approval').toList();

  /// Total cash drawer expenses that are pending approval
  double get totalPendingCashExpenses {
    return pendingExpenses
        .where((e) => e.paymentSource == 'sales_cash' || e.paymentSource == 'Cash Drawer')
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalHandedOverDeposits {
    return _deposits.fold(0.0, (sum, d) => sum + d.amount);
  }

  double get totalAcknowledgedInterimDrops {
    return _cashDrops
        .where((d) => d.isAcknowledged)
        .fold(0.0, (sum, d) => sum + d.amount);
  }

  /// Interim cash drops that have been acknowledged but whose shift is NOT yet verified
  double get totalUnverifiedInterimDrops {
    final verifiedShiftIds = _submissions.where((s) => s.status == 'Verified').map((s) => s.id).toSet();
    return _cashDrops
        .where((d) => d.isAcknowledged && (d.shiftId == null || !verifiedShiftIds.contains(d.shiftId)))
        .fold(0.0, (sum, d) => sum + d.amount);
  }

  double get expectedClosingCash {
    return _openingCash +
        totalVerifiedCashReceipts +
        totalUnverifiedInterimDrops -
        totalPhysicalCashExpenses -
        totalHandedOverDeposits;
  }

  double get cashDrawerVariance => totalCountedCash - expectedClosingCash;

  // ---------------------------------------------------------------------------
  // STATION SETUP CREATE FLOWS (§3.1, §4.8) — 'created' | 'queued' | 'failed'
  // ---------------------------------------------------------------------------

  /// Add a tank from Station Setup
  Future<String> createTank({
    required String code,
    required String productCode,
    required double capacityLitres,
    required double initialStockLitres,
  }) async {
    if (code.trim().isEmpty ||
        productCode.trim().isEmpty ||
        capacityLitres <= 0 ||
        initialStockLitres < 0) {
      return 'failed';
    }

    final repo = SupabaseRepository.instance;
    final id = repo.generateUuid();
    final tank = LiveTankStock(
      code: code,
      product: productCode,
      capacity: capacityLitres,
      bookStock: initialStockLitres,
      physicalDip: initialStockLitres,
      lastDipTime: DateTime.now(),
    );

    if (repo.isConnected) {
      final ok = await repo.createTank(
        id: id,
        code: code,
        productCode: productCode,
        capacityLitres: capacityLitres,
        initialStockLitres: initialStockLitres,
        stationCode: _currentStationCode,
      );
      if (ok) {
        _tanks.add(tank);
        notifyListeners();
        return 'created';
      }
    }

    try {
      await _syncService.enqueue(
        actionType: SyncActionType.tankCreate,
        payload: {
          'id': id,
          'code': code,
          'name': '$productCode Tank $code',
          'capacity_litres': capacityLitres,
          'current_dip_litres': initialStockLitres,
          'calculated_stock_litres': initialStockLitres,
          'is_interlocked': false,
          'product_code': productCode,
          'station_code': _currentStationCode,
        },
      );
    } catch (_) {
      return 'failed';
    }

    _tanks.add(tank);
    notifyListeners();
    return 'queued';
  }

  /// Add a pump nozzle from Station Setup
  Future<String> createNozzle({
    required int nozzleNumber,
    required String productCode,
    required String tankCode,
    required double latestMeterReading,
  }) async {
    if (nozzleNumber <= 0 ||
        productCode.trim().isEmpty ||
        tankCode.trim().isEmpty ||
        latestMeterReading < 0) {
      return 'failed';
    }

    final repo = SupabaseRepository.instance;
    final id = repo.generateUuid();
    final nozzle = NozzleItem(
      nozzleNumber: nozzleNumber,
      productName: productCode,
      tankCode: tankCode,
      openingReading: latestMeterReading,
      pricePerLitre: productCode == 'PMS' ? _pmsPrice : _agoPrice,
      isOpeningConfirmed: false,
    );

    if (repo.isConnected) {
      final ok = await repo.createNozzle(
        id: id,
        nozzleNumber: nozzleNumber,
        productCode: productCode,
        tankCode: tankCode,
        latestMeterReading: latestMeterReading,
        stationCode: _currentStationCode,
      );
      if (ok) {
        _nozzles.add(nozzle);
        notifyListeners();
        return 'created';
      }
    }

    try {
      await _syncService.enqueue(
        actionType: SyncActionType.nozzleCreate,
        payload: {
          'id': id,
          'nozzle_number': nozzleNumber,
          'latest_meter_reading': latestMeterReading,
          'product_code': productCode,
          'tank_code': tankCode,
          'station_code': _currentStationCode,
        },
      );
    } catch (_) {
      return 'failed';
    }

    _nozzles.add(nozzle);
    notifyListeners();
    return 'queued';
  }

  /// Onboard a credit customer from Station Setup
  Future<String> createCreditCustomer({
    required String companyName,
    required String contactPerson,
    required int paymentTermsDays,
  }) async {
    if (companyName.trim().isEmpty || paymentTermsDays < 0) return 'failed';

    final repo = SupabaseRepository.instance;
    final id = repo.generateUuid();
    final customer = CreditCustomer(
      id: id,
      name: companyName,
      outstanding: 0,
      lastRepayment: 'No repayment yet',
      dueDate: '$paymentTermsDays days',
      status: CustomerCreditStatus.current,
    );

    if (repo.isConnected) {
      final ok = await repo.createCreditCustomer(
        id: id,
        companyName: companyName,
        contactPerson: contactPerson,
        paymentTermsDays: paymentTermsDays,
        stationCode: _currentStationCode,
      );
      if (ok) {
        _creditCustomers.add(customer);
        notifyListeners();
        return 'created';
      }
    }

    try {
      await _syncService.enqueue(
        actionType: SyncActionType.creditCustomerCreate,
        payload: {
          'id': id,
          'company_name': companyName,
          'contact_person': contactPerson,
          'payment_terms_days': paymentTermsDays,
          'outstanding_balance': 0,
          'status': 'current',
          'station_code': _currentStationCode,
        },
      );
    } catch (_) {
      return 'failed';
    }

    _creditCustomers.add(customer);
    notifyListeners();
    return 'queued';
  }

  // ---------------------------------------------------------------------------
  // INTERLOCKED TANK CHANGEOVERS & FORECOURT SETUP (§3.1, §7)
  // ---------------------------------------------------------------------------

  /// Branch Manager & Director: Execute manifold changeover (§3.1, §7)
  Future<bool> executeTankChangeover({
    required String productCode,
    required String fromTankCode,
    required String toTankCode,
    required Map<String, double> switchReadings,
    double? fromTankDip,
    double? toTankDip,
    String? notes,
  }) async {
    final repo = SupabaseRepository.instance;
    final success = await repo.recordTankChangeover(
      stationCode: _currentStationCode,
      productCode: productCode,
      fromTankCode: fromTankCode,
      toTankCode: toTankCode,
      switchReadings: switchReadings,
      fromTankDip: fromTankDip,
      toTankDip: toTankDip,
      notes: notes,
      switchedBy: _currentUser.id,
    );

    // Update local nozzles and tanks
    for (final nozzleStr in switchReadings.keys) {
      final nozzleNum = int.tryParse(nozzleStr.replaceAll(RegExp(r'[^0-9]'), ''));
      if (nozzleNum != null) {
        final idx = _nozzles.indexWhere((n) => n.nozzleNumber == nozzleNum);
        if (idx != -1) {
          _nozzles[idx] = NozzleItem(
            nozzleNumber: _nozzles[idx].nozzleNumber,
            productName: _nozzles[idx].productName,
            tankCode: toTankCode,
            openingReading: switchReadings[nozzleStr] ?? _nozzles[idx].openingReading,
            pricePerLitre: _nozzles[idx].pricePerLitre,
            isOpeningConfirmed: true,
          );
        }
      }
    }

    // Update active supply flag on twin tanks
    for (final t in _tanks) {
      if (t.code == fromTankCode) t.isActiveSupply = false;
      if (t.code == toTankCode) t.isActiveSupply = true;
      if (t.code == fromTankCode && fromTankDip != null) t.physicalDip = fromTankDip;
      if (t.code == toTankCode && toTankDip != null) t.physicalDip = toTankDip;
    }

    _notifService.postNotification(
      title: 'Manifold Changeover Applied',
      message: 'Switched from $fromTankCode to $toTankCode for $productCode at $_currentStationName.',
      type: NotificationType.info,
      actionRouteName: '17 Manager Dashboard',
    );

    notifyListeners();
    return success;
  }

  /// Director / Admin: Update station interlock capability
  Future<bool> updateStationInterlockConfig(bool hasInterlockedTanks) async {
    final repo = SupabaseRepository.instance;
    _hasInterlockedTanks = hasInterlockedTanks;
    notifyListeners();
    return await repo.updateStationInterlockStatus(_currentStationCode, hasInterlockedTanks);
  }

  /// Director / Admin: Update tank interlock twin flag
  Future<bool> updateTankInterlockConfig(String tankCode, bool isInterlocked) async {
    final repo = SupabaseRepository.instance;
    final tank = _tanks.firstWhere((t) => t.code == tankCode, orElse: () => _tanks[0]);
    tank.isInterlocked = isInterlocked;
    notifyListeners();
    return await repo.updateTankInterlock(tankCode, isInterlocked);
  }

  /// Director / Admin: Remap nozzle to supplying tank
  Future<bool> assignNozzleSupplyingTank(int nozzleNumber, String targetTankCode) async {
    final repo = SupabaseRepository.instance;
    final idx = _nozzles.indexWhere((n) => n.nozzleNumber == nozzleNumber);
    if (idx != -1) {
      _nozzles[idx] = NozzleItem(
        nozzleNumber: _nozzles[idx].nozzleNumber,
        productName: _nozzles[idx].productName,
        tankCode: targetTankCode,
        openingReading: _nozzles[idx].openingReading,
        pricePerLitre: _nozzles[idx].pricePerLitre,
        isOpeningConfirmed: _nozzles[idx].isOpeningConfirmed,
      );
    }
    // Reconcile active supply on tanks
    final activeCodes = _nozzles.map((n) => n.tankCode).toSet();
    for (final t in _tanks) {
      t.isActiveSupply = activeCodes.contains(t.code);
    }

    notifyListeners();
    return await repo.updateNozzleSupplyingTank(nozzleNumber, targetTankCode);
  }

  /// Switch the active station context (e.g., when Director navigates between stations)
  void switchStation(Station station) {
    _currentStationCode = station.code;
    _currentStationName = station.name;
    _hasInterlockedTanks = station.hasInterlockedTanks;
    notifyListeners();
    syncWithSupabase();
  }

  /// Director / Admin: Register and onboard a new branch station (§1)
  Future<Station?> registerNewStation({
    required String code,
    required String name,
    String? address,
    String? phone,
    String? managerName,
    bool hasInterlockedTanks = false,
  }) async {
    final repo = SupabaseRepository.instance;
    final st = await repo.createStation(
      code: code,
      name: name,
      address: address,
      phone: phone,
      managerName: managerName,
      hasInterlockedTanks: hasInterlockedTanks,
    );
    if (st != null) {
      _stations.removeWhere((s) => s.id == st.id || s.code == st.code);
      _stations.add(st);
      notifyListeners();
    }
    return st;
  }

  // ---------------------------------------------------------------------------
  // STAFF & ATTENDANT MANAGEMENT (§2.1–§2.4, §4.7)
  // ---------------------------------------------------------------------------

  /// Onboard a new pump attendant, cashier, or manager (§2.2).
  /// Captures: Full name, display name, role, station, phone, address, and shortee/surety info.
  /// Enforces: Base salary can only be configured if currentUser is Director.
  Future<UserProfile?> onboardStaff({
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
    final actualSalary = currentUser.role == UserRole.director ? baseSalary : 0.0;
    final repo = SupabaseRepository.instance;
    final newProfile = await repo.createStaffProfile(
      fullName: fullName,
      displayName: displayName,
      role: role,
      pin: pin,
      stationCode: stationCode,
      phone: phone,
      address: address,
      suretyName: suretyName,
      suretyPhone: suretyPhone,
      suretyAddress: suretyAddress,
      baseSalary: actualSalary,
    );

    if (newProfile != null) {
      _staff.removeWhere((s) => s.id == newProfile.id);
      _staff.add(newProfile);
      notifyListeners();
    }
    return newProfile;
  }

  /// Update staff monthly base salary (Director-only restriction enforced here & backend)
  Future<bool> updateStaffSalary({
    required String profileId,
    required double baseSalary,
  }) async {
    if (currentUser.role != UserRole.director) {
      return false; // Strictly restricted
    }
    final repo = SupabaseRepository.instance;
    final ok = await repo.updateStaffSalary(profileId: profileId, baseSalary: baseSalary);
    if (ok) {
      final idx = _staff.indexWhere((s) => s.id == profileId);
      if (idx != -1) {
        final old = _staff[idx];
        _staff[idx] = UserProfile(
          id: old.id,
          displayName: old.displayName,
          fullName: old.fullName,
          role: old.role,
          stationName: old.stationName,
          stationId: old.stationId,
          phone: old.phone,
          address: old.address,
          suretyName: old.suretyName,
          suretyPhone: old.suretyPhone,
          suretyAddress: old.suretyAddress,
          baseSalary: baseSalary,
          isActive: old.isActive,
        );
        notifyListeners();
      }
    }
    return ok;
  }

  /// Reset attendant login PIN (§2.3)
  Future<bool> resetStaffPin({
    required String profileId,
    required String newPin,
  }) async {
    final repo = SupabaseRepository.instance;
    return await repo.resetStaffPin(profileId: profileId, newPin: newPin);
  }

  /// Toggle active / inactive status (Deactivate or Reactivate)
  Future<bool> toggleStaffStatus({
    required String profileId,
    required bool isActive,
  }) async {
    final repo = SupabaseRepository.instance;
    final ok = await repo.toggleStaffStatus(profileId: profileId, isActive: isActive);
    if (ok) {
      final idx = _staff.indexWhere((s) => s.id == profileId);
      if (idx != -1) {
        final old = _staff[idx];
        _staff[idx] = UserProfile(
          id: old.id,
          displayName: old.displayName,
          fullName: old.fullName,
          role: old.role,
          stationName: old.stationName,
          stationId: old.stationId,
          phone: old.phone,
          address: old.address,
          suretyName: old.suretyName,
          suretyPhone: old.suretyPhone,
          suretyAddress: old.suretyAddress,
          baseSalary: old.baseSalary,
          isActive: isActive,
        );
        notifyListeners();
      }
    }
    return ok;
  }

  // ---------------------------------------------------------------------------
  // INTRA-SHIFT CASH DROPS & POS TRANSACTIONS (§2.6, §4.1, §4.4)
  // ---------------------------------------------------------------------------

  /// Attendant submits an interim cash drop to Cashier (§2.6)
  Future<InterimCashDrop?> recordInterimCashDrop({
    required double amount,
    String? notes,
  }) async {
    final repo = SupabaseRepository.instance;
    final drop = await repo.createInterimCashDrop(
      stationCode: _currentStationCode,
      attendantId: _currentUser.id,
      attendantName: _currentUser.displayName,
      amount: amount,
      notes: notes,
      shiftId: currentShiftId,
    );

    if (drop != null) {
      _cashDrops.removeWhere((d) => d.id == drop.id);
      _cashDrops.insert(0, drop);

      // Offline: queue the drop for interim_cash_drops instead of the
      // memory-only fallback (a mis-typed branchExpense enqueue here
      // previously poisoned the queue).
      if (!repo.isConnected) {
        _syncService.enqueue(
          actionType: SyncActionType.interimCashDrop,
          payload: drop.toJson(),
        );
      }

      // Post high-priority notification to Cashier
      _notifService.postNotification(
        title: 'Incoming Interim Cash Drop',
        message: '${_currentUser.displayName} submitted ₦${amount.toStringAsFixed(0)} cash drop for acknowledgement.',
        type: NotificationType.warning,
        actionRouteName: '16 Cashier Verification',
      );

      notifyListeners();
    }
    return drop;
  }

  /// Cashier acknowledges receipt of interim cash drop (§4.1, §4.4)
  Future<bool> acknowledgeCashDrop(String dropId) async {
    final repo = SupabaseRepository.instance;
    final ok = await repo.acknowledgeInterimCashDrop(
      dropId: dropId,
      cashierId: _currentUser.id,
    );

    final idx = _cashDrops.indexWhere((d) => d.id == dropId);
    if (idx != -1) {
      _cashDrops[idx].status = 'acknowledged';
      _cashDrops[idx].acknowledgedBy = _currentUser.displayName;
      _cashDrops[idx].acknowledgedAt = DateTime.now();

      _notifService.postNotification(
        title: 'Cash Drop Acknowledged',
        message: 'Cashier ${_currentUser.displayName} confirmed receipt of ₦${_cashDrops[idx].amount.toStringAsFixed(0)}.',
        type: NotificationType.success,
        actionRouteName: 'Attendant Home',
      );

      notifyListeners();
    }
    return ok;
  }

  /// Attendant logs in-between POS card or bank transfer payment (§4.4)
  Future<PosTransaction?> recordPosTransaction({
    required String paymentChannel,
    required double amount,
    String? terminalName,
    String? referenceNumber,
    String? storagePath,
    String? customerVehicle,
  }) async {
    final repo = SupabaseRepository.instance;
    final tx = await repo.recordShiftPosTransaction(
      stationCode: _currentStationCode,
      attendantId: _currentUser.id,
      attendantName: _currentUser.displayName,
      paymentChannel: paymentChannel,
      amount: amount,
      terminalName: terminalName,
      referenceNumber: referenceNumber,
      storagePath: storagePath,
      customerVehicle: customerVehicle,
      shiftId: currentShiftId,
    );

    if (tx != null) {
      _posTransactions.removeWhere((p) => p.id == tx.id);
      _posTransactions.insert(0, tx);

      // Offline: queue for shift_pos_transactions (previously a bogus
      // evidencePhoto enqueue dispatched to the photo uploader and always
      // failed).
      if (!repo.isConnected) {
        _syncService.enqueue(
          actionType: SyncActionType.posTransaction,
          payload: tx.toJson(),
        );
      }

      notifyListeners();
    }
    return tx;
  }
}

