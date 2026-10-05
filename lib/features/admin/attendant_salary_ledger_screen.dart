import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';

class AttendantDiscrepancyItem {
  final String id;
  final String attendantName;
  final String station;
  final String shiftDate;
  final double varianceAmount;
  String status; // 'Pending Review', 'Salary Deduction Approved', 'Recovered'

  AttendantDiscrepancyItem({
    required this.id,
    required this.attendantName,
    required this.station,
    required this.shiftDate,
    required this.varianceAmount,
    this.status = 'Pending Review',
  });
}

class AttendantSalaryLedgerScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AttendantSalaryLedgerScreen({super.key, required this.onBack});

  @override
  State<AttendantSalaryLedgerScreen> createState() => _AttendantSalaryLedgerScreenState();
}

class _AttendantSalaryLedgerScreenState extends State<AttendantSalaryLedgerScreen> {
  final List<AttendantDiscrepancyItem> _items = [
    AttendantDiscrepancyItem(
      id: 'DISC-01',
      attendantName: 'Bello S.',
      station: 'Lekki Road',
      shiftDate: 'Yesterday · Evening Shift',
      varianceAmount: -4500.0,
      status: 'Pending Review',
    ),
    AttendantDiscrepancyItem(
      id: 'DISC-02',
      attendantName: 'Fatima A.',
      station: 'Lekki Road',
      shiftDate: '1 Oct 2026 · Morning Shift',
      varianceAmount: -12000.0,
      status: 'Salary Deduction Approved',
    ),
    AttendantDiscrepancyItem(
      id: 'DISC-03',
      attendantName: 'Amaka O.',
      station: 'Lekki Road',
      shiftDate: '28 Sep 2026 · Morning Shift',
      varianceAmount: 2500.0,
      status: 'Excess Added to Salary',
    ),
  ];

  void _approveDeduction(AttendantDiscrepancyItem item) {
    setState(() {
      item.status = 'Salary Deduction Approved';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.bad,
        content: Text('Salary deduction of ${CurrencyFormatter.formatNaira(item.varianceAmount.abs())} approved by Senior for ${item.attendantName}.'),
      ),
    );
  }

  void _waiveShortage(AttendantDiscrepancyItem item) {
    setState(() {
      item.status = 'Waived by Senior';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        content: Text('Shortfall for ${item.attendantName} waived upon operational review.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendant Salary Adjustments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Shortages & Excesses Ledger (§4.6, §4.7)', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Attendant shortage & excess records',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Unresolved shift differences feed the attendant payroll record. Senior decides large or disputed items (§4.7).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                ..._items.map((item) {
                  final isShortage = item.varianceAmount < 0;
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
                                '${item.attendantName} · ${item.station}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                              ),
                              StatusChip(
                                label: isShortage
                                    ? 'Shortage ${CurrencyFormatter.formatNaira(item.varianceAmount.abs())}'
                                    : 'Excess +${CurrencyFormatter.formatNaira(item.varianceAmount)}',
                                type: isShortage ? ChipType.bad : ChipType.ok,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Shift: ${item.shiftDate} · Current Status: ${item.status}',
                            style: const TextStyle(fontSize: 14, color: AppColors.muted),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (item.status == 'Pending Review') ...[
                                OutlinedButton(
                                  onPressed: () => _waiveShortage(item),
                                  child: const Text('Waive discrepancy'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.bad),
                                  onPressed: () => _approveDeduction(item),
                                  child: const Text('Approve salary deduction'),
                                ),
                              ] else ...[
                                Text(
                                  '✓ ${item.status}',
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
            ),
          ),
        ),
      ),
    );
  }
}
