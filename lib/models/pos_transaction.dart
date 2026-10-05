class PosTransaction {
  final String id;
  final String? shiftId;
  final String stationId;
  final String attendantId;
  final String attendantName;
  final String paymentChannel; // 'pos_card', 'pos_transfer', 'bank_transfer'
  final double amount;
  final String? terminalName; // e.g. 'Moniepoint POS 1', 'OPay POS 2', 'Stanbic'
  final String? referenceNumber; // e.g. RRN, Auth code, session ID
  final String? storagePath; // Slip photo URL/path
  final String? customerVehicle; // Vehicle registration plate if entered
  final DateTime createdAt;

  PosTransaction({
    required this.id,
    this.shiftId,
    required this.stationId,
    required this.attendantId,
    required this.attendantName,
    required this.paymentChannel,
    required this.amount,
    this.terminalName,
    this.referenceNumber,
    this.storagePath,
    this.customerVehicle,
    required this.createdAt,
  });

  String get channelDisplayName {
    switch (paymentChannel) {
      case 'pos_card':
        return 'POS Card';
      case 'pos_transfer':
        return 'POS Transfer';
      case 'bank_transfer':
        return 'Direct Bank Transfer';
      default:
        return 'Card / POS';
    }
  }

  factory PosTransaction.fromJson(Map<String, dynamic> json) {
    final attendantProfile = json['profiles'] as Map?;
    final attendantName = attendantProfile?['display_name'] ?? attendantProfile?['full_name'] ?? 'Attendant';

    return PosTransaction(
      id: json['id'] as String,
      shiftId: json['shift_id'] as String?,
      stationId: json['station_id'] as String? ?? 'LEKKI-01',
      attendantId: json['attendant_id'] as String? ?? '',
      attendantName: attendantName,
      paymentChannel: json['payment_channel'] as String? ?? 'pos_card',
      amount: (json['amount'] as num).toDouble(),
      terminalName: json['terminal_name'] as String?,
      referenceNumber: json['reference_number'] as String?,
      storagePath: json['storage_path'] as String?,
      customerVehicle: json['customer_vehicle'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shift_id': shiftId,
      'station_id': stationId,
      'attendant_id': attendantId,
      'payment_channel': paymentChannel,
      'amount': amount,
      'terminal_name': terminalName,
      'reference_number': referenceNumber,
      'storage_path': storagePath,
      'customer_vehicle': customerVehicle,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
