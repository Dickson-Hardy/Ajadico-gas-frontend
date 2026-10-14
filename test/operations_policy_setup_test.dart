import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajadico_gas/core/widgets/operations_policy_setup_card.dart';
import 'package:ajadico_gas/core/theme/app_theme.dart';
import 'package:ajadico_gas/models/user_profile.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  testWidgets('Setup starts blank and never saves a policy optimistically',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = StationAppState.instance;
    state.setCurrentUser(const UserProfile(
        id: 'fixture-director',
        displayName: 'Test director',
        fullName: 'Test director',
        role: UserRole.director,
        stationName: 'Test station'));
    expect(state.operationsPolicy, isNull);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!),
        home: const Scaffold(
            body: SingleChildScrollView(child: OperationsPolicySetupCard()))));
    await tester.tap(find.text('Configure approval policy'));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, isEmpty);
    }
    await tester.tap(find.text('Save company policy'));
    await tester.pump();
    expect(find.textContaining('Enter non-negative limits'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '3500');
    await tester.enterText(find.byType(TextField).at(1), '27500');
    await tester.enterText(find.byType(TextField).at(2), 'Maintenance');
    await tester.tap(find.text('Save company policy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not saved.'), findsOneWidget);
    expect(state.operationsPolicy, isNull);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard policy changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
