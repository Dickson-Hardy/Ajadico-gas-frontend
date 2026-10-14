import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajadico_gas/core/offline/offline_sync_service.dart';
import 'package:ajadico_gas/core/widgets/pump_editor_dialog.dart';
import 'package:ajadico_gas/models/nozzle.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  tearDownAll(() => OfflineSyncService.instance.dispose());
  testWidgets(
      'arbitrary pump names retain ID and cannot report an offline rename',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final point = NozzleItem(
        id: '00000000-0000-4000-8000-000000000001',
        displayName: 'Pump1a',
        nozzleNumber: 1,
        productName: 'PMS',
        tankCode: 'T1',
        openingReading: 0,
        pricePerLitre: 1);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => PumpEditorDialog(pump: point)),
                    child: const Text('Edit'))))));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Diesel Left');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save not confirmed.'), findsOneWidget);
    expect(point.label, 'Pump1a');
    expect(point.id, '00000000-0000-4000-8000-000000000001');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard pump changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    StationAppState.instance.clearSession();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
