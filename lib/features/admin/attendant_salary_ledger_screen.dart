import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

class AttendantSalaryLedgerScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AttendantSalaryLedgerScreen({super.key, required this.onBack});

  @override
  State<AttendantSalaryLedgerScreen> createState() => _AttendantSalaryLedgerScreenState();
}

class _AttendantSalaryLedgerScreenState extends State<AttendantSalaryLedgerScreen> {
  final state = StationAppState.instance;
  int _selectedTab = 0; // 0 = Discrepancy Queue, 1 = Monthly Payroll Settlement
  String _selectedMonth = 'October 2026';

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  List<String> get _recentMonths {
    final now = DateTime.now();
    final months = List.generate(7, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return '${_monthNames[d.month - 1]} ${d.year}';
    });
    if (!months.contains(_selectedMonth)) {
      months.insert(0, _selectedMonth);
    }
    return months;
  }

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

  Future<void> _approveDeduction(SalaryAdjustment adj) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve salary deduction?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${adj.attendantName} · ${adj.station}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Deduction: ${CurrencyFormatter.formatNaira(adj.amount.abs())}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            Text(
              'Shift Reference: ${adj.shiftRef}',
              style: const TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 12),
            const Text(
              'This amount will be deducted from the attendant\'s payroll once the monthly settlement is executed (§4.7).',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Approve Deduction', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    state.approveSalaryDeduction(adj.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Salary deduction of ${CurrencyFormatter.formatNaira(adj.amount.abs())} approved by Director for ${adj.attendantName}.',
        ),
      ),
    );
  }

  Future<void> _waiveShortage(SalaryAdjustment adj) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Waive discrepancy?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${adj.attendantName} · ${adj.station}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Variance: ${CurrencyFormatter.formatVariance(adj.amount)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            const Text(
              'Waiving records the operational review decision permanently and removes this variance from payroll deductions.',
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
            child: const Text('Waive Shortfall', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    state.waiveShortage(adj.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content: Text('Discrepancy for ${adj.attendantName} waived upon operational review.'),
      ),
    );
  }

  void _confirmExecuteMonthlySettlement() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Execute $_selectedMonth Payroll Settlement?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will finalize attendant payroll calculations for $_selectedMonth, automatically deducting all Director-approved forecourt shortages (§4.7).',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.badSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.lightCherry),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.bad, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Approved shortages will be marked as "Settled in Payroll" and net wages locked.',
                      style: TextStyle(fontSize: 12, color: AppColors.bad, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              state.processAllAttendantsPayroll(
                monthYear: _selectedMonth,
                settledBy: state.currentUser.displayName,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.ok,
                  behavior: SnackBarBehavior.floating,
                  content: Text('$_selectedMonth Monthly Payroll Settlement completed successfully!'),
                ),
              );
            },
            child: const Text('Confirm & Execute Settlement', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _copyPayrollCsv(List<_AttendantPayrollSummary> summaries) {
    final buffer = StringBuffer();
    buffer.writeln('AJADICO ENERGY LIMITED - MONTHLY ATTENDANT PAYROLL & SHORTAGE DEDUCTIONS');
    buffer.writeln('Payroll Period,"$_selectedMonth"');
    buffer.writeln('Audited By,"${state.currentUser.displayName}"');
    buffer.writeln('');
    buffer.writeln('Attendant Name,Station,Base Salary (NGN),Approved Shortages Deducted (NGN),Excesses Credited (NGN),Net Payable Wage (NGN),Carried Forward Deficit (NGN),Shortage Shifts Count,Status');

    for (var s in summaries) {
      buffer.writeln('"${s.attendantName}","${s.station}",${s.baseSalary ?? 0},${s.approvedShortages},${s.approvedExcesses},${s.netPayable},${s.carriedDeficit},${s.shortfallShiftsCount},"${s.isSettled ? "Settled & Processed" : "Ready for Settlement"}"');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payroll Sheet CSV copied to clipboard! Paste directly into Microsoft Excel or Google Sheets.'),
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyPayrollSlips(List<_AttendantPayrollSummary> summaries) {
    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('   AJADICO ENERGY - ATTENDANT PAYROLL SLIPS ($_selectedMonth)   ');
    buffer.writeln('====================================================\n');

    for (var s in summaries) {
      buffer.writeln('ATTENDANT: ${s.attendantName} (${s.station})');
      buffer.writeln(
        '  Monthly Base Wage:           ${s.baseSalary == null ? 'Not set (awaiting Director)' : CurrencyFormatter.formatNaira(s.baseSalary!)}',
      );
      buffer.writeln('  - Shortages Deducted (§4.7): ${CurrencyFormatter.formatNaira(s.approvedShortages)} (${s.shortfallShiftsCount} shifts)');
      if (s.approvedExcesses > 0) {
        buffer.writeln('  + Excesses Credited:         ${CurrencyFormatter.formatNaira(s.approvedExcesses)}');
      }
      buffer.writeln('  --------------------------------------------------');
      buffer.writeln('  NET SALARY PAYABLE:          ${CurrencyFormatter.formatNaira(s.netPayable)}');
      if (s.carriedDeficit > 0) {
        buffer.writeln('  ! DEFICIT CARRIED FORWARD:   ${CurrencyFormatter.formatNaira(s.carriedDeficit)}');
      }
      buffer.writeln('  Status:                      ${s.isSettled ? "Settled & Processed" : "Ready for Settlement"}\n');
    }
    buffer.writeln('====================================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Itemized attendant payslips copied to clipboard! Ready to print or dispatch.'),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<_AttendantPayrollSummary> _computePayrollSummaries() {
    final Map<String, _AttendantPayrollSummary> summaryMap = {};

    // 1. Enrolled attendants in staff database
    final enrolledAttendants = state.staff.where((s) => s.role == UserRole.attendant);
    for (var att in enrolledAttendants) {
      final base = att.baseSalary > 0 ? att.baseSalary : null;
      summaryMap[att.displayName.trim().toLowerCase()] = _AttendantPayrollSummary(
        attendantId: att.id,
        attendantName: att.displayName,
        station: att.stationName.isNotEmpty ? att.stationName : state.currentStationName,
        baseSalary: base,
      );
    }

    // 2. Scan salary adjustments
    for (var adj in state.salaryAdjustments) {
      final key = adj.attendantName.trim().toLowerCase();
      if (!summaryMap.containsKey(key)) {
        summaryMap[key] = _AttendantPayrollSummary(
          attendantId: 'att-${key.hashCode.abs()}',
          attendantName: adj.attendantName,
          station: adj.station.isNotEmpty ? adj.station : state.currentStationName,
          baseSalary: null,
        );
      }

      final summary = summaryMap[key]!;
      final isApprovedDeduction = adj.status == 'Salary Deduction Approved' || adj.status.contains('Settled in Payroll');

      if (isApprovedDeduction) {
        if (adj.amount < 0) {
          summary.approvedShortages += adj.amount.abs();
          summary.shortfallShiftsCount += 1;
        } else {
          summary.approvedExcesses += adj.amount;
        }
      }
    }

    // 3. Check if already settled in payroll settlements history
    for (var settlement in state.payrollSettlements) {
      if (settlement.monthYear == _selectedMonth) {
        final key = settlement.attendantName.trim().toLowerCase();
        if (summaryMap.containsKey(key)) {
          summaryMap[key]!.isSettled = true;
        }
      }
    }

    return summaryMap.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (state.currentUser.role != UserRole.director) {
      return _buildRestrictedAccess();
    }

    final adjustments = state.salaryAdjustments;
    final summaries = _computePayrollSummaries();

    final totalBasePayroll = summaries.fold(0.0, (sum, s) => sum + (s.baseSalary ?? 0.0));
    final totalShortagesDeducted = summaries.fold(0.0, (sum, s) => sum + s.approvedShortages);
    final totalNetPayable = summaries.fold(0.0, (sum, s) => sum + s.netPayable);
    final totalShortfallShifts = summaries.fold(0, (sum, s) => sum + s.shortfallShiftsCount);
    final allSettled = summaries.isNotEmpty && summaries.every((s) => s.isSettled);

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
            Text('Attendant Salary & Payroll Deductions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Director · Forecourt Discrepancies & Monthly Settlement (§4.6, §4.7)', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Tab Switcher
                LayoutBuilder(
                  builder: (context, constraints) {
                    final titleBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedTab == 0 ? 'Shift Discrepancy Governance' : 'Monthly Payroll Settlement Engine',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTab == 0
                              ? 'Review individual shift variances, approve salary deductions, or waive operational differences.'
                              : 'Reconcile attendant monthly base wages against approved shift shortages (§4.7).',
                          style: const TextStyle(fontSize: 14, color: AppColors.muted),
                        ),
                      ],
                    );
                    final tabSwitch = SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.playlist_remove),
                          label: Text('Discrepancy Queue'),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.account_balance_wallet_outlined),
                          label: Text('Monthly Settlement'),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (set) => setState(() => _selectedTab = set.first),
                    );

                    if (constraints.maxWidth < 700) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleBlock,
                          const SizedBox(height: 12),
                          Align(alignment: Alignment.centerLeft, child: tabSwitch),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 16),
                        tabSwitch,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // =============================================================
                // TAB 0: SHIFT DISCREPANCY QUEUE (DIRECTOR INDIVIDUAL GOVERNANCE)
                // =============================================================
                if (_selectedTab == 0) ...[
                  if (adjustments.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.verified_outlined, size: 48, color: AppColors.ok),
                              SizedBox(height: 12),
                              Text('No Attendant Discrepancies Currently Recorded', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 4),
                              Text('All forecourt shifts balanced cleanly without unresolved cashier differences.', style: TextStyle(color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    ...adjustments.map((adj) {
                      final isShortage = adj.amount < 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 20, color: AppColors.slate),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${adj.attendantName} · ${adj.station}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  StatusChip(
                                    label: isShortage
                                        ? 'Shortage ${CurrencyFormatter.formatNaira(adj.amount.abs())}'
                                        : 'Excess +${CurrencyFormatter.formatNaira(adj.amount)}',
                                    type: isShortage ? ChipType.bad : ChipType.ok,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Shift Reference: ${adj.shiftRef}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('Governance Status: ', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                  Text(
                                    adj.status,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: adj.status == 'Salary Deduction Approved'
                                          ? AppColors.bad
                                          : (adj.status.contains('Settled') ? AppColors.ink : (adj.status == 'Waived by Director' ? AppColors.ok : AppColors.warn)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (adj.status == 'Pending Review') ...[
                                    OutlinedButton(
                                      onPressed: () => _waiveShortage(adj),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(48, 48),
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                      ),
                                      child: const Text('Waive Shortfall', style: TextStyle(fontSize: 13)),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.bad,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(48, 48),
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                      ),
                                      onPressed: () => _approveDeduction(adj),
                                      child: const Text('Approve Salary Deduction', style: TextStyle(fontSize: 13)),
                                    ),
                                  ] else ...[
                                    Text(
                                      '✓ Decision Recorded: ${adj.status}',
                                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],

                // =============================================================
                // TAB 1: MONTHLY PAYROLL SETTLEMENT ENGINE (§4.7)
                // =============================================================
                if (_selectedTab == 1) ...[
                  // Control Bar & Month Selector
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _selectedMonth,
                              items: _recentMonths
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        'Payroll Cycle: $m',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (m) {
                                if (m == null) return;
                                setState(() => _selectedMonth = m);
                              },
                              underline: const SizedBox.shrink(),
                              isDense: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.copy_all, size: 16),
                            label: const Text('Copy Payslips', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                            onPressed: () => _copyPayrollSlips(summaries),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.table_chart, size: 16),
                            label: const Text('Export Excel (CSV)', style: TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.ok,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => _copyPayrollCsv(summaries),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(allSettled ? Icons.check_circle : Icons.payments, size: 16),
                            label: Text(allSettled ? 'Settled & Processed' : 'Execute Monthly Settlement', style: const TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: allSettled ? AppColors.ok : AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: allSettled ? null : _confirmExecuteMonthlySettlement,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // KPI Summary Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 36) / 4;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildKpiCard('Total Base Wages', CurrencyFormatter.formatNaira(totalBasePayroll), itemWidth),
                          _buildKpiCard('Shortages Deducted (§4.7)', CurrencyFormatter.formatVariance(-totalShortagesDeducted), itemWidth, isRed: true),
                          _buildKpiCard('Net Disbursable Payroll', CurrencyFormatter.formatNaira(totalNetPayable), itemWidth, isGreen: true),
                          _buildKpiCard('Shortfall Shifts Resolved', '$totalShortfallShifts Shifts', itemWidth, isBlue: true),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Payroll Calculation Breakdown Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Attendant Wage & Deduction Calculation Ledger',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                ),
                              ),
                              const SizedBox(width: 12),
                              StatusChip(
                                label: allSettled ? 'Payroll Finalized' : 'Draft Settlement',
                                type: allSettled ? ChipType.ok : ChipType.draft,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Net Payable = Base Monthly Salary - Approved Shift Shortages (§4.7). If shortages exceed base salary, remaining balance is carried forward.',
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                          const SizedBox(height: 16),

                          if (summaries.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text('No pump attendants enrolled in system.', style: TextStyle(color: AppColors.muted)),
                              ),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                                columns: [
                                  const DataColumn(label: Text('Attendant')),
                                  const DataColumn(label: Text('Station')),
                                  const DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('Base Salary (₦)')), numeric: true),
                                  const DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('Shortages Deducted (₦)')), numeric: true),
                                  const DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('Net Payable Wage (₦)')), numeric: true),
                                  const DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('Carried Deficit (₦)')), numeric: true),
                                  const DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('Shortage Shifts')), numeric: true),
                                  const DataColumn(label: Text('Settlement Status')),
                                ],
                                rows: summaries.map((s) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(s.attendantName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(s.station)),
                                      DataCell(
                                        _numericCell(
                                          s.baseSalary == null
                                              ? const Text(
                                                  'Not set — awaiting Director',
                                                  style: TextStyle(fontSize: 12, color: AppColors.warn),
                                                )
                                              : Text(
                                                  CurrencyFormatter.formatNaira(s.baseSalary!),
                                                  style: const TextStyle(color: AppColors.ink),
                                                ),
                                        ),
                                      ),
                                      DataCell(
                                        _numericCell(
                                          Text(
                                            s.approvedShortages > 0
                                                ? CurrencyFormatter.formatVariance(-s.approvedShortages)
                                                : CurrencyFormatter.formatNaira(0),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: s.approvedShortages > 0 ? AppColors.bad : AppColors.muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        _numericCell(
                                          s.baseSalary == null
                                              ? const Text(
                                                  'Pending base salary',
                                                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                                                )
                                              : Text(
                                                  CurrencyFormatter.formatNaira(s.netPayable),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ok),
                                                ),
                                        ),
                                      ),
                                      DataCell(
                                        _numericCell(
                                          s.carriedDeficit > 0
                                              ? Text(
                                                  CurrencyFormatter.formatNaira(s.carriedDeficit),
                                                  style: const TextStyle(color: AppColors.bad),
                                                )
                                              : const Text('None', style: TextStyle(color: AppColors.muted)),
                                        ),
                                      ),
                                      DataCell(
                                        _numericCell(
                                          Text('${s.shortfallShiftsCount} shift(s)', style: const TextStyle(color: AppColors.slate)),
                                        ),
                                      ),
                                      DataCell(StatusChip(
                                        label: !s.hasBaseSalary
                                            ? 'Awaiting Director'
                                            : (s.isSettled ? 'Settled' : 'Ready'),
                                        type: !s.hasBaseSalary ? ChipType.draft : (s.isSettled ? ChipType.ok : ChipType.warn),
                                      )),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _numericCell(Widget child) {
    return Align(alignment: Alignment.centerRight, child: child);
  }

  Widget _buildRestrictedAccess() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: const Text('Attendant Salary & Payroll Deductions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppColors.muted),
            const SizedBox(height: 16),
            const Text(
              'Restricted — director access required',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, double width, {bool isGreen = false, bool isRed = false, bool isBlue = false}) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isGreen ? AppColors.ok : (isRed ? AppColors.bad : (isBlue ? AppColors.bank : AppColors.ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendantPayrollSummary {
  final String attendantId;
  final String attendantName;
  final String station;

  /// null = monthly base salary has not been configured by the Director yet.
  final double? baseSalary;
  double approvedShortages = 0.0;
  double approvedExcesses = 0.0;
  int shortfallShiftsCount = 0;
  bool isSettled = false;

  _AttendantPayrollSummary({
    required this.attendantId,
    required this.attendantName,
    required this.station,
    required this.baseSalary,
  });

  bool get hasBaseSalary => baseSalary != null;

  double get netPayable {
    final diff = (baseSalary ?? 0.0) - approvedShortages + approvedExcesses;
    return diff > 0 ? diff : 0.0;
  }

  double get carriedDeficit {
    final diff = (baseSalary ?? 0.0) - approvedShortages + approvedExcesses;
    return diff < 0 ? diff.abs() : 0.0;
  }
}
