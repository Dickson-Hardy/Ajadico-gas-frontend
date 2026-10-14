import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/widgets/evidence_photo_picker.dart';
import '../../models/shift_adjustment.dart';
import '../../state/station_app_state.dart';

class PumpExpenseScreen extends StatefulWidget {
  final VoidCallback onBack, onSuccess;
  const PumpExpenseScreen(
      {super.key, required this.onBack, required this.onSuccess});
  @override
  State<PumpExpenseScreen> createState() => _PumpExpenseScreenState();
}

class _PumpExpenseScreenState extends State<PumpExpenseScreen>
    with UnsavedWorkAware {
  final state = StationAppState.instance;
  final amount = TextEditingController(), reason = TextEditingController();
  String? category;
  String? error;
  bool dirty = false;
  List<CompressedImageResult> photos = [];
  @override
  bool get hasUnsavedWork => dirty;
  @override
  void initState() {
    super.initState();
    ShellBackGuard.register(this);
  }

  @override
  void dispose() {
    ShellBackGuard.unregister(this);
    amount.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (!dirty) {
      widget.onBack();
      return;
    }
    final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Discard expense entry?'),
                content: const Text('This expense has not been submitted.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep editing')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Discard'))
                ]));
    if (discard == true && mounted) widget.onBack();
  }

  void submit() {
    final value = double.tryParse(amount.text.replaceAll(',', '').trim());
    final evidence =
        photos.map((p) => p.remoteStorageUrl).whereType<String>().toList();
    if (category == null ||
        value == null ||
        !value.isFinite ||
        value <= 0 ||
        reason.text.trim().isEmpty ||
        evidence.isEmpty) {
      setState(() => error =
          'Choose a category, enter a valid amount and reason, and attach receipt evidence.');
      return;
    }
    try {
      state.recordShiftAdjustment(
          kind: ShiftAdjustmentKind.expense,
          category: category!,
          amount: value,
          reason: reason.text,
          evidence: evidence);
      dirty = false;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Expense saved locally; awaiting approval.')));
      widget.onSuccess();
    } catch (_) {
      setState(() => error =
          'Could not save expense. Check your shift and operational policy.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = state.operationsPolicy?.expenseCategories ?? <String>[];
    return Scaffold(
      appBar: AppBar(
          title: const Text('Pump expense'),
          leading: IconButton(
              tooltip: 'Back',
              onPressed: leave,
              icon: const Icon(Icons.arrow_back))),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                        'Record money spent from this shift’s sales cash. Approval is required before it counts toward your handover.'),
                    const SizedBox(height: 16),
                    if (categories.isEmpty)
                      const Text(
                          'Expense categories are unavailable. Ask your administrator to configure the operational policy.'),
                    DropdownButtonFormField<String>(
                        initialValue: category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Expense category'),
                        items: categories
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() {
                              category = v;
                              dirty = true;
                            })),
                    const SizedBox(height: 16),
                    TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Amount spent', prefixText: '₦ '),
                        onChanged: (_) => dirty = true),
                    const SizedBox(height: 16),
                    TextField(
                        controller: reason,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'What was paid for and why?'),
                        onChanged: (_) => dirty = true),
                    const SizedBox(height: 16),
                    EvidencePhotoPicker(
                        title: 'Receipt / expense evidence',
                        photoType: 'expense',
                        stationName: state.currentStationName,
                        staffName: state.currentUser.displayName,
                        bucketName: 'expense-receipts',
                        onPhotosChanged: (p) => setState(() {
                              photos = p;
                              dirty = true;
                            })),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: categories.isEmpty ? null : submit,
                        child: const Text('Submit expense for approval')),
                  ]),
            ),
          )),
    );
  }
}
