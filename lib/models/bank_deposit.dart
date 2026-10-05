class BankDepositRecord {
  final String id;
  final String stationId;
  final String stationName;
  final double amount;
  final String cashierName; // Bearer / Depositor name
  final String bankName;
  final String? tellerNumber;
  final String? slipUrl;
  final String? notes;
  final DateTime handedOverAt;
  bool isConfirmed;
  DateTime? confirmedAt;
  String? confirmedBy;
  String status; // 'awaiting_bank', 'confirmed', 'discrepancy'
  String? directorNotes;

  BankDepositRecord({
    required this.id,
    this.stationId = 'LEKKI-01',
    required this.stationName,
    required this.amount,
    required this.cashierName,
    required this.bankName,
    this.tellerNumber,
    this.slipUrl,
    this.notes,
    required this.handedOverAt,
    this.isConfirmed = false,
    this.confirmedAt,
    this.confirmedBy,
    this.status = 'awaiting_bank',
    this.directorNotes,
  });

  String get bearerName => cashierName;

  factory BankDepositRecord.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? (json['is_confirmed'] == true ? 'confirmed' : 'awaiting_bank');
    return BankDepositRecord(
      id: json['id'] as String,
      stationId: json['station_id'] as String? ?? 'LEKKI-01',
      stationName: json['stations']?['name'] ?? 'Lekki Road Station',
      amount: (json['amount'] as num).toDouble(),
      cashierName: json['bearer_name'] ?? json['cashier_name'] ?? 'Branch Manager',
      bankName: json['bank_name'] as String? ?? 'Zenith Bank',
      tellerNumber: json['teller_number'] as String?,
      slipUrl: json['slip_url'] as String?,
      notes: json['notes'] as String?,
      handedOverAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isConfirmed: statusStr == 'confirmed' || json['is_confirmed'] == true,
      confirmedAt: json['confirmed_at'] != null ? DateTime.tryParse(json['confirmed_at']) : null,
      confirmedBy: json['confirmed_by'] as String?,
      status: statusStr,
      directorNotes: json['director_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'amount': amount,
      'bank_name': bankName,
      'bearer_name': cashierName,
      'teller_number': tellerNumber,
      'slip_url': slipUrl,
      'notes': notes,
      'status': isConfirmed ? 'confirmed' : status,
      'is_confirmed': isConfirmed,
      'confirmed_at': confirmedAt?.toIso8601String(),
      'confirmed_by': confirmedBy,
      'director_notes': directorNotes,
      'created_at': handedOverAt.toIso8601String(),
    };
  }
}
