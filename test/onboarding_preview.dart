// Visual QA entrypoint ONLY. Never build or distribute this instead of lib/main.dart.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ajadico_gas/core/theme/app_theme.dart';
import 'package:ajadico_gas/features/onboarding/company_setup_screen.dart';
import 'package:ajadico_gas/models/company_onboarding.dart';
import 'package:ajadico_gas/models/user_profile.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  if (kReleaseMode)
    throw StateError('Onboarding preview cannot run as a release');
  WidgetsFlutterBinding.ensureInitialized();
  final state = StationAppState.instance;
  state.setCurrentUser(const UserProfile(
      id: 'test-only-director',
      displayName: 'Test director',
      fullName: 'Test director',
      role: UserRole.director,
      stationName: ''));
  runApp(MaterialApp(
      title: 'Onboarding QA — not a release',
      theme: AppTheme.lightTheme,
      home: CompanySetupScreen.forTesting(
        onContinue: () {},
        onSignOut: () {},
        statusLoader: () async => CompanyOnboarding.fromJson({}),
      )));
}
