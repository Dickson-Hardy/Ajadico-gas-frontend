class MonthlyPayrollSettlement {
  final String id;
  final String attendantId;
  final String attendantName;
  final String stationName;
  final String monthYear; // e.g. "October 2026"
  final double baseSalary;
  final double totalShortagesDeducted;
  final double totalExcessesCredited;
  final double netPayable;
  final double carriedDeficit;
  final int shortfallShiftCount;
  final String settledBy;
  final DateTime settledAt;
  final String status; // 'Settled'

  const MonthlyPayrollSettlement({
    required this.id,
    required this.attendantId,
    required this.attendantName,
    required this.stationName,
    required this.monthYear,
    required this.baseSalary,
    required this.totalShortagesDeducted,
    required this.totalExcessesCredited,
    required this.netPayable,
    required this.carriedDeficit,
    required this.shortfallShiftCount,
    required this.settledBy,
    required this.settledAt,
    this.status = 'Settled',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'attendant_id': attendantId,
    'attendant_name': attendantName,
    'station_name': stationName,
    'month_year': monthYear,
    'base_salary': baseSalary,
    'total_shortages_deducted': totalShortagesDeducted,
    'total_excesses_credited': totalExcessesCredited,
    'net_payable': netPayable,
    'carried_deficit': carriedDeficit,
    'shortfall_shift_count': shortfallShiftCount,
    'settled_by': settledBy,
    'settled_at': settledAt.toIso8601String(),
    'status': status,
  };

  factory MonthlyPayrollSettlement.fromJson(Map<String, dynamic> json) {
    return MonthlyPayrollSettlement(
      id: json['id'] as String,
      attendantId: json['attendant_id'] as String? ?? '',
      attendantName: json['attendant_name'] as String? ?? '',
      stationName: json['station_name'] as String? ?? '',
      monthYear: json['month_year'] as String? ?? '',
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 0.0,
      totalShortagesDeducted: (json['total_shortages_deducted'] as num?)?.toDouble() ?? 0.0,
      totalExcessesCredited: (json['total_excesses_credited'] as num?)?.toDouble() ?? 0.0,
      netPayable: (json['net_payable'] as num?)?.toDouble() ?? 0.0,
      carriedDeficit: (json['carried_deficit'] as num?)?.toDouble() ?? 0.0,
      shortfallShiftCount: json['shortfall_shift_count'] as int? ?? 0,
      settledBy: json['settled_by'] as String? ?? 'Director',
      settledAt: DateTime.tryParse(json['settled_at'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'Settled',
    );
  }
}
