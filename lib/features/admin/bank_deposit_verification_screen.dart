import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';

class DepositItem {
  final String id;
  final String stationName;
  final String date;
  final double amount;
  final String cashierName;
  final String bankName;
  bool isConfirmed;

  DepositItem({
    required this.id,
    required this.stationName,
    required this.date,
    required this.amount,
    required this.cashierName,
    required this.bankName,
    this.isConfirmed = false,
  });
}

class BankDepositVerificationScreen extends StatefulWidget {
  final VoidCallback onBack;

  const BankDepositVerificationScreen({super.key, required this.onBack});

  @override
  State<BankDepositVerificationScreen> createState() => _BankDepositVerificationScreenState();
}

class _BankDepositVerificationScreenState extends State<BankDepositVerificationScreen> {
  final List<DepositItem> _deposits = [
    DepositItem(
      id: 'DEP-01',
      stationName: 'Lekki Road Station',
      date: 'Today · 12:40 PM',
      amount: 500000.0,
      cashierName: 'Chidi E.',
      bankName: 'GTBank (Station Main Account)',
      isConfirmed: false,
    ),
    DepositItem(
      id: 'DEP-02',
      stationName: 'Ikeja Branch',
      date: 'Yesterday · 4:15 PM',
      amount: 1200000.0,
      cashierName: 'Funke O.',
      bankName: 'Zenith Bank',
      isConfirmed: false,
    ),
    DepositItem(
      id: 'DEP-03',
      stationName: 'Victoria Island Station',
      date: '2 Oct 2026',
      amount: 850000.0,
      cashierName: 'Ahmed B.',
      bankName: 'FirstBank',
      isConfirmed: true,
    ),
  ];

  void _confirmDeposit(DepositItem item) {
    setState(() {
      item.isConfirmed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        content: Text(
          'Deposit of ${CurrencyFormatter.formatNaira(item.amount)} confirmed against bank credit alert by Senior (§4.3).',
        ),
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
            Text('Bank Deposit Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Senior · Multi-Branch Alert Verification (§4.3, §5.5)', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Bank deposit approvals',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Senior verifies station cash handovers against corporate bank credit alerts before funds are confirmed (§4.3, §5.5).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                ..._deposits.map((item) {
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
                                item.stationName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              StatusChip(
                                label: item.isConfirmed ? 'Confirmed in Bank' : 'Awaiting Bank Alert',
                                type: item.isConfirmed ? ChipType.ok : ChipType.bank,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Amount: ${CurrencyFormatter.formatNaira(item.amount)} · Cashier: ${item.cashierName} · ${item.date}',
                            style: const TextStyle(fontSize: 14, color: AppColors.muted),
                          ),
                          Text(
                            'Destination: ${item.bankName}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!item.isConfirmed)
                                ElevatedButton.icon(
                                  onPressed: () => _confirmDeposit(item),
                                  icon: const Icon(Icons.verified),
                                  label: const Text('Confirm against bank alert'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.bank,
                                    minimumSize: const Size(220, 44),
                                  ),
                                )
                              else
                                const Text(
                                  '✓ Verified by Senior',
                                  style: TextStyle(color: AppColors.ok, fontWeight: FontWeight.bold),
                                ),
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
