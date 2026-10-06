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

  void _approveDeduction(SalaryAdjustment adj) {
    state.approveSalaryDeduction(adj.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.bad,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Salary deduction of ${CurrencyFormatter.formatNaira(adj.amount.abs())} approved by Director for ${adj.attendantName}.',
        ),
      ),
    );
  }

  void _waiveShortage(SalaryAdjustment adj) {
    state.waiveShortage(adj.id);
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
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
            child: const Text('Confirm & Execute Settlement'),
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
      buffer.writeln('"${s.attendantName}","${s.station}",${s.baseSalary},${s.approvedShortages},${s.approvedExcesses},${s.netPayable},${s.carriedDeficit},${s.shortfallShiftsCount},"${s.isSettled ? "Settled & Processed" : "Ready for Settlement"}"');
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
      buffer.writeln('  Monthly Base Wage:           ${CurrencyFormatter.formatNaira(s.baseSalary)}');
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
      final base = att.baseSalary > 0 ? att.baseSalary : 75000.0;
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
          baseSalary: 75000.0,
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
    final adjustments = state.salaryAdjustments;
    final summaries = _computePayrollSummaries();

    final totalBasePayroll = summaries.fold(0.0, (sum, s) => sum + s.baseSalary);
    final totalShortagesDeducted = summaries.fold(0.0, (sum, s) => sum + s.approvedShortages);
    final totalNetPayable = summaries.fold(0.0, (sum, s) => sum + s.netPayable);
    final totalShortfallShifts = summaries.fold(0, (sum, s) => sum + s.shortfallShiftsCount);
    final allSettled = summaries.isNotEmpty && summaries.every((s) => s.isSettled);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                    ),
                    SegmentedButton<int>(
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
                    ),
                  ],
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 20, color: AppColors.slate),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${adj.attendantName} · ${adj.station}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      child: const Text('Waive Shortfall'),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.bad,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      onPressed: () => _approveDeduction(adj),
                                      child: const Text('Approve Salary Deduction'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Payroll Cycle: $_selectedMonth',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.copy_all, size: 16),
                            label: const Text('Copy Payslips'),
                            onPressed: () => _copyPayrollSlips(summaries),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.table_chart, size: 16),
                            label: const Text('Export Excel (CSV)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF047857),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _copyPayrollCsv(summaries),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: Icon(allSettled ? Icons.check_circle : Icons.payments, size: 16),
                            label: Text(allSettled ? 'Settled & Processed' : 'Execute Monthly Settlement'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: allSettled ? AppColors.ok : AppColors.primary,
                              foregroundColor: Colors.white,
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
                          _buildKpiCard('Shortages Deducted (§4.7)', '-${CurrencyFormatter.formatNaira(totalShortagesDeducted)}', itemWidth, isRed: true),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Attendant Wage & Deduction Calculation Ledger',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                              ),
                              StatusChip(
                                label: allSettled ? 'Payroll Finalized' : 'Draft Settlement',
                                type: allSettled ? ChipType.ok : ChipType.warn,
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
                                columns: const [
                                  DataColumn(label: Text('Attendant')),
                                  DataColumn(label: Text('Station')),
                                  DataColumn(label: Text('Base Salary (₦)'), numeric: true),
                                  DataColumn(label: Text('Shortages Deducted (₦)'), numeric: true),
                                  DataColumn(label: Text('Net Payable Wage (₦)'), numeric: true),
                                  DataColumn(label: Text('Carried Deficit (₦)'), numeric: true),
                                  DataColumn(label: Text('Shortage Shifts')),
                                  DataColumn(label: Text('Settlement Status')),
                                ],
                                rows: summaries.map((s) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(s.attendantName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(s.station)),
                                      DataCell(Text(CurrencyFormatter.formatNaira(s.baseSalary))),
                                      DataCell(Text(
                                        s.approvedShortages > 0 ? '-${CurrencyFormatter.formatNaira(s.approvedShortages)}' : '₦0.00',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: s.approvedShortages > 0 ? AppColors.bad : AppColors.muted,
                                        ),
                                      )),
                                      DataCell(Text(
                                        CurrencyFormatter.formatNaira(s.netPayable),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ok),
                                      )),
                                      DataCell(Text(
                                        s.carriedDeficit > 0 ? CurrencyFormatter.formatNaira(s.carriedDeficit) : 'None',
                                        style: TextStyle(color: s.carriedDeficit > 0 ? AppColors.bad : AppColors.muted),
                                      )),
                                      DataCell(Text('${s.shortfallShiftsCount} shift(s)')),
                                      DataCell(StatusChip(
                                        label: s.isSettled ? 'Settled' : 'Ready',
                                        type: s.isSettled ? ChipType.ok : ChipType.warn,
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
  final double baseSalary;
  double approvedShortages;
  double approvedExcesses;
  int shortfallShiftsCount;
  bool isSettled;

  _AttendantPayrollSummary({
    required this.attendantId,
    required this.attendantName,
    required this.station,
    required this.baseSalary,
    this.approvedShortages = 0.0,
    this.approvedExcesses = 0.0,
    this.shortfallShiftsCount = 0,
    this.isSettled = false,
  });

  double get netPayable {
    final diff = baseSalary - approvedShortages + approvedExcesses;
    return diff > 0 ? diff : 0.0;
  }

  double get carriedDeficit {
    final diff = baseSalary - approvedShortages + approvedExcesses;
    return diff < 0 ? diff.abs() : 0.0;
  }
}
