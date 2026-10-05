import 'package:flutter/material.dart';
import '../core/offline/offline_sync_service.dart';
import '../core/offline/sync_queue_item.dart';
import '../core/utils/currency_formatter.dart';
import '../models/credit_customer.dart';
import '../models/nozzle.dart';
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

  LiveTankStock({
    required this.code,
    required this.product,
    required this.capacity,
    required this.bookStock,
    required this.physicalDip,
    required this.lastDipTime,
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
  String status; // 'Pending Review', 'Salary Deduction Approved', 'Waived by Senior'
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

  // 1. Current Session
  UserProfile _currentUser = UserProfile.demoStaff[0]; // Amaka O.
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

  // 11. Daily Cash Drawer State
  double _openingCash = 120000.0;
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
      ),
      LiveTankStock(
        code: 'T2',
        product: 'PMS',
        capacity: 45000,
        bookStock: 28520,
        physicalDip: 28400, // -120L deficit
        lastDipTime: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      LiveTankStock(
        code: 'T3',
        product: 'AGO',
        capacity: 33000,
        bookStock: 14200,
        physicalDip: 14200,
        lastDipTime: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];

    _creditCustomers = List.from(CreditCustomer.getDemoCustomers());

    // Initial seed submission in queue
    _submissions.add(
      ShiftSubmission(
        id: 'SHIFT-20261005-01',
        attendantName: 'Amaka O.',
        attendantId: 'attendant-1',
        shiftType: 'Morning',
        submittedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        nozzles: [
          NozzleItem(
            nozzleNumber: 1,
            productName: 'PMS',
            tankCode: 'T1',
            openingReading: 412380.5,
            closingReading: 413102.0,
            pricePerLitre: 1050.0,
            isOpeningConfirmed: true,
          ),
          NozzleItem(
            nozzleNumber: 3,
            productName: 'AGO',
            tankCode: 'T3',
            openingReading: 201775.5,
            closingReading: 202198.0,
            pricePerLitre: 1320.0,
            isOpeningConfirmed: true,
          ),
        ],
        expectedSalesValue: 1250000.0,
        cashDeclared: 640000.0,
        posCardDeclared: 310000.0,
        posTransferDeclared: 120000.0,
        bankTransferDeclared: 0.0,
        creditSalesDeclared: 180000.0,
        evidencePhotos: ['POS Settlement Slip #01', 'Transfer Alert Slip #02'],
        status: 'Pending Verification',
      ),
    );

    // Initial seed deposits
    _deposits.add(
      BankDepositRecord(
        id: 'DEP-01',
        stationName: 'Lekki Road Station',
        amount: 500000.0,
        cashierName: 'Chidi E.',
        bankName: 'GTBank (Main Account)',
        handedOverAt: DateTime.now().subtract(const Duration(hours: 3)),
        isConfirmed: false,
      ),
    );

    // Initial seed salary adjustment
    _salaryAdjustments.add(
      SalaryAdjustment(
        id: 'DISC-01',
        attendantName: 'Bello S.',
        station: 'Lekki Road',
        shiftRef: 'Morning Shift · Yesterday',
        amount: -4500.0,
        status: 'Pending Review',
        recordedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
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
    final totalExpected = expectedSales > 0 ? expectedSales : 1250000.0;
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
      evidencePhotos: evidencePhotos.isEmpty ? ['POS Settlement Slip #1'] : evidencePhotos,
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

    notifyListeners();
  }

  /// Senior approves salary deduction
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

  /// Senior waives attendant shortage
  void waiveShortage(String adjustmentId) {
    final adj = _salaryAdjustments.firstWhere((a) => a.id == adjustmentId);
    adj.status = 'Waived by Senior';

    _syncService.enqueue(
      actionType: SyncActionType.salaryAdjustment,
      payload: {
        'id': adjustmentId,
        'status': 'Waived by Senior',
      },
    );

    notifyListeners();
  }

  /// Senior confirms bank deposit against bank alert (§4.3, §5.5)
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
}
