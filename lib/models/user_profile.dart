enum UserRole {
  attendant,
  cashier,
  manager,
  director,
}

class UserProfile {
  final String id;
  final String displayName;
  final String fullName;
  final UserRole role;
  final String stationName;
  final String? stationId;
  final String? phone;
  final String? address; // Staff residential address
  final String? suretyName; // Shortee / Guarantor full name (§2.2)
  final String? suretyPhone; // Shortee / Guarantor phone number
  final String? suretyAddress; // Shortee / Guarantor address
  final double baseSalary;
  final bool isActive;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.fullName,
    required this.role,
    required this.stationName,
    this.stationId,
    this.phone,
    this.address,
    this.suretyName,
    this.suretyPhone,
    this.suretyAddress,
    this.baseSalary = 0.0,
    this.isActive = true,
  });

  /// Default executive session actor for Director oversight
  static const UserProfile defaultDirector = UserProfile(
    id: 'director-1',
    displayName: 'Engr. Dickson (Director)',
    fullName: 'Dickson Hardy (Managing Director)',
    role: UserRole.director,
    stationName: 'HQ · All 5 Stations',
  );

  /// Zero demo data: Staff list starts completely empty and loads from live database
  static const List<UserProfile> demoStaff = [];
}
