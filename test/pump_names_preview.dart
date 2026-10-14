// Debug-only visual QA. No backend connection or production equipment catalog.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ajadico_gas/core/theme/app_theme.dart';
import 'package:ajadico_gas/core/widgets/pump_editor_dialog.dart';
import 'package:ajadico_gas/models/nozzle.dart';
import 'package:ajadico_gas/models/station.dart';
import 'package:ajadico_gas/models/user_profile.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  if (kReleaseMode) throw StateError('Pump preview is not a release target');
  WidgetsFlutterBinding.ensureInitialized();
  final state = StationAppState.instance;
  state.switchStation(const Station(
      id: '00000000-0000-4000-8000-000000000010',
      code: 'QA',
      name: 'QA station'));
  state.setCurrentUser(const UserProfile(
      id: 'test-director',
      displayName: 'Test director',
      fullName: 'Test director',
      role: UserRole.director,
      stationName: 'QA station'));
  state.tanks.add(LiveTankStock(
      code: 'T1',
      product: 'PMS',
      capacity: 10000,
      bookStock: 0,
      physicalDip: 0,
      lastDipTime: DateTime.utc(2026)));
  for (var i = 1; i <= 2; i++) {
    state.nozzles.add(NozzleItem(
        id: '00000000-0000-4000-8000-00000000000$i',
        displayName: i == 1 ? 'Pump1a' : 'Pump1b',
        nozzleNumber: i,
        productName: 'PMS',
        tankCode: 'T1',
        openingReading: 0,
        pricePerLitre: 1));
  }
  runApp(MaterialApp(
      title: 'Pump names QA — not a release',
      theme: AppTheme.lightTheme,
      home: const _Preview()));
}

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Pumps & dispensing points')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text(
            'QA fixture only. Saves intentionally fail without a verified backend session.'),
        const SizedBox(height: 16),
        for (final point in StationAppState.instance.nozzles)
          ListTile(
              title: Text(point.label),
              subtitle: Text('${point.productName} · Tank ${point.tankCode}'),
              trailing: IconButton(
                  tooltip: 'Rename ${point.label}',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => PumpEditorDialog(pump: point)))),
        FilledButton(
            onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const PumpEditorDialog()),
            child: const Text('Add pump')),
      ]));
}
