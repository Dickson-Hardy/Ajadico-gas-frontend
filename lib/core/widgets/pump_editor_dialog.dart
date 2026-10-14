import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/nozzle.dart';
import '../../state/station_app_state.dart';
import '../network/supabase_repository.dart';

/// Configure actual station equipment. Never fabricates an offline saved pump.
class PumpEditorDialog extends StatefulWidget {
  const PumpEditorDialog({super.key, this.pump});
  final NozzleItem? pump;
  @override
  State<PumpEditorDialog> createState() => _PumpEditorDialogState();
}

class _PumpEditorDialogState extends State<PumpEditorDialog> {
  final state = StationAppState.instance;
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  final meter = TextEditingController();
  late final String requestId, stationId;
  String? product, tank, error;
  bool saving = false, dirty = false;
  bool get editing => widget.pump != null;
  @override
  void initState() {
    super.initState();
    requestId = SupabaseRepository.instance.generateUuid();
    stationId = state.currentStationId;
    name = TextEditingController(text: widget.pump?.label ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    meter.dispose();
    super.dispose();
  }

  void changed(String _) => setState(() {
        dirty = true;
        error = null;
      });
  Future<void> close() async {
    if (saving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Discard pump changes?'),
                  content: const Text('These changes have not been saved.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Keep editing')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Discard')),
                  ]));
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> save() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    if (state.currentStationId != stationId) {
      setState(() => error =
          'Station changed. Close this form and reopen it at the intended station.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    bool success;
    if (editing) {
      success = await state.renamePump(widget.pump!.id, name.text);
    } else {
      success = await state.createNozzle(
              displayName: name.text,
              productCode: product!,
              tankCode: tank!,
              latestMeterReading:
                  double.parse(meter.text.trim().replaceAll(',', '')),
              requestId: requestId) ==
          'created';
    }
    if (!mounted) return;
    if (success) {
      dirty = false;
      Navigator.pop(context, true);
    } else
      setState(() {
        saving = false;
        error =
            'Save not confirmed. A verified director connection and the named-pump migration are required. Check for a duplicate name, then retry or refresh the station.';
      });
  }

  @override
  Widget build(BuildContext context) {
    final products = state.tanks.map((t) => t.product).toSet().toList()..sort();
    final tanks = state.tanks.where((t) => t.product == product).toList();
    return PopScope(
        canPop: !dirty && !saving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close();
        },
        child: AlertDialog(
            title: Text(editing ? 'Rename pump' : 'Add pump'),
            content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                    child: Form(
                        key: form,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Station: ${state.currentStationName}'),
                              const SizedBox(height: 12),
                              const Text(
                                  'Use your station’s equipment name. Names are unique within this station; the permanent ID is assigned automatically and does not change when renamed.'),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: name,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  enabled: !saving,
                                  maxLength: 80,
                                  onChanged: changed,
                                  decoration: const InputDecoration(
                                      labelText: 'Pump name',
                                      hintText:
                                          'Pump1a, Pump1b or Diesel Left'),
                                  validator: (value) {
                                    try {
                                      final label =
                                          NozzleItem.validateName(value ?? '');
                                      if (state.nozzles.any((n) =>
                                          n.id != widget.pump?.id &&
                                          n.label.toLowerCase() ==
                                              label.toLowerCase())) {
                                        return 'This pump name is already used in this station.';
                                      }
                                    } on FormatException {
                                      return 'Enter a name of 1–80 characters without control characters.';
                                    }
                                    return null;
                                  }),
                              if (editing) ...[
                                Text('Equipment ID: ${widget.pump!.id}'),
                                const SizedBox(height: 8),
                                Text(
                                    '${widget.pump!.productName} · Tank ${widget.pump!.tankCode}'),
                              ] else ...[
                                if (products.isEmpty)
                                  const Text(
                                      'Register a storage tank before adding a pump.'),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                    initialValue: product,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Fuel product'),
                                    items: products
                                        .map((p) => DropdownMenuItem(
                                            value: p, child: Text(p)))
                                        .toList(),
                                    onChanged: saving
                                        ? null
                                        : (value) => setState(() {
                                              product = value;
                                              tank = null;
                                              dirty = true;
                                            }),
                                    validator: (value) => value == null
                                        ? 'Select the fuel product.'
                                        : null),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                    key: ValueKey(product),
                                    initialValue: tank,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Supplying tank'),
                                    items: tanks
                                        .map((t) => DropdownMenuItem(
                                            value: t.code,
                                            child: Text(
                                                'Tank ${t.code} · ${t.product}')))
                                        .toList(),
                                    onChanged: saving
                                        ? null
                                        : (value) => setState(() {
                                              tank = value;
                                              dirty = true;
                                            }),
                                    validator: (value) => value == null
                                        ? 'Select the supplying tank.'
                                        : null),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: meter,
                                    enabled: !saving,
                                    onChanged: changed,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.,]'))
                                    ],
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Actual opening meter reading (L)'),
                                    validator: (value) {
                                      final reading = double.tryParse(
                                          (value ?? '')
                                              .trim()
                                              .replaceAll(',', ''));
                                      return reading == null ||
                                              !reading.isFinite ||
                                              reading < 0 ||
                                              reading >= 1000000000000
                                          ? 'Enter the actual non-negative opening meter reading.'
                                          : null;
                                    }),
                              ],
                              if (error != null) ...[
                                const SizedBox(height: 12),
                                Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))
                              ],
                            ])))),
            actions: [
              TextButton(
                  onPressed: saving ? null : close,
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving
                      ? 'Saving…'
                      : editing
                          ? 'Save name'
                          : 'Save pump')),
            ]));
  }
}
