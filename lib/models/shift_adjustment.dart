enum ShiftAdjustmentKind {
  expense,
  calibrationReturn,
  generatorFuel,
  companyVehicle
}

class ShiftAdjustment {
  final String id, shiftId, stationCode, attendantId, attendantName;
  final ShiftAdjustmentKind kind;
  final String category, reason, status;
  final double amount, litres, pricePerLitre;
  final int? nozzleNumber;
  final String? pumpId, pumpName;
  final String? tankCode, reviewedBy, reviewNotes;
  final DateTime createdAt;
  final List<String> evidence;

  const ShiftAdjustment(
      {required this.id,
      required this.shiftId,
      required this.stationCode,
      required this.attendantId,
      required this.attendantName,
      required this.kind,
      required this.reason,
      required this.amount,
      required this.createdAt,
      this.category = '',
      this.litres = 0,
      this.pricePerLitre = 0,
      this.nozzleNumber,
      this.pumpId,
      this.pumpName,
      this.tankCode,
      this.status = 'pending',
      this.reviewedBy,
      this.reviewNotes,
      this.evidence = const []});

  bool get isPending => status == 'pending';
  String get pumpLabel => pumpName?.isNotEmpty == true
      ? pumpName!
      : 'Pump${nozzleNumber ?? "unspecified"}';
  bool get isApproved => status == 'approved';
  bool get isFuel => kind != ShiftAdjustmentKind.expense;
  String get label => switch (kind) {
        ShiftAdjustmentKind.expense => 'Pump expense',
        ShiftAdjustmentKind.calibrationReturn => 'Calibration return',
        ShiftAdjustmentKind.generatorFuel => 'Generator fuel',
        ShiftAdjustmentKind.companyVehicle => 'Company vehicle fuel',
      };
  String get statusLabel => switch (status) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'Awaiting approval',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'shift_id': shiftId,
        'station_code': stationCode,
        'attendant_id': attendantId,
        'attendant_name': attendantName,
        'kind': kind.name,
        'category': category,
        'reason': reason,
        'amount': amount,
        'litres': litres,
        'price_per_litre': pricePerLitre,
        'nozzle_number': nozzleNumber,
        'nozzle_id': pumpId,
        'pump_name_snapshot': pumpName,
        'tank_code': tankCode,
        'status': status,
        'reviewed_by': reviewedBy,
        'review_notes': reviewNotes,
        'created_at': createdAt.toUtc().toIso8601String(),
        'evidence': evidence,
      };
  factory ShiftAdjustment.fromJson(Map<String, dynamic> row) => ShiftAdjustment(
        id: row['id'] as String,
        shiftId: row['shift_id'] as String,
        stationCode: row['station_code'] as String,
        attendantId: row['attendant_id'] as String,
        attendantName: row['attendant_name'] as String,
        kind: ShiftAdjustmentKind.values.byName(row['kind'] as String),
        category: row['category'] as String? ?? '',
        reason: row['reason'] as String,
        amount: (row['amount'] as num).toDouble(),
        litres: (row['litres'] as num?)?.toDouble() ?? 0,
        pricePerLitre: (row['price_per_litre'] as num?)?.toDouble() ?? 0,
        nozzleNumber: (row['nozzle_number'] as num?)?.toInt(),
        pumpId: row['nozzle_id'] as String?,
        pumpName: row['pump_name_snapshot'] as String?,
        tankCode: row['tank_code'] as String?,
        status: row['status'] as String? ?? 'pending',
        reviewedBy: row['reviewed_by'] as String?,
        reviewNotes: row['review_notes'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        evidence: List<String>.from(row['evidence'] as List? ?? const []),
      );
}

/// Approved expenses account for cash spent; approved non-sale fuel reduces
/// metered sales collectible. They must not be counted in both places.
class ShiftAdjustmentTotals {
  final List<ShiftAdjustment> entries;
  const ShiftAdjustmentTotals(this.entries);
  bool get hasPending => entries.any((entry) => entry.isPending);
  double get approvedExpenses => entries
      .where((e) => e.isApproved && !e.isFuel)
      .fold(0.0, (sum, e) => sum + e.amount);
  double get approvedFuelValue => entries
      .where((e) => e.isApproved && e.isFuel)
      .fold(0.0, (sum, e) => sum + e.amount);
  double variance(
          {required double grossSales,
          required double money,
          required double credit}) =>
      money + credit + approvedExpenses - (grossSales - approvedFuelValue);
}
