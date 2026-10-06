import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/bank_deposit.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

class BankDepositVerificationScreen extends StatefulWidget {
  final VoidCallback onBack;

  const BankDepositVerificationScreen({super.key, required this.onBack});

  @override
  State<BankDepositVerificationScreen> createState() => _BankDepositVerificationScreenState();
}

class _BankDepositVerificationScreenState extends State<BankDepositVerificationScreen> {
  final state = StationAppState.instance;
  final Set<String> _processingIds = {};

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

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $hour:$minute';
  }

  Future<void> _confirmDeposit(BankDepositRecord dep) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm bank credit alert?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${CurrencyFormatter.formatNaira(dep.amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Depositor: ${dep.cashierName}',
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
            ),
            Text(
              '${dep.stationName} · ${dep.bankName}',
              style: const TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dual-custody action: this locks the deposit into the company ledger as matched against the bank credit alert (§4.3, §5.5).',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bank,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Confirm Deposit', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runDepositAction(dep);
  }

  Future<void> _runDepositAction(BankDepositRecord dep) async {
    setState(() => _processingIds.add(dep.id));
    try {
      final ok = await state.confirmBankDeposit(dep.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.ok,
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Deposit ${dep.id} of ${CurrencyFormatter.formatNaira(dep.amount)} confirmed against bank credit alert by Director (§4.3, §5.5).',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.bad,
              behavior: SnackBarBehavior.floating,
              content: Text('Failed to confirm deposit. Please retry.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bad,
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to confirm deposit: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(dep.id));
    }
  }

  void _showTellerSlip(BankDepositRecord dep) {
    final url = dep.slipUrl ?? '';
    final width = (MediaQuery.of(context).size.width * 0.85).clamp(280.0, 760.0);
    final height = (MediaQuery.of(context).size.height * 0.6).clamp(240.0, 620.0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teller Slip'),
        content: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dep.id} · ${CurrencyFormatter.formatNaira(dep.amount)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
              ),
              const SizedBox(height: 12),
              Container(
                height: height,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (c, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  );
                },
                errorBuilder: (c, err, stack) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined, size: 44, color: AppColors.muted),
                      SizedBox(height: 8),
                      Text('Teller slip image could not be loaded', style: TextStyle(fontSize: 13, color: AppColors.ink)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildRestrictedAccess() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: const Text('Bank Deposit Approvals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                'Dual-custody bank credit verification is limited to the Director role (§4.3, §5.5).',
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

  void _flagDiscrepancyDialog(BankDepositRecord dep) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.bad),
              const SizedBox(width: 8),
              const Text('Flag Deposit Discrepancy'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are flagging ${CurrencyFormatter.formatNaira(dep.amount)} remitted by ${dep.cashierName} for ${dep.stationName}.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              const Text('Discrepancy Reason / Audit Note *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Credit alert not received on corporate statement; or amount credited is short by ₦50,000.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.bad),
              onPressed: () async {
                final notes = textController.text.trim();
                if (notes.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter discrepancy reason.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _processingIds.add(dep.id));
                try {
                  await state.flagBankDepositDiscrepancy(dep.id, notes);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.bad,
                        behavior: SnackBarBehavior.floating,
                        content: Text('Deposit ${dep.id} flagged for discrepancy investigation!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.bad,
                        behavior: SnackBarBehavior.floating,
                        content: Text('Failed to flag deposit: $e'),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _processingIds.remove(dep.id));
                }
              },
              child: const Text('Flag Discrepancy'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (state.currentUser.role != UserRole.director) {
      return _buildRestrictedAccess();
    }

    final deposits = state.deposits;
    final totalPending = deposits.where((d) => d.status == 'awaiting_bank' || !d.isConfirmed).fold(0.0, (s, d) => s + d.amount);
    final totalConfirmed = deposits.where((d) => d.status == 'confirmed' || d.isConfirmed).fold(0.0, (s, d) => s + d.amount);
    final totalDiscrepancies = deposits.where((d) => d.status == 'discrepancy').fold(0.0, (s, d) => s + d.amount);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bank Deposit Approvals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Commercial Bank Alert Verification (§4.3, §5.5)', style: const TextStyle(fontSize: 13, color: Colors.white70)),
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
                const Text(
                  'Bank deposit dual-custody audit',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cash handed over by station cashiers/managers remains held in "Awaiting bank" status until Director matches the bank SMS/email credit alert against the stamped teller (§5.5).',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
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
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.bank),
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
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ok),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (totalDiscrepancies > 0) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Discrepancies', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                Text(
                                  CurrencyFormatter.formatNaira(totalDiscrepancies),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.bad),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // If empty state
                if (deposits.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 56, color: AppColors.muted),
                            const SizedBox(height: 16),
                            const Text(
                              'No Bank Deposits in Verification Queue',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'When station cashiers or managers remit cash from the safe drawer to the commercial bank, deposit records with stamped teller slips will appear here for credit alert verification.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  const Text(
                    'Remittance Verification Queue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                  ),
                  const SizedBox(height: 10),

                  // Deposit Queue Cards
                  ...deposits.map((dep) {
                    final isProcessing = _processingIds.contains(dep.id);

                    ChipType chipType;
                    String statusLabel;
                    if (dep.status == 'confirmed' || dep.isConfirmed) {
                      chipType = ChipType.ok;
                      statusLabel = 'Confirmed in Bank';
                    } else if (dep.status == 'discrepancy') {
                      chipType = ChipType.bad;
                      statusLabel = 'Discrepancy Flagged';
                    } else {
                      chipType = ChipType.bank;
                      statusLabel = 'Awaiting Bank Alert';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance, color: AppColors.bank, size: 22),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${dep.stationName} (${dep.id})',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                StatusChip(
                                  label: statusLabel,
                                  type: chipType,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Main numbers row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Amount Remitted:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                      Text(
                                        CurrencyFormatter.formatNaira(dep.amount),
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Designated Bank Account:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                      Text(
                                        dep.bankName,
                                        textAlign: TextAlign.end,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, color: AppColors.line),

                            // Audit details row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bearer / Depositor: ${dep.cashierName}',
                                        style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Teller Ref: ${dep.tellerNumber ?? "N/A"} • ${_formatDateTime(dep.handedOverAt)}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (dep.slipUrl != null && dep.slipUrl!.trim().isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () => _showTellerSlip(dep),
                                    icon: const Icon(Icons.receipt_long, size: 16, color: AppColors.bank),
                                    label: const Text('View Teller Slip', style: TextStyle(fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.bank,
                                      minimumSize: const Size(48, 48),
                                    ),
                                  )
                                else if (dep.slipUrl != null)
                                  const Text(
                                    'No teller slip uploaded',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                              ],
                            ),

                            if (dep.notes != null && dep.notes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Station Memo: "${dep.notes}"',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.muted),
                              ),
                            ],

                            if (dep.directorNotes != null && dep.directorNotes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Director Note: "${dep.directorNotes}"',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: dep.status == 'discrepancy' ? AppColors.bad : AppColors.ok,
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // Actions
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (dep.status == 'awaiting_bank' || !dep.isConfirmed) ...[
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.bad,
                                      minimumSize: const Size(48, 48),
                                    ),
                                    icon: const Icon(Icons.flag_outlined, size: 16),
                                    label: const Text('Flag Discrepancy', style: TextStyle(fontSize: 13)),
                                    onPressed: isProcessing ? null : () => _flagDiscrepancyDialog(dep),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: isProcessing ? null : () => _confirmDeposit(dep),
                                    icon: isProcessing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.verified, size: 18),
                                    label: const Text('Confirm against bank credit alert', style: TextStyle(fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.bank,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(48, 48),
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                    ),
                                  ),
                                ] else if (dep.status == 'confirmed' || dep.isConfirmed) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle, color: AppColors.ok, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Verified & Locked into Company Ledger (${dep.confirmedBy ?? "Director"})',
                                          style: const TextStyle(color: AppColors.ok, fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (dep.status == 'discrepancy') ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error, color: AppColors.bad, size: 18),
                                      const SizedBox(width: 6),
                                      const Flexible(
                                        child: Text(
                                          'Flagged for Shortage Investigation',
                                          style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
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
