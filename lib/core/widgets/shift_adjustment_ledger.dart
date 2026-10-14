import 'package:flutter/material.dart';
import '../../models/shift_adjustment.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';
import '../utils/currency_formatter.dart';
import 'evidence_preview_dialog.dart';

class ShiftAdjustmentLedger extends StatefulWidget {
  final List<ShiftAdjustment> entries;
  final bool review;
  const ShiftAdjustmentLedger(
      {super.key, required this.entries, this.review = false});
  @override
  State<ShiftAdjustmentLedger> createState() => _ShiftAdjustmentLedgerState();
}

class _ShiftAdjustmentLedgerState extends State<ShiftAdjustmentLedger> {
  bool busy = false;
  Future<void> decide(ShiftAdjustment entry, bool approve) async {
    final notes = TextEditingController();
    String? error;
    final route = DialogRoute<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: Text(approve ? 'Approve entry?' : 'Reject entry?'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          '${entry.label} · ${CurrencyFormatter.formatNaira(entry.amount)}'),
                      TextField(
                          controller: notes,
                          maxLines: 3,
                          decoration: InputDecoration(
                              labelText: 'Review notes (required)',
                              errorText: error)),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () {
                            if (notes.text.trim().isEmpty) {
                              update(() => error = 'Explain your decision.');
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                          child: const Text('Confirm'))
                    ])));
    final confirmed = await Navigator.of(context).push(route);
    final reason = notes.text.trim();
    await route.completed;
    notes.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    final saved = await StationAppState.instance
        .reviewShiftAdjustment(entry.id, approve, reason);
    if (!mounted) return;
    setState(() => busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved
            ? 'Review confirmed by the server.'
            : 'Review was not saved. An authenticated connection and sufficient approval authority are required.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = StationAppState.instance;
    final policy = state.operationsPolicy;
    final colors = Theme.of(context).colorScheme;
    if (widget.entries.isEmpty)
      return const Text('No pump expenses or non-sale fuel recorded.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final entry in widget.entries) ...[
        Text('${entry.label} · ${CurrencyFormatter.formatNaira(entry.amount)}',
            style: Theme.of(context).textTheme.titleSmall),
        if (widget.review)
          Text('${entry.attendantName} · Shift ${entry.shiftId}'),
        if (entry.isFuel)
          Text(
              '${entry.litres.toStringAsFixed(2)} L · ${entry.pumpLabel} · Tank ${entry.tankCode}'),
        if (entry.category.isNotEmpty) Text(entry.category),
        Text(entry.reason),
        Text(entry.statusLabel,
            style: TextStyle(
                color: entry.isPending
                    ? colors.onSurfaceVariant
                    : colors.primary)),
        if (entry.reviewedBy != null) Text('Reviewed by ${entry.reviewedBy}'),
        if (entry.reviewNotes?.isNotEmpty ?? false) Text(entry.reviewNotes!),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < entry.evidence.length; i++)
            TextButton.icon(
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text('Evidence ${i + 1}'),
                onPressed: () => EvidencePreviewDialog.show(context,
                    title: entry.label, reference: entry.evidence[i])),
          if (widget.review &&
              entry.isPending &&
              state.currentUser.id != entry.attendantId &&
              policy != null &&
              state.currentUser.isActive &&
              (state.currentUser.role == UserRole.director ||
                  state.currentUser.role == UserRole.manager &&
                      entry.amount <= policy.managerApprovalLimit ||
                  state.currentUser.role == UserRole.cashier &&
                      entry.amount <= policy.cashierApprovalLimit)) ...[
            OutlinedButton(
                onPressed: busy ? null : () => decide(entry, true),
                child: const Text('Approve')),
            TextButton(
                onPressed: busy ? null : () => decide(entry, false),
                child: const Text('Reject')),
          ],
        ]),
        const Divider(height: 24),
      ],
    ]);
  }
}
