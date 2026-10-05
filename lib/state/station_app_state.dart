import 'package:flutter/material.dart';
import '../core/network/supabase_repository.dart';
import '../core/notifications/forecourt_notification.dart';
import '../core/notifications/notification_service.dart';
import '../core/offline/offline_sync_service.dart';
import '../core/offline/sync_queue_item.dart';
import '../core/utils/currency_formatter.dart';
import '../models/credit_customer.dart';
import '../models/nozzle.dart';
import '../models/station.dart';
import '../models/user_profile.dart';

/// Models for real-time forecourt operations
class ShiftSubmission {
  final String id;
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
  String status; // 'Pending Verification', 'Verified', 'Flagged Unresolved'
  String? cashierComment;
  DateTime? verifiedAt;

  ShiftSubmission({
    required this.id,
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
    this.status = 'Pending Verification',
    this.cashierComment,
    this.verifiedAt,
  });

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
  final String paymentSource; // 'sales_cash' or 'bank_transfer'
  final String description;
  final String recordedBy;
  final DateTime recordedAt;

  BranchExpense({
    required this.id,
    required this.category,
    required this.amount,
    required this.paymentSource,
    required this.description,
    required this.recordedBy,
    required this.recordedAt,
  });
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

class BankDepositRecord {
  final String id;
  final String stationName;
  final double amount;
  final String cashierName;
  final String bankName;
  final DateTime handedOverAt;
  bool isConfirmed;
  DateTime? confirmedAt;

  BankDepositRecord({
    required this.id,
    required this.stationName,
    required this.amount,
    required this.cashierName,
    required this.bankName,
    required this.handedOverAt,
    this.isConfirmed = false,
    this.confirmedAt,
  });
}

/// Central Reactive State Store for the entire Filling Station System
/// Integrates with OfflineSyncService (Phase 2), Camera (Phase 3), and Kiosk (Phase 4)
class StationAppState extends ChangeNotifier {
  static final StationAppState instance = StationAppState._internal();
  StationAppState._internal() {
    _initDefaultState();
  }

  final _syncService = OfflineSyncService.instance;
  final _notifService = NotificationService.instance;

  // 1. Current Session
  UserProfile _currentUser = UserProfile.defaultDirector;
  UserProfile get currentUser => _currentUser;

  void setCurrentUser(UserProfile user) {
    _currentUser = user;
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

  // 10. Bank Deposits
  final List<BankDepositRecord> _deposits = [];
  List<BankDepositRecord> get deposits => List.unmodifiable(_deposits);

  // 11. Staff & Attendants (§2.1–§2.4)
  List<UserProfile> _staff = [];
  List<UserProfile> get staff => List.unmodifiable(_staff);

  // 12. Daily Cash Drawer State
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
    _nozzles = [
      NozzleItem(
        nozzleNumber: 1,
        productName: 'PMS',
        tankCode: 'T1',
        openingReading: 412380.5,
        pricePerLitre: _pmsPrice,
        isOpeningConfirmed: true,
      ),
      NozzleItem(
        nozzleNumber: 2,
        productName: 'PMS',
        tankCode: 'T1',
        openingReading: 388102.0,
        pricePerLitre: _pmsPrice,
        isOpeningConfirmed: false,
      ),
      NozzleItem(
        nozzleNumber: 3,
        productName: 'AGO',
        tankCode: 'T3',
        openingReading: 201775.5,
        pricePerLitre: _agoPrice,
        isOpeningConfirmed: true,
      ),
    ];

    _tanks = [
      LiveTankStock(
        code: 'T1',
        product: 'PMS',
        capacity: 45000,
        bookStock: 32100,
        physicalDip: 32100,
        lastDipTime: DateTime.now().subtract(const Duration(hours: 4)),
        isInterlocked: true,
        isActiveSupply: true,
      ),
      LiveTankStock(
        code: 'T2',
        product: 'PMS',
        capacity: 45000,
        bookStock: 28520,
        physicalDip: 28400, // -120L deficit
        lastDipTime: DateTime.now().subtract(const Duration(hours: 4)),
        isInterlocked: true,
        isActiveSupply: false,
      ),
      LiveTankStock(
        code: 'T3',
        product: 'AGO',
        capacity: 33000,
        bookStock: 14200,
        physicalDip: 14200,
        lastDipTime: DateTime.now().subtract(const Duration(hours: 4)),
        isInterlocked: false,
        isActiveSupply: true,
      ),
    ];

    _creditCustomers = List.from(CreditCustomer.getDefaultCustomers());
    _staff = [];
    // Submissions, deposits, salary adjustments, expenses, and staff start empty (0 mock transactions).
    // They populate dynamically via live Supabase queries or actual forecourt operations.
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
      }

      final stationInfo = await repo.fetchStationInfo(_currentStationCode);
      if (stationInfo != null) {
        _hasInterlockedTanks = stationInfo['has_interlocked_tanks'] ?? false;
        _currentStationName = stationInfo['name'] ?? _currentStationName;
      } else if (_stations.isNotEmpty) {
        final match = _stations.firstWhere(
          (s) => s.code == _currentStationCode,
          orElse: () => _stations.first,
        );
        _currentStationCode = match.code;
        _currentStationName = match.name;
        _hasInterlockedTanks = match.hasInterlockedTanks;
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
      final remoteCustomers = await repo.fetchCreditLedger('LEKKI-01');
      if (remoteCustomers.isNotEmpty) {
        _creditCustomers = remoteCustomers;
      }

      // 5. Fetch live expenses
      final remoteExpenses = await repo.fetchLiveExpenses('LEKKI-01');
      _expenses.clear();
      for (final e in remoteExpenses) {
        _expenses.add(
          BranchExpense(
            id: e['id'] as String,
            category: e['category'] as String,
            amount: (e['amount'] as num).toDouble(),
            paymentSource: e['payment_source'] ?? 'Cash Drawer',
            description: e['description'] ?? '',
            recordedBy: 'Branch Manager',
            recordedAt: DateTime.tryParse(e['created_at'] ?? '') ?? DateTime.now(),
          ),
        );
      }

      // 6. Fetch live salary adjustments
      final remoteSalary = await repo.fetchLiveSalaryAdjustments('LEKKI-01');
      _salaryAdjustments.clear();
      for (final s in remoteSalary) {
        _salaryAdjustments.add(
          SalaryAdjustment(
            id: s['id'] as String,
            attendantName: s['attendant_name'] ?? 'Attendant',
            station: 'Lekki Road Station',
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
    } catch (e) {
      debugPrint('[Supabase Sync Error]: $e');
    } finally {
      _isSyncingWithRemote = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // REAL-TIME ACTIONS & RECONCILIATION LOGIC (PHASE 1 & PHASE 2 QUEUING)
  // ---------------------------------------------------------------------------

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
        'shiftId': 'SHIFT-${DateTime.now().millisecondsSinceEpoch}',
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
  }) {
    final expectedSales = _nozzles.fold(0.0, (s, n) => s + n.salesValue);
    final totalExpected = expectedSales;
    final shiftId = 'SHIFT-${DateTime.now().millisecondsSinceEpoch}';

    final sub = ShiftSubmission(
      id: shiftId,
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
      }
    }

    // Dispatch to Offline Sync Service
    _syncService.enqueue(
      actionType: SyncActionType.remittanceSubmission,
      payload: {
        'shiftId': shiftId,
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

    // If there is any shortage or excess, immediately log to Attendant Salary Ledger (§4.6)
    if (!sub.isBalanced) {
      _salaryAdjustments.insert(
        0,
        SalaryAdjustment(
          id: 'DISC-${DateTime.now().millisecondsSinceEpoch}',
          attendantName: sub.attendantName,
          station: 'Lekki Road',
          shiftRef: '${sub.shiftType} Shift (${sub.id})',
          amount: sub.variance,
          status: 'Pending Review',
          recordedAt: DateTime.now(),
        ),
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

    _salaryAdjustments.insert(
      0,
      SalaryAdjustment(
        id: 'DISC-${DateTime.now().millisecondsSinceEpoch}',
        attendantName: sub.attendantName,
        station: 'Lekki Road',
        shiftRef: '${sub.shiftType} Shift (${sub.id})',
        amount: sub.variance,
        status: 'Pending Review',
        recordedAt: DateTime.now(),
      ),
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

    // Queue in Offline Sync Engine
    _syncService.enqueue(
      actionType: SyncActionType.creditSale,
      payload: {
        'customerId': customerId,
        'customerName': customer.name,
        'nozzleNumber': nozzleNumber,
        'litres': litres,
        'totalAmount': saleValue,
        'vehicleReg': vehiclePlate,
        'driverName': driverName,
      },
    );

    notifyListeners();
  }

  /// Record Branch Expense (§5.1, §5.2)
  void recordExpense({
    required String category,
    required double amount,
    required String paymentSource,
    required String description,
  }) {
    final expId = 'EXP-${DateTime.now().millisecondsSinceEpoch}';

    _expenses.insert(
      0,
      BranchExpense(
        id: expId,
        category: category,
        amount: amount,
        paymentSource: paymentSource,
        description: description,
        recordedBy: _currentUser.displayName,
        recordedAt: DateTime.now(),
      ),
    );

    // Queue in Offline Sync Engine
    _syncService.enqueue(
      actionType: SyncActionType.branchExpense,
      payload: {
        'id': expId,
        'category': category,
        'amount': amount,
        'payment_source': paymentSource,
        'description': description,
        'station_id': 'lekki-01',
      },
    );

    notifyListeners();
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

    _syncService.enqueue(
      actionType: SyncActionType.tankDipAudit,
      payload: {
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
  }) {
    final tank = _tanks.firstWhere((t) => t.code == tankCode);
    tank.bookStock += litres;
    tank.physicalDip += litres;

    _syncService.enqueue(
      actionType: SyncActionType.fuelReturn,
      payload: {
        'tankCode': tankCode,
        'litres': litres,
        'reason': reason,
        'attendantId': _currentUser.id,
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

  /// Director approves salary deduction
  void approveSalaryDeduction(String adjustmentId) {
    final adj = _salaryAdjustments.firstWhere((a) => a.id == adjustmentId);
    adj.status = 'Salary Deduction Approved';

    _syncService.enqueue(
      actionType: SyncActionType.salaryAdjustment,
      payload: {
        'id': adjustmentId,
        'status': 'Salary Deduction Approved',
      },
    );

    notifyListeners();
  }

  /// Director waives attendant shortage
  void waiveShortage(String adjustmentId) {
    final adj = _salaryAdjustments.firstWhere((a) => a.id == adjustmentId);
    adj.status = 'Waived by Director';

    _syncService.enqueue(
      actionType: SyncActionType.salaryAdjustment,
      payload: {
        'id': adjustmentId,
        'status': 'Waived by Director',
      },
    );

    notifyListeners();
  }

  /// Director confirms bank deposit against bank alert (§4.3, §5.5)
  void confirmBankDeposit(String depositId) {
    final dep = _deposits.firstWhere((d) => d.id == depositId);
    dep.isConfirmed = true;
    dep.confirmedAt = DateTime.now();

    _syncService.enqueue(
      actionType: SyncActionType.bankDepositConfirmation,
      payload: {
        'id': depositId,
        'confirmed_at': dep.confirmedAt!.toIso8601String(),
      },
    );

    _notifService.postNotification(
      title: 'Bank Deposit Confirmed',
      message: 'Director confirmed commercial bank credit alert for deposit ${dep.id} (${CurrencyFormatter.formatNaira(dep.amount)}).',
      type: NotificationType.success,
      targetRole: UserRole.cashier,
      actionRouteName: '20 Bank Deposits',
    );

    notifyListeners();
  }

  /// Cash count calculations
  void updateCashCount(int denomination, int count) {
    if (_cashCounts.containsKey(denomination)) {
      _cashCounts[denomination] = count;
      notifyListeners();
    }
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
        .where((e) => e.paymentSource == 'sales_cash')
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalHandedOverDeposits {
    return _deposits.fold(0.0, (sum, d) => sum + d.amount);
  }

  double get expectedClosingCash {
    return _openingCash +
        totalVerifiedCashReceipts -
        totalPhysicalCashExpenses -
        totalHandedOverDeposits;
  }

  double get cashDrawerVariance => totalCountedCash - expectedClosingCash;

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

    _notifService.pushNotification(
      ForecourtNotification(
        id: 'NOTIF-CO-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Manifold Changeover Applied',
        body: 'Switched from $fromTankCode to $toTankCode for $productCode at $_currentStationName.',
        type: ForecourtNotificationType.compliance,
        timestamp: DateTime.now(),
        actionRouteName: '17 Manager Dashboard',
      ),
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
}

