import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/executive_hero_card.dart';
import '../../core/widgets/forecourt_charts.dart';
import '../../core/widgets/forecourt_tank_gauge.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';
import '../cashier/bank_deposit_dialog.dart';
import '../reports/shift_summary_export_dialog.dart';
import 'tank_changeover_dialog.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenVerificationQueue;
  final VoidCallback onOpenCashCount;
  final VoidCallback onOpenCreditCustomers;
  final VoidCallback? onOpenTankDip;
  final VoidCallback? onOpenFuelDelivery;
  final VoidCallback? onOpenStaffManagement;
  final VoidCallback? onOpenExpenseEntry;
  final VoidCallback onLogout;

  const ManagerDashboardScreen({
    super.key,
    required this.onOpenVerificationQueue,
    required this.onOpenCashCount,
    required this.onOpenCreditCustomers,
    this.onOpenTankDip,
    this.onOpenFuelDelivery,
    this.onOpenStaffManagement,
    this.onOpenExpenseEntry,
    required this.onLogout,
  });

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final state = StationAppState.instance;

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

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out of this kiosk?'),
        content: const Text(
          'You will be returned to the PIN sign-in screen. Any unsubmitted entries on this shared tablet will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Stay Signed In'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bad,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _openBankDepositDialog(double availableCash) {
    showDialog(
      context: context,
      builder: (context) => BankDepositDialog(
        availableCash: availableCash,
        onDepositRecorded: () => setState(() {}),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
            Text('Recorded By: ${expense.recordedByRole.toUpperCase()} (${(expense.approvedBy?.isNotEmpty ?? false) ? expense.approvedBy : "Pending Approval"})'),
            const SizedBox(height: 12),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: const Center(
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
          TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(minimumSize: const Size(0, 48)), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmApproveExpense(BranchExpense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Expense Disbursal?'),
        content: Text(
          'Confirm approval of ${CurrencyFormatter.formatNaira(expense.amount)} for "${expense.description}". This will formalize the deduction from the safe cash drawer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(minimumSize: const Size(0, 48)), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.approveExpense(expenseId: expense.id, approverNotes: state.currentUser.displayName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Approved ${CurrencyFormatter.formatNaira(expense.amount)} (${expense.category})'),
                  backgroundColor: AppColors.ok,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ok, foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );
  }

  void _confirmRejectExpense(BranchExpense expense) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Expense Disbursal?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting ${CurrencyFormatter.formatNaira(expense.amount)} for "${expense.description}". The physical safe balance will not deduct this amount and the disbursing cashier must reconcile the difference.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'A rejection reason is required.' : null,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'e.g. Unapproved petty purchase, invalid receipt',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(minimumSize: const Size(0, 48)), child: const Text('Cancel')),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: reasonController,
            builder: (context, value, _) {
              final canReject = value.text.trim().isNotEmpty;
              return ElevatedButton(
                onPressed: !canReject
                    ? null
                    : () {
                        if (formKey.currentState?.validate() != true) return;
                        final reason = value.text.trim();
                        Navigator.pop(ctx);
                        state.rejectExpense(expenseId: expense.id, reason: reason);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Rejected ${CurrencyFormatter.formatNaira(expense.amount)} (${expense.category})'),
                            backgroundColor: AppColors.bad,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bad,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.line,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Reject Expense'),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic KPI Aggregation strictly from live state
    double pmsSold = 0.0;
    double agoSold = 0.0;
    for (var n in state.nozzles) {
      if (n.productName == 'PMS') pmsSold += n.litresSold;
      if (n.productName == 'AGO') agoSold += n.litresSold;
    }

    final totalSalesValue = state.submissions.fold(0.0, (s, sub) => s + sub.expectedSalesValue);
    final totalCreditGiven = state.creditCustomers.fold(0.0, (s, c) => s + c.outstanding);
    final totalExpenses = state.expenses.fold(0.0, (s, e) => s + e.amount);
    final totalDepositsPending = state.deposits.where((d) => !d.isConfirmed).fold(0.0, (s, d) => s + d.amount);

    final pendingVerifications = state.submissions.where((s) => s.status == 'Pending Verification').length;
    final unresolvedDifferences = state.submissions.where((s) => s.status == 'Flagged Unresolved').length + state.salaryAdjustments.where((a) => a.status == 'Pending Review').length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Branch Manager Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · ${state.currentStationName} · Today', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(state.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: state.isDarkMode ? 'Daylight Mode' : 'Night Shift Mode',
            onPressed: () => state.toggleTheme(),
          ),
          if (widget.onOpenStaffManagement != null)
            IconButton(
              icon: const Icon(Icons.badge_outlined),
              tooltip: 'Staff & Attendants',
              onPressed: widget.onOpenStaffManagement,
            ),
          if (widget.onOpenExpenseEntry != null)
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Station Expenses',
              onPressed: widget.onOpenExpenseEntry,
            ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Copy Shift Summary',
            onPressed: () => ShiftSummaryExportDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Credit Customers',
            onPressed: widget.onOpenCreditCustomers,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _confirmLogout,
          ),
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
                // 1. Executive Duotone Hero Card: The One Number That Matters
                ExecutiveHeroCard(
                  totalRevenue: totalSalesValue,
                  pmsLitres: pmsSold,
                  agoLitres: agoSold,
                  safeCashBalance: state.totalCountedCash > 0 ? state.totalCountedCash : state.expectedClosingCash,
                  netVariance: state.submissions.fold(0.0, (s, sub) => s + sub.variance),
                  pendingAuditCount: pendingVerifications,
                  stationName: state.currentStationName,
                  onDepositPressed: () => _openBankDepositDialog(
                    state.totalCountedCash > 0 ? state.totalCountedCash : state.expectedClosingCash,
                  ),
                  onAuditPressed: widget.onOpenVerificationQueue,
                  onExportPressed: () => ShiftSummaryExportDialog.show(context),
                ),

                const SizedBox(height: 20),

                // 2. 7-Day Forecourt Throughput & Sales Trend Sparkline Chart
                const Forecourt7DaySalesChart(),

                const SizedBox(height: 20),

                // 3. Operational Dials Title & Submissions Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Operational Dials & Safe Balances',
                      style: AppTypography.title(
                        fontSize: 18,
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink,
                      ),
                    ),
                    StatusChip(
                      label: pendingVerifications > 0 ? '$pendingVerifications Submissions Need Audit' : 'All Clear',
                      type: pendingVerifications > 0 ? ChipType.warn : ChipType.ok,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // KPI Metric Tiles
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 800 ? 3 : (width >= 460 ? 2 : 1);
                    final itemWidth = (width - 12 * (columns - 1)) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildKpiCard('PMS Sold', CurrencyFormatter.formatLitres(pmsSold), itemWidth),
                        _buildKpiCard('AGO Sold', CurrencyFormatter.formatLitres(agoSold), itemWidth),
                        _buildKpiCard('Sales Value', CurrencyFormatter.formatNaira(totalSalesValue), itemWidth, isGreen: true),
                        _buildKpiCard('Credit Given', CurrencyFormatter.formatNaira(totalCreditGiven), itemWidth),
                        _buildKpiCard('Expenses', CurrencyFormatter.formatNaira(totalExpenses), itemWidth),
                        _buildKpiCard('Deposits Pending', CurrencyFormatter.formatNaira(totalDepositsPending), itemWidth, isBlue: true),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Graphical Underground Storage Tanks (UST) Real-Time Levels
                LayoutBuilder(
                  builder: (context, constraints) {
                    final title = const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Underground Fuel Tanks (UST)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Live physical dip levels, calculated book stock & tanker discharge ullage.',
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                      ],
                    );
                    final actions = <Widget>[
                      if (state.hasInterlockedTanks)
                        ElevatedButton.icon(
                          onPressed: () => TankChangeoverDialog.show(context, state),
                          icon: const Icon(Icons.alt_route, size: 16),
                          label: const Text('Manifold Changeover'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warn,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      if (widget.onOpenTankDip != null)
                        OutlinedButton.icon(
                          onPressed: widget.onOpenTankDip,
                          icon: const Icon(Icons.straighten, size: 16),
                          label: const Text('Record Daily Dip'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            side: const BorderSide(color: AppColors.line),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      if (widget.onOpenFuelDelivery != null)
                        OutlinedButton.icon(
                          onPressed: widget.onOpenFuelDelivery,
                          icon: const Icon(Icons.local_shipping_outlined, size: 16),
                          label: const Text('Record Fuel Delivery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            side: const BorderSide(color: AppColors.line),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ];
                    if (constraints.maxWidth < 700) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: actions),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Visual Tank Gauge Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 750;
                    return isMobile
                        ? Column(
                            children: state.tanks.map((t) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ForecourtTankGauge(
                                  tankCode: t.code,
                                  productName: t.product,
                                  capacityLitres: t.capacity,
                                  currentLitres: t.physicalDip,
                                  calculatedStockLitres: t.bookStock,
                                  lastDipTime: t.lastDipTime,
                                  onTap: widget.onOpenTankDip,
                                ),
                              );
                            }).toList(),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: state.tanks.map((t) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: ForecourtTankGauge(
                                    tankCode: t.code,
                                    productName: t.product,
                                    capacityLitres: t.capacity,
                                    currentLitres: t.physicalDip,
                                    calculatedStockLitres: t.bookStock,
                                    lastDipTime: t.lastDipTime,
                                    onTap: widget.onOpenTankDip,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                  },
                ),
                const SizedBox(height: 20),

                // Pending Safe & Station Expense Approvals Card
                if (state.pendingExpenses.isNotEmpty) ...[
                  Card(
                    color: AppColors.warnSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.warn),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final heading = Row(
                                children: [
                                  const Icon(Icons.pending_actions, color: AppColors.amber, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pending Expense Approvals (${state.pendingExpenses.length})',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.warnInk),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                              final recordButton = widget.onOpenExpenseEntry == null
                                  ? null
                                  : TextButton.icon(
                                      onPressed: widget.onOpenExpenseEntry,
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Record Safe Expense'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.warnInk,
                                        minimumSize: const Size(0, 48),
                                      ),
                                    );
                              if (constraints.maxWidth < 700 || recordButton == null) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    heading,
                                    if (recordButton != null) ...[
                                      const SizedBox(height: 4),
                                      Align(alignment: Alignment.centerLeft, child: recordButton),
                                    ],
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: heading),
                                  recordButton,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          ...state.pendingExpenses.map((expense) => _buildPendingExpenseTile(expense)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Operational Summary Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Needs attention
                        Expanded(
                          flex: isNarrow ? 0 : 1,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Needs attention',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  if (state.pendingExpenses.isNotEmpty)
                                    _buildActionRow(
                                      'Pending expense approvals',
                                      StatusChip(
                                        label: '${state.pendingExpenses.length}',
                                        type: ChipType.warn,
                                      ),
                                    ),
                                  _buildActionRow(
                                    'Submissions to verify',
                                    StatusChip(label: '$pendingVerifications', type: pendingVerifications > 0 ? ChipType.warn : ChipType.ok),
                                  ),
                                  _buildActionRow(
                                    'Unresolved differences',
                                    StatusChip(label: '$unresolvedDifferences', type: unresolvedDifferences > 0 ? ChipType.bad : ChipType.ok),
                                  ),
                                  _buildActionRow(
                                    'Bank deposits in transit',
                                    StatusChip(
                                      label: totalDepositsPending > 0 ? CurrencyFormatter.formatNaira(totalDepositsPending) : 'None',
                                      type: totalDepositsPending > 0 ? ChipType.bank : ChipType.ok,
                                    ),
                                  ),
                                    ...state.tanks.where((t) => t.hasDeficit).map((t) {
                                      return _buildActionRow(
                                        'Tank ${t.code} dip vs calculated',
                                        StatusChip(
                                          label: '${t.variance >= 0 ? '+' : '−'}${CurrencyFormatter.formatLitres(t.variance.abs())}',
                                          type: ChipType.bad,
                                        ),
                                      );
                                    }),
                                  ...state.tanks.where((t) => t.isLowStock).map((t) {
                                    return _buildActionRow(
                                      'Low stock: ${t.product} ${t.code}',
                                      const StatusChip(label: 'Low', type: ChipType.warn),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (!isNarrow) const SizedBox(width: 16),

                        // Right: Shifts Status
                        Expanded(
                          flex: isNarrow ? 0 : 1,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Shift operations',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildActionRow(
                                    'Morning Shift',
                                    StatusChip(
                                      label: pendingVerifications > 0 ? 'Verification Pending' : 'Verified & Locked',
                                      type: pendingVerifications > 0 ? ChipType.warn : ChipType.ok,
                                    ),
                                  ),
                                  _buildActionRow(
                                    'Afternoon / Evening Shift',
                                    StatusChip(
                                      label: DateTime.now().hour >= 14 ? 'Active / In progress' : 'Scheduled (Starts 2:00 PM)',
                                      type: DateTime.now().hour >= 14 ? ChipType.warn : ChipType.draft,
                                    ),
                                  ),
                                  const Divider(color: AppColors.line),
                                  const Text(
                                    'Active Prices (Authorized by Director):',
                                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PMS: ${CurrencyFormatter.formatNaira(state.pmsPrice)}/L | AGO: ${CurrencyFormatter.formatNaira(state.agoPrice)}/L',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.playlist_add_check),
                  onPressed: widget.onOpenVerificationQueue,
                  label: const Text('Verify queue'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.point_of_sale),
                  onPressed: widget.onOpenCashCount,
                  label: const Text('Cash count'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.account_balance, color: AppColors.bank),
                  onPressed: () => _openBankDepositDialog(state.totalCountedCash > 0 ? state.totalCountedCash : state.expectedClosingCash),
                  label: const Text('Bank deposit'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.print_outlined, color: AppColors.primary),
                tooltip: 'Copy Shift Summary',
                onPressed: () => ShiftSummaryExportDialog.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, double width, {bool isGreen = false, bool isBlue = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isGreen
        ? (isDark ? AppColors.emerald : AppColors.okInk)
        : (isBlue ? AppColors.accent : (isDark ? AppColors.darkInk : AppColors.ink));

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
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(String label, Widget chip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          chip,
        ],
      ),
    );
  }

  Widget _buildPendingExpenseTile(BranchExpense expense) {
    final requiresDirector = expense.amount > 50000;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warn),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            expense.category,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                          label: expense.recordedByRole.toUpperCase(),
                          type: ChipType.draft,
                        ),
                        if (expense.paymentSource == 'sales_cash' || expense.paymentSource == 'Cash Drawer') ...[
                          const SizedBox(width: 6),
                          const StatusChip(
                            label: 'CASH SAFE',
                            type: ChipType.warn,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expense.description,
                      style: const TextStyle(fontSize: 13, color: AppColors.slate),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recorded: ${_formatTime(expense.recordedAt)} · Source: ${expense.paymentSource}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                CurrencyFormatter.formatNaira(expense.amount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final left = expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty
                  ? TextButton.icon(
                      onPressed: () => _showReceiptPreview(expense),
                      icon: const Icon(Icons.receipt, size: 16, color: AppColors.primary),
                      label: const Text('View Receipt Proof', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No receipt attached',
                        style: TextStyle(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic),
                      ),
                    );
              final right = requiresDirector
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.badSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.bad),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: AppColors.bad),
                          SizedBox(width: 4),
                          Text(
                            'Requires Director Approval (>₦50k)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.bad),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _confirmRejectExpense(expense),
                          icon: const Icon(Icons.close, size: 16, color: AppColors.bad),
                          label: const Text('Reject', style: TextStyle(fontSize: 13, color: AppColors.bad)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.bad),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _confirmApproveExpense(expense),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ok,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [left, const SizedBox(height: 8), right],
                );
              }
              return Row(
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 8),
                  right,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
