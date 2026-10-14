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

  /// Neutral identity while no authenticated session is active.
  static const signedOut = UserProfile(
    id: '',
    displayName: 'Not signed in',
    fullName: 'Not signed in',
    role: UserRole.attendant,
    stationName: '',
    isActive: false,
  );
}
