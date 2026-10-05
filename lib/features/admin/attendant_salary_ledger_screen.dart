import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';

class AttendantSalaryLedgerScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AttendantSalaryLedgerScreen({super.key, required this.onBack});

  @override
  State<AttendantSalaryLedgerScreen> createState() => _AttendantSalaryLedgerScreenState();
}

class _AttendantSalaryLedgerScreenState extends State<AttendantSalaryLedgerScreen> {
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

  @override
  Widget build(BuildContext context) {
    final adjustments = state.salaryAdjustments;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendant Salary Deductions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Director · Forecourt Discrepancy & Payroll Adjustments (§4.6, §4.7)', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendant shortage & excess ledger',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Shift variances are recorded automatically. Unresolved shortfalls reduce the attendant’s salary; Director decides large or disputed items (§4.7).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                if (adjustments.isEmpty) ...[
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text('No attendant discrepancies currently recorded.'),
                      ),
                    ),
                  ),
                ] else ...[
                  ...adjustments.map((adj) {
                    final isShortage = adj.amount < 0;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${adj.attendantName} · ${adj.station}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
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
                            Text(
                              'Shift Reference: ${adj.shiftRef}',
                              style: const TextStyle(fontSize: 14, color: AppColors.muted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Current Governance Status: ${adj.status}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: adj.status == 'Salary Deduction Approved'
                                    ? AppColors.bad
                                    : (adj.status == 'Waived by Director' ? AppColors.ok : AppColors.warn),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (adj.status == 'Pending Review') ...[
                                  OutlinedButton(
                                    onPressed: () => _waiveShortage(adj),
                                    child: const Text('Waive shortfall'),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.bad),
                                    onPressed: () => _approveDeduction(adj),
                                    child: const Text('Approve salary deduction'),
                                  ),
                                ] else ...[
                                  Text(
                                    '✓ Decision Recorded: ${adj.status}',
                                    style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
