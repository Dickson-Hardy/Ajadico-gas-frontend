import '../lib/models/company_onboarding.dart';

void main() {
  var checks = 0;
  void check(bool condition) {
    if (!condition) throw StateError('Onboarding check ${checks + 1} failed');
    checks++;
  }

  check(CompanyOnboarding.validOptionalWebUrl(''));
  check(CompanyOnboarding.validOptionalWebUrl('   '));
  check(CompanyOnboarding.validOptionalWebUrl('https://company.example'));
  check(CompanyOnboarding.validOptionalWebUrl('https://company.example/app'));
  for (final url in [
    'http://company.example',
    'https://localhost',
    'https://127.0.0.1',
    'https://user:password@company.example',
    'https://company.example?key=x',
    'https://company.example/#token',
    'https://company .example'
  ]) {
    check(!CompanyOnboarding.validOptionalWebUrl(url));
  }
  check(CompanyOnboarding.validCompanyName('Company Limited'));
  check(!CompanyOnboarding.validCompanyName(' '));
  check(!CompanyOnboarding.validCompanyName('x' * 151));
  check(CompanyOnboarding.fromJson({}).resumeStep == 0);
  final data = <String, dynamic>{
    'workspace': {'company_name': 'Test company', 'web_url': null},
    'policy_configured': true,
    'active_stations': 1,
    'infrastructure_configured': true,
    'active_staff': 3,
    'unlinked_staff': 0,
    'tablet_authentication_available': false
  };
  check(CompanyOnboarding.fromJson(data).resumeStep == 5);
  check(!CompanyOnboarding.fromJson(data).configurationComplete);
  check(CompanyOnboarding.fromJson({...data, 'unlinked_staff': 1}).resumeStep ==
      4);
  check(
      CompanyOnboarding.fromJson({...data, 'infrastructure_configured': false})
              .resumeStep ==
          3);
  check(
      CompanyOnboarding.fromJson({...data, 'active_stations': 0}).resumeStep ==
          2);
  check(CompanyOnboarding.fromJson({...data, 'policy_configured': false})
          .resumeStep ==
      1);
  final configured = CompanyOnboarding.fromJson(
      {...data, 'tablet_authentication_available': true});
  check(configured.configurationComplete);
  check(configured.resumeStep == 6);
  check(!configured
      .configuredSteps.last); // Configuration never certifies launch.
  check(CompanyOnboarding.fromJson({...data, 'unlinked_staff': null})
          .resumeStep ==
      4);
  print('$checks APK-first onboarding checks passed');
}
