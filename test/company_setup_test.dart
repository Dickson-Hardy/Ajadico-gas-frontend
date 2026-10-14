import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajadico_gas/core/offline/offline_sync_service.dart';
import 'package:ajadico_gas/features/onboarding/company_setup_screen.dart';
import 'package:ajadico_gas/models/company_onboarding.dart';
import 'package:ajadico_gas/models/user_profile.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  tearDownAll(() => OfflineSyncService.instance.dispose());
  testWidgets('APK company form accepts no URL but never saves offline',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = StationAppState.instance;
    state.setCurrentUser(const UserProfile(
        id: 'fixture-director',
        displayName: 'Director',
        fullName: 'Test director',
        role: UserRole.director,
        stationName: ''));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(MaterialApp(
        home: CompanySetupScreen.forTesting(
            onContinue: () {},
            onSignOut: () {},
            statusLoader: () async => CompanyOnboarding.fromJson({}))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 1 of 7'), findsOneWidget);
    await tester.tap(find.text('Enter company details'));
    await tester.pumpAndSettle();
    expect(find.text('Web URL (optional)'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).first, 'Test Company Limited');
    await tester.tap(find.text('Save company'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not saved.'), findsOneWidget);
    expect(find.text('Enter your deployed HTTPS web address.'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    for (var step = 0; step < 6; step++) {
      await tester.ensureVisible(find.text('Next step'));
      await tester.tap(find.text('Next step'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Not approved for live operations.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.clearSession();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('a non-director cannot enter company setup', (tester) async {
    SharedPreferences.setMockInitialValues({});
    StationAppState.instance.clearSession();
    await tester.pumpWidget(MaterialApp(
        home: CompanySetupScreen.forTesting(
            onContinue: () {},
            onSignOut: () {},
            statusLoader: () async => CompanyOnboarding.fromJson({}))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Setup could not be loaded.'), findsOneWidget);
    expect(find.text('Enter company details'), findsNothing);
  });
}
