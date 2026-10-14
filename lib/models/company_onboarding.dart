/// Saved configuration is distinct from authorization to begin live operations.
class CompanyOnboarding {
  const CompanyOnboarding(
      {required this.workspace,
      required this.policyConfigured,
      required this.stationCount,
      required this.infrastructureConfigured,
      required this.staffCount,
      required this.unlinkedStaff,
      required this.tabletAuthenticationAvailable});
  final Map<String, dynamic>? workspace;
  final bool policyConfigured,
      infrastructureConfigured,
      tabletAuthenticationAvailable;
  final int stationCount, staffCount, unlinkedStaff;

  factory CompanyOnboarding.fromJson(Map<String, dynamic> json) =>
      CompanyOnboarding(
        workspace: json['workspace'] is Map
            ? Map<String, dynamic>.from(json['workspace'] as Map)
            : null,
        policyConfigured: json['policy_configured'] == true,
        stationCount: (json['active_stations'] as num?)?.toInt() ?? 0,
        infrastructureConfigured: json['infrastructure_configured'] == true,
        staffCount: (json['active_staff'] as num?)?.toInt() ?? 0,
        unlinkedStaff: (json['unlinked_staff'] as num?)?.toInt() ?? -1,
        tabletAuthenticationAvailable:
            json['tablet_authentication_available'] == true,
      );

  List<bool> get configuredSteps => [
        workspace != null, policyConfigured, stationCount > 0,
        infrastructureConfigured, staffCount > 0 && unlinkedStaff == 0,
        tabletAuthenticationAvailable,
        false, // Live readiness is never inferred from these configuration counts.
      ];
  int get resumeStep {
    final index = configuredSteps.indexOf(false);
    return index < 0 ? 6 : index;
  }

  bool get configurationComplete =>
      configuredSteps.take(6).every((step) => step);

  static bool validCompanyName(String value) =>
      value.trim().length >= 2 && value.trim().length <= 150;
  static bool validOptionalWebUrl(String value) {
    if (value.trim().isEmpty) return true;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.host != 'localhost' &&
        uri.host != '127.0.0.1' &&
        uri.host != '::1' &&
        !RegExp(r'\s').hasMatch(value);
  }
}
