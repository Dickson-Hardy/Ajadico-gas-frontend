import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';

class BankDepositVerificationScreen extends StatefulWidget {
  final VoidCallback onBack;

  const BankDepositVerificationScreen({super.key, required this.onBack});

  @override
  State<BankDepositVerificationScreen> createState() => _BankDepositVerificationScreenState();
}

class _BankDepositVerificationScreenState extends State<BankDepositVerificationScreen> {
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

  void _confirmDeposit(BankDepositRecord dep) {
    state.confirmBankDeposit(dep.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Deposit ${dep.id} of ${CurrencyFormatter.formatNaira(dep.amount)} confirmed against bank credit alert by Director (§4.3, §5.5).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deposits = state.deposits;
    final totalPending = deposits.where((d) => !d.isConfirmed).fold(0.0, (s, d) => s + d.amount);
    final totalConfirmed = deposits.where((d) => d.isConfirmed).fold(0.0, (s, d) => s + d.amount);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bank Deposit Approvals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Director · Commercial Bank Alert Verification (§4.3, §5.5)', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Bank deposit confirmation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cash handed over by station cashiers remains held in "Awaiting bank" state until Director matches the bank SMS/email credit alert (§5.5).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // Summary Stats
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Awaiting Bank Alert', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.formatNaira(totalPending),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.bank),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Confirmed Bank Assets', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.formatNaira(totalConfirmed),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ok),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Deposit Queue Cards
                ...deposits.map((dep) {
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
                                '${dep.stationName} (${dep.id})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              StatusChip(
                                label: dep.isConfirmed ? 'Confirmed in Bank' : 'Awaiting Bank Alert',
                                type: dep.isConfirmed ? ChipType.ok : ChipType.bank,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Amount: ${CurrencyFormatter.formatNaira(dep.amount)} · Cashier: ${dep.cashierName}',
                            style: const TextStyle(fontSize: 14, color: AppColors.muted),
                          ),
                          Text(
                            'Target Account: ${dep.bankName}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!dep.isConfirmed)
                                ElevatedButton.icon(
                                  onPressed: () => _confirmDeposit(dep),
                                  icon: const Icon(Icons.verified, size: 18),
                                  label: const Text('Confirm against bank credit alert'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.bank,
                                    minimumSize: const Size(260, 44),
                                  ),
                                )
                              else
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: AppColors.ok, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Verified & Locked into Company Bank Ledger',
                                      style: TextStyle(color: AppColors.ok, fontWeight: FontWeight.bold),
                                    ),
                                  ],
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
