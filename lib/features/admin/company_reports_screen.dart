import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/operations_workspace.dart';
import '../../core/widgets/shift_adjustment_ledger.dart';
import '../../core/widgets/forecourt_tank_gauge.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/evidence_preview_dialog.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';
import '../manager/tank_changeover_dialog.dart';

class CompanyReportsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onOpenStationSetup;
  final VoidCallback? onOpenStaffManagement;
  final VoidCallback? onOpenExpenseEntry;

  const CompanyReportsScreen({
    super.key,
    required this.onBack,
    this.onOpenStationSetup,
    this.onOpenStaffManagement,
    this.onOpenExpenseEntry,
  });

  @override
  State<CompanyReportsScreen> createState() => _CompanyReportsScreenState();
}

class _CompanyReportsScreenState extends State<CompanyReportsScreen> {
  final state = StationAppState.instance;
  int _selectedView = 0; // 0 = Financial Performance, 1 = Live Graphical Tanks

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showReceiptPreview(BranchExpense expense) {
    EvidencePreviewDialog.show(context,
        title: '${expense.category} receipt', reference: expense.receiptUrl);
  }

  Future<void> _approveExpenseDialog(BranchExpense exp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Expense?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${exp.category} · ${CurrencyFormatter.formatNaira(exp.amount)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(exp.description,
                style: const TextStyle(fontSize: 13, color: AppColors.slate)),
            const SizedBox(height: 12),
            const Text(
              'Approving locks this expense into the consolidated company ledger as Director-authorized.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ok,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Approve', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      if (!state.approveExpense(
          expenseId: exp.id, approverNotes: 'Director approval')) {
        throw StateError(
            'Approval not permitted by the current policy or record status.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Approved ${CurrencyFormatter.formatNaira(exp.amount)} (${exp.category})'),
            backgroundColor: AppColors.ok,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to approve expense: $e'),
              backgroundColor: AppColors.bad),
        );
      }
    }
  }

  Future<void> _rejectExpenseDialog(BranchExpense exp) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canSubmit = reasonCtrl.text.trim().isNotEmpty;
          return AlertDialog(
            title: const Text('Reject Expense?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${exp.category} · ${CurrencyFormatter.formatNaira(exp.amount)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(exp.description,
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.slate)),
                const SizedBox(height: 12),
                const Text(
                  'Rejection Reason *',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. Missing original vendor receipt; resubmit with proof of purchase.',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (!canSubmit)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'A reason is required before rejecting.',
                      style: TextStyle(fontSize: 12, color: AppColors.bad),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: canSubmit
                    ? () => Navigator.pop(ctx, reasonCtrl.text.trim())
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bad,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Reject', style: TextStyle(fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
    reasonCtrl.dispose();

    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      if (!state.rejectExpense(expenseId: exp.id, reason: reason)) {
        throw StateError(
            'Rejection not permitted by the current policy or record status.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Rejected ${CurrencyFormatter.formatNaira(exp.amount)} — reason recorded.'),
            backgroundColor: AppColors.ink,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to reject expense: $e'),
              backgroundColor: AppColors.bad),
        );
      }
    }
  }

  Widget _buildRestrictedAccess() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: const Text('Company Consolidated Executive View',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: AppColors.muted),
              const SizedBox(height: 16),
              const Text(
                'Restricted — director access required',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Consolidated financials, expense approvals and storage oversight are limited to the Director role.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTimeRange? _reportRange;

  bool _inPeriod(DateTime date) {
    final range = _reportRange;
    if (range == null) return true;
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _selectPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _reportRange,
      helpText: 'Select reporting period',
    );
    if (range != null && mounted) setState(() => _reportRange = range);
  }

  Widget _empty(String title, String description, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined,
            size: 30, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        if (action != null) ...[const SizedBox(height: 16), action],
      ]),
    );
  }

  Widget _metricGrid(List<Widget> cards) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820
            ? 4
            : constraints.maxWidth >= 460
                ? 2
                : 1;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) => SizedBox(width: width, child: card))
                .toList());
      });

  Widget _expenseRow(BranchExpense expense) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(builder: (context, constraints) {
        final details =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(expense.category,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 5),
          Text(expense.description,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
              '${expense.paymentSource} · ${expense.recordedBy} · ${_dateLabel(expense.recordedAt)}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
        ]);
        final actions = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(CurrencyFormatter.formatNaira(expense.amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty)
                IconButton(
                    tooltip: 'View receipt',
                    onPressed: () => _showReceiptPreview(expense),
                    icon: const Icon(Icons.attach_file, size: 18)),
              if (expense.isPending) ...[
                OutlinedButton(
                    onPressed: () => _rejectExpenseDialog(expense),
                    child: const Text('Reject')),
                ElevatedButton(
                    onPressed: () => _approveExpenseDialog(expense),
                    child: const Text('Approve')),
              ] else
                Text(expense.status,
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            expense.isRejected ? AppColors.bad : AppColors.ok)),
            ]);
        if (constraints.maxWidth < 760)
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 12),
                actions,
              ]);
        return Row(children: [
          Expanded(child: details),
          const SizedBox(width: 18),
          actions
        ]);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (state.currentUser.role != UserRole.director)
      return _buildRestrictedAccess();
    final colors = Theme.of(context).colorScheme;
    final submissions =
        state.submissions.where((s) => _inPeriod(s.submittedAt)).toList();
    final verified = submissions.where((s) => s.status == 'Verified').toList();
    final expenses =
        state.expenses.where((e) => _inPeriod(e.recordedAt)).toList();
    final revenue = verified.fold(0.0, (sum, s) => sum + s.expectedSalesValue);
    final expenseTotal = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final pumpEntries =
        state.shiftAdjustments.where((e) => _inPeriod(e.createdAt)).toList();
    final pending = expenses.where((e) => e.isPending).toList();
    final tanks = state.tanks;
    final pmsStock = tanks
        .where((t) => t.product == 'PMS')
        .fold(0.0, (sum, t) => sum + t.physicalDip);
    final agoStock = tanks
        .where((t) => t.product == 'AGO')
        .fold(0.0, (sum, t) => sum + t.physicalDip);
    final attention = tanks.where((t) => t.isLowStock || t.hasDeficit).length;
    final periodLabel = _reportRange == null
        ? 'Loaded records'
        : '${_dateLabel(_reportRange!.start)} – ${_dateLabel(_reportRange!.end)}';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Financial overview'),
        actions: [
          IconButton(
            tooltip: 'Refresh records',
            onPressed: state.isSyncingWithRemote
                ? null
                : () => state.syncWithSupabase(),
            icon: state.isSyncingWithRemote
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(state.currentStationName,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Review verified sales, recorded expenses and fuel stock.',
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 22),
              Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: 0,
                            label: Text('Financials'),
                            icon: Icon(Icons.receipt_long_outlined)),
                        ButtonSegment(
                            value: 1,
                            label: Text('Fuel stock'),
                            icon: Icon(Icons.storage_outlined)),
                      ],
                      selected: {_selectedView},
                      onSelectionChanged: (selection) =>
                          setState(() => _selectedView = selection.first),
                    ),
                    OutlinedButton.icon(
                        onPressed: _selectPeriod,
                        icon: const Icon(Icons.date_range_outlined, size: 17),
                        label: Text(periodLabel)),
                    if (_reportRange != null)
                      TextButton(
                          onPressed: () => setState(() => _reportRange = null),
                          child: const Text('Clear dates')),
                    if (widget.onOpenExpenseEntry != null)
                      ElevatedButton.icon(
                          onPressed: widget.onOpenExpenseEntry,
                          icon: const Icon(Icons.add, size: 17),
                          label: const Text('Record expense')),
                  ]),
              const SizedBox(height: 24),
              if (_selectedView == 0) ...[
                _metricGrid([
                  WorkspaceMetric(
                      label: 'Verified sales',
                      value: CurrencyFormatter.formatNaira(revenue),
                      detail: '${verified.length} verified submissions'),
                  WorkspaceMetric(
                      label: 'Recorded expenses',
                      value: CurrencyFormatter.formatNaira(expenseTotal +
                          pumpEntries
                              .where((e) => !e.isFuel)
                              .fold(0.0, (sum, e) => sum + e.amount)),
                      detail:
                          '${pending.length + pumpEntries.where((e) => !e.isFuel && e.isPending).length} awaiting approval'),
                  WorkspaceMetric(
                      label: 'Gross profit',
                      value: 'Unavailable',
                      detail: 'Fuel cost accounting required'),
                  WorkspaceMetric(
                      label: 'Profit after expenses',
                      value: 'Unavailable',
                      detail: 'Stock and costs must be reconciled'),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: colors.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                'Profit is unavailable until delivery costs and remaining stock are reconciled. Date filters apply to loaded records; these totals are not a complete company accounting statement.',
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: colors.onSurfaceVariant))),
                      ]),
                ),
                const SizedBox(height: 24),
                WorkspaceSection(
                  title: 'Shift records',
                  subtitle:
                      '${submissions.length} records · ${state.currentStationName}',
                  child: submissions.isEmpty
                      ? _empty('No shift records in this view',
                          'Submitted shifts appear here with their verification status.')
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('ATTENDANT')),
                              DataColumn(label: Text('SHIFT / DATE')),
                              DataColumn(
                                  label: Text('SALES VALUE'), numeric: true),
                              DataColumn(
                                  label: Text('DIFFERENCE'), numeric: true),
                              DataColumn(label: Text('STATUS')),
                            ],
                            rows: submissions
                                .map((s) => DataRow(cells: [
                                      DataCell(Text(s.attendantName)),
                                      DataCell(Text(
                                          '${s.shiftType} · ${_dateLabel(s.submittedAt)}')),
                                      DataCell(Text(
                                          CurrencyFormatter.formatNaira(
                                              s.expectedSalesValue))),
                                      DataCell(Text(
                                          CurrencyFormatter.formatVariance(
                                              s.variance),
                                          style: TextStyle(
                                              color: s.isBalanced
                                                  ? colors.onSurface
                                                  : AppColors.bad))),
                                      DataCell(StatusChip(
                                          label: s.status,
                                          type: s.status == 'Verified'
                                              ? ChipType.ok
                                              : s.status == 'Flagged Unresolved'
                                                  ? ChipType.bad
                                                  : ChipType.warn)),
                                    ]))
                                .toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                WorkspaceSection(
                  title: 'Expense review',
                  subtitle:
                      '${pending.length} awaiting your decision · ${expenses.length} recorded',
                  child: expenses.isEmpty
                      ? _empty('No expenses in this view',
                          'Record a branch expense to start the approval trail.',
                          action: widget.onOpenExpenseEntry == null
                              ? null
                              : OutlinedButton.icon(
                                  onPressed: widget.onOpenExpenseEntry,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Record expense')))
                      : Column(children: [
                          for (var index = 0;
                              index < expenses.length;
                              index++) ...[
                            if (index > 0)
                              Divider(height: 1, color: colors.outlineVariant),
                            _expenseRow(expenses[index]),
                          ],
                        ]),
                ),
                if (state.shiftAdjustments.isNotEmpty)
                  WorkspaceSection(
                      title: 'Pump expenses & non-sale fuel',
                      subtitle:
                          'Shift-linked entries; approval follows operational limits',
                      child: ShiftAdjustmentLedger(
                          entries: pumpEntries, review: true)),
              ] else ...[
                Text('Latest loaded tank readings',
                    style: TextStyle(
                        fontSize: 12, color: colors.onSurfaceVariant)),
                const SizedBox(height: 12),
                _metricGrid([
                  WorkspaceMetric(
                      label: 'Measured PMS stock',
                      value: CurrencyFormatter.formatLitres(pmsStock)),
                  WorkspaceMetric(
                      label: 'Measured AGO stock',
                      value: CurrencyFormatter.formatLitres(agoStock)),
                  WorkspaceMetric(
                      label: 'Available tank capacity',
                      value: CurrencyFormatter.formatLitres(tanks.fold(
                          0.0, (sum, t) => sum + t.capacity - t.physicalDip))),
                  WorkspaceMetric(
                      label: 'Tanks needing attention',
                      value: '$attention',
                      detail: 'Low stock or recorded deficit',
                      color: attention > 0 ? AppColors.warn : colors.primary),
                ]),
                const SizedBox(height: 24),
                WorkspaceSection(
                  title: 'Tank reconciliation',
                  subtitle:
                      'Calculated stock compared with the last loaded measurement',
                  action: state.hasInterlockedTanks && tanks.isNotEmpty
                      ? TextButton.icon(
                          onPressed: () =>
                              TankChangeoverDialog.show(context, state),
                          icon: const Icon(Icons.alt_route, size: 16),
                          label: const Text('Changeover'))
                      : null,
                  child: tanks.isEmpty
                      ? _empty('No tanks configured',
                          'Set up the station tanks before recording stock.',
                          action: widget.onOpenStationSetup == null
                              ? null
                              : OutlinedButton(
                                  onPressed: widget.onOpenStationSetup,
                                  child: const Text('Configure station')))
                      : MediaQuery.sizeOf(context).width < 700
                          ? Column(children: [
                              for (final tank in tanks)
                                ForecourtTankGauge(
                                  tankCode: tank.code,
                                  productName: tank.product,
                                  capacityLitres: tank.capacity,
                                  currentLitres: tank.physicalDip,
                                  calculatedStockLitres: tank.bookStock,
                                  lastDipTime: tank.lastDipTime,
                                  isCompact: true,
                                ),
                            ])
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('TANK')),
                                  DataColumn(label: Text('PRODUCT')),
                                  DataColumn(
                                      label: Text('CALCULATED'), numeric: true),
                                  DataColumn(
                                      label: Text('MEASURED'), numeric: true),
                                  DataColumn(
                                      label: Text('VARIANCE'), numeric: true),
                                  DataColumn(label: Text('STATUS')),
                                ],
                                rows: tanks
                                    .map((t) => DataRow(cells: [
                                          DataCell(Text(t.code,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600))),
                                          DataCell(Text(t.product)),
                                          DataCell(Text(
                                              CurrencyFormatter.formatLitres(
                                                  t.bookStock))),
                                          DataCell(Text(
                                              CurrencyFormatter.formatLitres(
                                                  t.physicalDip))),
                                          DataCell(Text(
                                              CurrencyFormatter.formatLitres(
                                                  t.variance),
                                              style: TextStyle(
                                                  color: t.hasDeficit
                                                      ? AppColors.bad
                                                      : colors.onSurface))),
                                          DataCell(StatusChip(
                                              label: t.hasDeficit
                                                  ? 'Variance'
                                                  : t.isLowStock
                                                      ? 'Low stock'
                                                      : 'Recorded',
                                              type: t.hasDeficit
                                                  ? ChipType.bad
                                                  : t.isLowStock
                                                      ? ChipType.warn
                                                      : ChipType.ok)),
                                        ]))
                                    .toList(),
                              )),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (widget.onOpenStaffManagement != null)
                  OutlinedButton.icon(
                      onPressed: widget.onOpenStaffManagement,
                      icon: const Icon(Icons.people_outline, size: 17),
                      label: const Text('People & access')),
                if (widget.onOpenStationSetup != null)
                  OutlinedButton.icon(
                      onPressed: widget.onOpenStationSetup,
                      icon: const Icon(Icons.settings_outlined, size: 17),
                      label: const Text('Station configuration')),
              ]),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}
