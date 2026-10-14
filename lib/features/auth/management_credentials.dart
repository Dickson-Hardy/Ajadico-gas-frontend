/// Management uses email verification; station staff use a separate PIN flow.
class ManagementCredentials {
  static bool validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  static bool validCode(String value) =>
      RegExp(r'^\d{6,8}$').hasMatch(value.trim());
}
