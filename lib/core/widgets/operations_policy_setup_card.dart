import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/operations_policy.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';
import '../utils/currency_formatter.dart';

class OperationsPolicySetupCard extends StatelessWidget {
  const OperationsPolicySetupCard({super.key, this.onChanged});
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    final state = StationAppState.instance;
    final policy = state.operationsPolicy;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Company approval policy',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                      'Company-wide expense limits and categories. Only a verified director can change these settings.'),
                  const SizedBox(height: 12),
                  if (policy == null)
                    const Text(
                        'Not configured. Expense approvals stay disabled until Setup is saved.')
                  else ...[
                    Text(
                        'Cashier limit: ${CurrencyFormatter.formatNaira(policy.cashierApprovalLimit, includeDecimals: true)}'),
                    Text(
                        'Manager limit: ${CurrencyFormatter.formatNaira(policy.managerApprovalLimit, includeDecimals: true)}'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final category in policy.expenseCategories)
                        Chip(label: Text(category))
                    ]),
                    Text('Policy revision ${policy.revision}'),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.rule_outlined),
                      label: Text(policy == null
                          ? 'Configure approval policy'
                          : 'Edit approval policy'),
                      onPressed: state.currentUser.isActive &&
                              state.currentUser.role == UserRole.director
                          ? () async {
                              await showDialog<void>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) =>
                                      _PolicyEditor(policy: policy));
                              if (context.mounted) onChanged?.call();
                            }
                          : null),
                ])));
  }
}

class _PolicyEditor extends StatefulWidget {
  final OperationsPolicy? policy;
  const _PolicyEditor({this.policy});
  @override
  State<_PolicyEditor> createState() => _PolicyEditorState();
}

class _PolicyEditorState extends State<_PolicyEditor> {
  late final TextEditingController cashier, manager, categories;
  bool dirty = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    // Defaults intentionally blank. Populate only actual saved configuration.
    cashier = TextEditingController(
        text: widget.policy?.cashierApprovalLimit.toStringAsFixed(2) ?? '');
    manager = TextEditingController(
        text: widget.policy?.managerApprovalLimit.toStringAsFixed(2) ?? '');
    categories = TextEditingController(
        text: widget.policy?.expenseCategories.join('\n') ?? '');
  }

  @override
  void dispose() {
    cashier.dispose();
    manager.dispose();
    categories.dispose();
    super.dispose();
  }

  void changed(String value) => setState(() {
        dirty = true;
        error = null;
      });
  Future<void> close() async {
    if (saving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Discard policy changes?'),
                  content: const Text('These settings have not been saved.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Keep editing')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Discard'))
                  ]));
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> save() async {
    final cashierValue =
        double.tryParse(cashier.text.trim().replaceAll(',', ''));
    final managerValue =
        double.tryParse(manager.text.trim().replaceAll(',', ''));
    final values = categories.text
        .split('\n')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    try {
      if (cashierValue == null || managerValue == null)
        throw const FormatException();
      OperationsPolicy(
          revision: (widget.policy?.revision ?? 0) + 1,
          cashierApprovalLimit: cashierValue,
          managerApprovalLimit: managerValue,
          expenseCategories: values);
    } on FormatException {
      setState(() => error =
          'Enter non-negative limits, with manager ≥ cashier, and 1–50 unique categories (up to 100 characters each).');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final saved = await StationAppState.instance.configureOperationsPolicy(
        cashierLimit: cashierValue,
        managerLimit: managerValue,
        categories: values,
        expectedRevision: widget.policy?.revision ?? 0);
    if (!mounted) return;
    setState(() => saving = false);
    if (!saved) {
      setState(() => error =
          'Not saved. A verified director connection is required. If the policy changed elsewhere, close this form and refresh Setup.');
      return;
    }
    dirty = false;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Approval policy saved and audited by the server.')));
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !dirty && !saving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !saving) close();
        },
        child: AlertDialog(
          title: const Text('Company approval policy'),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text(
                        'Changes apply to all stations. No amounts are preset.'),
                    const SizedBox(height: 16),
                    TextField(
                        controller: cashier,
                        enabled: !saving,
                        onChanged: changed,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Cashier approval limit',
                            prefixText: '₦ ')),
                    const SizedBox(height: 16),
                    TextField(
                        controller: manager,
                        enabled: !saving,
                        onChanged: changed,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Manager approval limit',
                            prefixText: '₦ ')),
                    const SizedBox(height: 16),
                    TextField(
                        controller: categories,
                        enabled: !saving,
                        onChanged: changed,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                            labelText: 'Expense categories',
                            helperText: 'One category per line')),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                  ]))),
          actions: [
            TextButton(
                onPressed: saving ? null : close, child: const Text('Cancel')),
            FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save company policy'))
          ],
        ),
      );
}
