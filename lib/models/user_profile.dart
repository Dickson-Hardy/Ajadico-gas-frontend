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

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.fullName,
    required this.role,
    required this.stationName,
  });

  static const List<UserProfile> demoStaff = [
    UserProfile(
      id: 'attendant-1',
      displayName: 'Amaka O.',
      fullName: 'Amaka Okonkwo',
      role: UserRole.attendant,
      stationName: 'Lekki Road Station',
    ),
    UserProfile(
      id: 'attendant-2',
      displayName: 'Bello S.',
      fullName: 'Bello Salami',
      role: UserRole.manager,
      stationName: 'Lekki Road Station',
    ),
    UserProfile(
      id: 'attendant-3',
      displayName: 'Chidi E.',
      fullName: 'Chidi Eze',
      role: UserRole.cashier,
      stationName: 'Lekki Road Station',
    ),
    UserProfile(
      id: 'attendant-4',
      displayName: 'Fatima A.',
      fullName: 'Fatima Abubakar',
      role: UserRole.attendant,
      stationName: 'Lekki Road Station',
    ),
    UserProfile(
      id: 'director-1',
      displayName: 'Senior',
      fullName: 'Senior Director',
      role: UserRole.director,
      stationName: 'All Branches',
    ),
  ];
}
