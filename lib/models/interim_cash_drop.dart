class InterimCashDrop {
  final String id;
  final String? shiftId;
  final String stationId;
  final String attendantId;
  final String attendantName;
  final double amount;
  String status; // 'pending', 'acknowledged'
  String? acknowledgedBy;
  DateTime? acknowledgedAt;
  final String? notes;
  final DateTime createdAt;

  InterimCashDrop({
    required this.id,
    this.shiftId,
    required this.stationId,
    required this.attendantId,
    required this.attendantName,
    required this.amount,
    this.status = 'pending',
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.notes,
    required this.createdAt,
  });

  bool get isAcknowledged => status == 'acknowledged';

  factory InterimCashDrop.fromJson(Map<String, dynamic> json) {
    final attendantProfile = json['profiles'] as Map?;
    final attendantName = attendantProfile?['display_name'] ?? attendantProfile?['full_name'] ?? 'Attendant';

    return InterimCashDrop(
      id: json['id'] as String,
      shiftId: json['shift_id'] as String?,
      stationId: json['station_id'] as String? ?? 'LEKKI-01',
      attendantId: json['attendant_id'] as String? ?? '',
      attendantName: attendantName,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      acknowledgedBy: json['acknowledged_by'] as String?,
      acknowledgedAt: json['acknowledged_at'] != null ? DateTime.tryParse(json['acknowledged_at']) : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shift_id': shiftId,
      'station_id': stationId,
      'attendant_id': attendantId,
      'amount': amount,
      'status': status,
      'acknowledged_by': acknowledgedBy,
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
