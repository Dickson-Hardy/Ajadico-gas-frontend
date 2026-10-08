import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../core/widgets/forecourt_charts.dart';
import '../../core/widgets/forecourt_tank_gauge.dart';
import '../../core/widgets/status_chip.dart';
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showReceiptPreview(BranchExpense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${expense.category} Receipt Proof'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${CurrencyFormatter.formatNaira(expense.amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Description: ${expense.description}'),
            const SizedBox(height: 4),
            Text('Recorded By: ${expense.recordedByRole.toUpperCase()} · Status: ${expense.status}'),
            const SizedBox(height: 12),
            Container(
              height: 180,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty
                  ? Image.network(
                      expense.receiptUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        );
                      },
                      errorBuilder: (ctx, err, stack) => const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined, size: 48, color: AppColors.muted),
                            SizedBox(height: 8),
                            Text(
                              'Receipt image could not be loaded',
                              style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Stored in Supabase expense-receipts bucket',
                              style: TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_outlined, size: 48, color: AppColors.muted),
                          SizedBox(height: 8),
                          Text('Receipt Photo Attached', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Stored in Supabase expense-receipts bucket', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(exp.description, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
            const SizedBox(height: 12),
            const Text(
              'Approving locks this expense into the consolidated company ledger as Director-authorized.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
      state.approveExpense(expenseId: exp.id, approverNotes: 'Director approval');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved ${CurrencyFormatter.formatNaira(exp.amount)} (${exp.category})'),
            backgroundColor: AppColors.ok,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve expense: $e'), backgroundColor: AppColors.bad),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(exp.description, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
                const SizedBox(height: 12),
                const Text(
                  'Rejection Reason *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Missing original vendor receipt; resubmit with proof of purchase.',
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: canSubmit ? () => Navigator.pop(ctx, reasonCtrl.text.trim()) : null,
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
      state.rejectExpense(expenseId: exp.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected ${CurrencyFormatter.formatNaira(exp.amount)} — reason recorded.'),
            backgroundColor: AppColors.ink,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject expense: $e'), backgroundColor: AppColors.bad),
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
        title: const Text('Company Consolidated Executive View', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
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
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (state.currentUser.role != UserRole.director) {
      return _buildRestrictedAccess();
    }

    // 1. Calculate Real Financial Metrics purely from live state
    double totalPmsLitres = 0.0;
    double totalAgoLitres = 0.0;
    double totalRevenue = 0.0;

    for (var sub in state.submissions) {
      if (sub.status == 'Verified') {
        totalRevenue += sub.expectedSalesValue;
        for (var n in sub.nozzles) {
          if (n.productName == 'PMS') totalPmsLitres += n.litresSold;
          if (n.productName == 'AGO') totalAgoLitres += n.litresSold;
        }
      }
    }

    final totalExpenses = state.expenses.fold(0.0, (s, e) => s + e.amount);
    // Estimated fuel COGS based on current retail price margins (~8% distribution margin)
    final totalCogs = totalRevenue * 0.92;
    final totalGrossProfit = totalRevenue - totalCogs;
    final totalNetProfit = totalGrossProfit - totalExpenses;

    // 2. Real Tanks from Supabase Database
    final liveTanks = state.tanks;
    final totalPmsInStock = liveTanks.where((t) => t.product == 'PMS').fold(0.0, (s, t) => s + t.physicalDip);
    final totalAgoInStock = liveTanks.where((t) => t.product == 'AGO').fold(0.0, (s, t) => s + t.physicalDip);
    final totalCompanyUllage = liveTanks.fold(0.0, (s, t) => s + (t.capacity - t.physicalDip));
    final lowStockTanksCount = liveTanks.where((t) => t.isLowStock || t.hasDeficit).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company Consolidated Executive View', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Director · Live Multi-Branch Consolidated Ledger & Storage', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(state.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: state.isDarkMode ? 'Daylight Mode' : 'Night Shift Mode',
            onPressed: () => state.toggleTheme(),
          ),
          if (state.hasInterlockedTanks)
            TextButton.icon(
              icon: const Icon(Icons.alt_route, color: AppColors.amber),
              label: const Text('Manifold Switch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => TankChangeoverDialog.show(context, state),
            ),
          if (widget.onOpenExpenseEntry != null)
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Record Corporate / Station Expense',
              onPressed: widget.onOpenExpenseEntry,
            ),
          if (widget.onOpenStaffManagement != null)
            IconButton(
              icon: const Icon(Icons.badge_outlined),
              tooltip: 'Staff Management & Payroll',
              onPressed: widget.onOpenStaffManagement,
            ),
          if (widget.onOpenStationSetup != null)
            IconButton(
              icon: const Icon(Icons.settings_suggest),
              tooltip: 'Forecourt & Station Setup',
              onPressed: widget.onOpenStationSetup,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header & Mode Toggle
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final titleBlock = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedView == 0
                                ? 'Consolidated Financial Performance'
                                : 'Underground Fuel Storage Tanks (UST)',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedView == 0
                                ? 'Real-time revenue, audited shift remittances, and verified expenses.'
                                : 'Real-time physical dip levels, book stock, and available discharge ullage.',
                            style: const TextStyle(fontSize: 15, color: AppColors.muted),
                          ),
                        ],
                      );
                      final viewToggle = SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.assessment_outlined),
                            label: Text('P&L Ledger'),
                          ),
                          ButtonSegment(
                            value: 1,
                            icon: Icon(Icons.propane_tank_outlined),
                            label: Text('Tank Gauges'),
                          ),
                        ],
                        selected: {_selectedView},
                        onSelectionChanged: (set) => setState(() => _selectedView = set.first),
                      );

                      if (constraints.maxWidth < 700) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleBlock,
                            const SizedBox(height: 12),
                            Align(alignment: Alignment.centerLeft, child: viewToggle),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: titleBlock),
                          const SizedBox(width: 16),
                          viewToggle,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                // =============================================================
                // VIEW 0: REAL FINANCIAL LEDGER (ZERO DEMO DATA)
                // =============================================================
                if (_selectedView == 0) ...[
                  // 7-Day Forecourt Sales Trend Sparkline Chart
                  const Forecourt7DaySalesChart(),
                  const SizedBox(height: 20),

                  // Real Financial KPI Summary Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 36) / 4;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSummaryKpi('Total Verified Revenue', CurrencyFormatter.formatNaira(totalRevenue), width),
                          _buildSummaryKpi('Gross Margin (Profit)', CurrencyFormatter.formatNaira(totalGrossProfit), width, color: AppColors.ok),
                          _buildSummaryKpi('Verified Expenses', CurrencyFormatter.formatNaira(totalExpenses), width),
                          _buildSummaryKpi('Net Operating Profit', CurrencyFormatter.formatNaira(totalNetProfit), width, color: totalNetProfit >= 0 ? AppColors.ok : AppColors.bad),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Real Branch Financial Table
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Station Performance (Live Verified Shifts)',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                              ),
                              Text(
                                '${state.submissions.where((s) => s.status == "Verified").length} Verified Shift(s)',
                                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (totalRevenue == 0 && totalExpenses == 0)
                            const EmptyStateView.noRecords(
                              title: 'No Verified Transactions Yet Today',
                              message: 'Financial figures update live as pump attendants submit shift remittances and cashiers verify them.',
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                                columns: const [
                                  DataColumn(label: Text('Branch')),
                                  DataColumn(label: Text('PMS Litres', textAlign: TextAlign.end), numeric: true),
                                  DataColumn(label: Text('AGO Litres', textAlign: TextAlign.end), numeric: true),
                                  DataColumn(label: Text('Gross Revenue (₦)', textAlign: TextAlign.end), numeric: true),
                                  DataColumn(label: Text('Est. Gross Profit', textAlign: TextAlign.end), numeric: true),
                                  DataColumn(label: Text('Expenses', textAlign: TextAlign.end), numeric: true),
                                  DataColumn(label: Text('Net Profit', textAlign: TextAlign.end), numeric: true),
                                ],
                                rows: [
                                  DataRow(
                                    cells: [
                                      const DataCell(Text('Lekki Road Station', style: TextStyle(fontWeight: FontWeight.bold))),
                                      _numericCell(Text(CurrencyFormatter.formatLitres(totalPmsLitres))),
                                      _numericCell(Text(CurrencyFormatter.formatLitres(totalAgoLitres))),
                                      _numericCell(Text(CurrencyFormatter.formatNaira(totalRevenue))),
                                      _numericCell(Text(CurrencyFormatter.formatNaira(totalGrossProfit))),
                                      _numericCell(Text(CurrencyFormatter.formatNaira(totalExpenses))),
                                      _numericCell(
                                        Text(
                                          CurrencyFormatter.formatNaira(totalNetProfit),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: totalNetProfit >= 0 ? AppColors.ok : AppColors.bad),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Executive Expense Approvals & Audit Ledger Card (§6.1)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.receipt_long, color: AppColors.ink, size: 22),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Expense Ledger & Executive Approvals',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                        ),
                                      ],
                                    ),
                                    if (state.pendingExpenses.isNotEmpty)
                                      StatusChip(
                                        label: '${state.pendingExpenses.length} Pending Approval',
                                        type: ChipType.warn,
                                      ),
                                  ],
                                ),
                              ),
                              if (widget.onOpenExpenseEntry != null) ...[
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: widget.onOpenExpenseEntry,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Record Expense'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'All operational and petty cash safe disbursals recorded across branches. Director has absolute authorization authority.',
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                          const SizedBox(height: 16),

                          if (state.expenses.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No station expenses recorded yet today.', style: TextStyle(color: AppColors.muted)),
                              ),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                                columns: const [
                                  DataColumn(label: Text('Time')),
                                  DataColumn(label: Text('Category')),
                                  DataColumn(label: Text('Description')),
                                  DataColumn(label: Text('Source')),
                                  DataColumn(label: Text('Role')),
                                  DataColumn(label: Text('Amount (₦)', textAlign: TextAlign.end), numeric: true),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Receipt')),
                                  DataColumn(label: Text('Executive Action')),
                                ],
                                rows: state.expenses.map((exp) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(_formatTime(exp.recordedAt))),
                                      DataCell(Text(exp.category, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text(exp.description)),
                                      DataCell(Text(exp.paymentSource == 'sales_cash' ? 'Cash Safe' : exp.paymentSource)),
                                      DataCell(Text(exp.recordedByRole.toUpperCase())),
                                      _numericCell(Text(
                                        CurrencyFormatter.formatNaira(exp.amount),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      )),
                                      DataCell(StatusChip(
                                        label: exp.status,
                                        type: exp.isApproved
                                            ? ChipType.ok
                                            : (exp.isRejected ? ChipType.bad : ChipType.warn),
                                      )),
                                      DataCell(
                                        exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.receipt, color: AppColors.primary, size: 18),
                                                tooltip: 'View Receipt',
                                                onPressed: () => _showReceiptPreview(exp),
                                              )
                                            : const Text('-', style: TextStyle(color: AppColors.muted)),
                                      ),
                                      DataCell(
                                        exp.isPending
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  OutlinedButton(
                                                    onPressed: () => _rejectExpenseDialog(exp),
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(color: AppColors.bad),
                                                      minimumSize: const Size(48, 48),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                                    ),
                                                    child: const Text('Reject', style: TextStyle(color: AppColors.bad, fontSize: 13)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  ElevatedButton(
                                                    onPressed: () => _approveExpenseDialog(exp),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.ok,
                                                      foregroundColor: Colors.white,
                                                      minimumSize: const Size(48, 48),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                                    ),
                                                    child: const Text('Approve', style: TextStyle(fontSize: 13)),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                exp.approvedBy != null && exp.approvedBy!.isNotEmpty
                                                    ? 'By ${exp.approvedBy}'
                                                    : 'Completed',
                                                style: const TextStyle(fontSize: 12, color: AppColors.slate),
                                              ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                // =============================================================
                // VIEW 1: LIVE GRAPHICAL TANK GAUGES (REAL SUPABASE TANKS ONLY)
                // =============================================================
                if (_selectedView == 1) ...[
                  // Fuel Inventory KPI Metric Summary (from real tanks)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 36) / 4;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSummaryKpi('Total PMS in Storage', CurrencyFormatter.formatLitres(totalPmsInStock), width, color: const Color(0xFFC2410C)),
                          _buildSummaryKpi('Total AGO in Storage', CurrencyFormatter.formatLitres(totalAgoInStock), width, color: AppColors.ok),
                          _buildSummaryKpi('Total Discharge Ullage', CurrencyFormatter.formatLitres(totalCompanyUllage), width, color: AppColors.ink),
                          _buildSummaryKpi('Attention Required', '$lowStockTanksCount Tank(s)', width, color: lowStockTanksCount > 0 ? AppColors.warn : AppColors.ok),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Header with Tank Count
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Station Tanks (${liveTanks.length} Tanks in Database)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                      ),
                      const Text(
                        'Source: Supabase PostgreSQL `tanks` table',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Real Graphical Tank Gauges Grid
                  if (liveTanks.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.propane_tank_outlined, size: 48, color: AppColors.muted),
                              SizedBox(height: 12),
                              Text('No Storage Tanks Configured in Database', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 700;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: liveTanks.map((t) {
                            final itemWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;
                            return SizedBox(
                              width: itemWidth,
                              child: ForecourtTankGauge(
                                tankCode: t.code,
                                productName: t.product,
                                capacityLitres: t.capacity,
                                currentLitres: t.physicalDip,
                                calculatedStockLitres: t.bookStock,
                                stationName: 'Lekki Road Station',
                                lastDipTime: t.lastDipTime,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataCell _numericCell(Widget child) {
    return DataCell(Align(alignment: Alignment.centerRight, child: child));
  }

  Widget _buildSummaryKpi(String label, String value, double width, {Color color = AppColors.ink}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color == AppColors.ink ? (isDark ? AppColors.darkInk : AppColors.ink) : color;

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? AppColors.darkMuted : AppColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.monoNumeric(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
