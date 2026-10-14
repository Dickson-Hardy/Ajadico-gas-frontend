import '../lib/features/auth/management_credentials.dart';

void main() {
  var checks = 0;
  void check(bool result) {
    if (!result)
      throw StateError('Credential validation check ${checks + 1} failed');
    checks++;
  }

  check(ManagementCredentials.validEmail('director@company.test'));
  check(ManagementCredentials.validEmail(' manager@company.test '));
  for (final value in [
    '',
    'director',
    'x@y',
    'x y@company.test',
    'x@@company.test'
  ]) {
    check(!ManagementCredentials.validEmail(value));
  }
  check(ManagementCredentials.validCode('123456'));
  check(ManagementCredentials.validCode('12345678'));
  for (final value in ['', '1234', '123456789', '12ab56', '123 456']) {
    check(!ManagementCredentials.validCode(value));
  }
  print('$checks management credential checks passed');
}
