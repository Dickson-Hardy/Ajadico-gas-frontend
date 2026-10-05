class Station {
  final String id;
  final String code;
  final String name;
  final String? address;
  final String? state;
  final String? managerName;
  final String? phone;
  final bool isActive;
  final bool hasInterlockedTanks;

  const Station({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.state,
    this.managerName,
    this.phone,
    this.isActive = true,
    this.hasInterlockedTanks = false,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      state: json['state'] as String?,
      managerName: json['manager_name'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] ?? true,
      hasInterlockedTanks: json['has_interlocked_tanks'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'address': address,
      'state': state,
      'manager_name': managerName,
      'phone': phone,
      'is_active': isActive,
      'has_interlocked_tanks': hasInterlockedTanks,
    };
  }
}
