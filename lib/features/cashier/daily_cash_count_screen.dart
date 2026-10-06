import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';
import '../reports/shift_summary_export_dialog.dart';
import 'bank_deposit_dialog.dart';

class DailyCashCountScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onOpenExpenseEntry;

  const DailyCashCountScreen({
    super.key,
    required this.onBack,
    this.onOpenExpenseEntry,
  });

  @override
  State<DailyCashCountScreen> createState() => _DailyCashCountScreenState();
}

class _DailyCashCountScreenState extends State<DailyCashCountScreen> {
  final state = StationAppState.instance;

  final Map<int, TextEditingController> _controllers = {};
  final Map<int, String> _countErrors = {};

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
    state.cashCounts.forEach((denom, count) {
      _controllers[denom] = TextEditingController(text: count > 0 ? count.toString() : '');
    });
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onCountChanged(int denom, String val) {
    final text = val.trim();

    if (text.isEmpty) {
      _countErrors.remove(denom);
      state.updateCashCount(denom, 0);
      if (mounted) setState(() {});
      return;
    }

    final count = int.tryParse(text);
    if (count == null || count < 0) {
      setState(() => _countErrors[denom] = 'Enter a whole number of notes.');
      return;
    }

    _countErrors.remove(denom);
    state.updateCashCount(denom, count);
    if (mounted) setState(() {});
  }

  void _saveCount() {
    if (_countErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Correct the highlighted denomination counts before saving.'),
        ),
      );
      return;
    }

    final counted = state.totalCountedCash;
    final expected = state.expectedClosingCash;
    final diff = state.cashDrawerVariance;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm physical cash count'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Counted in safe: ${CurrencyFormatter.formatNaira(counted)}'),
            const SizedBox(height: 6),
            Text('Target expected closing cash: ${CurrencyFormatter.formatNaira(expected)}'),
            const SizedBox(height: 6),
            Text(
              'Variance: ${CurrencyFormatter.formatVariance(diff)}'
              '${diff < 0 ? ' (shortage)' : (diff > 0 ? ' (overage)' : ' (balanced)')}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: diff < 0 ? AppColors.bad : (diff > 0 ? AppColors.warn : AppColors.ok),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your station-wide count summary will show this count as verified. Denomination rows stay editable until you leave this screen.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Keep Counting'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.ok,
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    'Physical cash count saved: ${CurrencyFormatter.formatNaira(state.totalCountedCash)}. Variance: ${CurrencyFormatter.formatVariance(state.cashDrawerVariance)}',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Save Cash Count'),
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
        onDepositRecorded: () {
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final denoms = [1000, 500, 200, 100, 50, 20, 10];
    final expected = state.expectedClosingCash;
    final counted = state.totalCountedCash;
    final diff = state.cashDrawerVariance;

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
            const Text('Daily Physical Cash Audit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Station Safe Cash Count (§5.3)', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print / Export Shift Summary',
            onPressed: () => ShiftSummaryExportDialog.show(context),
          ),
          if (widget.onOpenExpenseEntry != null)
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Disburse / Record Safe Expense',
              onPressed: widget.onOpenExpenseEntry,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Physical note count & drawer audit',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Count physical bank notes in the cashier safe. The expected closing cash formula updates dynamically from verified shifts and expenses (§5.3).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Denominations Input
                        Expanded(
                          flex: isNarrow ? 0 : 6,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '1. Denomination breakdown',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  ...denoms.map((d) {
                                    final count = state.cashCounts[d] ?? 0;
                                    final subtotal = d * count;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 75,
                                            child: Text(
                                              '₦$d',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 110,
                                            child: TextField(
                                              controller: _controllers[d],
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                errorText: _countErrors[d],
                                                errorMaxLines: 2,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              ),
                                              onChanged: (val) => _onCountChanged(d, val),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            CurrencyFormatter.formatNaira(subtotal),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  const Divider(color: AppColors.line),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total Physical Notes Counted', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        CurrencyFormatter.formatNaira(counted),
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (!isNarrow) const SizedBox(width: 16),

                        // Right: Live Expected Cash Equation Card
                        Expanded(
                          flex: isNarrow ? 0 : 5,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '2. Expected closing cash formula',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEqRow('Opening cash in drawer', CurrencyFormatter.formatNaira(state.openingCash)),
                                  _buildEqRow('+ Acknowledged interim cash drops', CurrencyFormatter.formatNaira(state.totalAcknowledgedInterimDrops), isGreen: true),
                                  _buildEqRow('+ Verified closing cash receipts', CurrencyFormatter.formatNaira(state.totalVerifiedCashReceipts), isGreen: true),
                                  _buildEqRow('− Cash expenses paid from drawer', CurrencyFormatter.formatNaira(state.totalPhysicalCashExpenses)),
                                  if (state.totalPendingCashExpenses > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, size: 14, color: AppColors.warn),
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${CurrencyFormatter.formatNaira(state.totalPendingCashExpenses)} pending manager approval)',
                                            style: const TextStyle(fontSize: 12, color: AppColors.warn, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  _buildEqRow('− Handed over for bank deposit', CurrencyFormatter.formatNaira(state.totalHandedOverDeposits)),
                                  const Divider(color: AppColors.line),
                                  _buildEqRow('Target Expected Closing Cash', CurrencyFormatter.formatNaira(expected), isBold: true),
                                  const SizedBox(height: 16),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Counted in safe', style: TextStyle(fontSize: 15, color: AppColors.muted)),
                                      Text(
                                        CurrencyFormatter.formatNaira(counted),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Variance banner with icon + word (not colour alone)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: diff < 0 ? AppColors.badSurface : (diff > 0 ? AppColors.warnSurface : AppColors.okSurface),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: diff < 0 ? AppColors.bad : (diff > 0 ? AppColors.warn : AppColors.ok),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          diff < 0
                                              ? Icons.remove_circle_outline
                                              : (diff > 0 ? Icons.add_circle_outline : Icons.check_circle_outline),
                                          size: 24,
                                          color: diff < 0 ? AppColors.bad : (diff > 0 ? AppColors.warn : AppColors.ok),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                diff < 0
                                                    ? 'Safe Drawer Variance — Shortage'
                                                    : (diff > 0 ? 'Safe Drawer Variance — Overage' : 'Safe Drawer Variance — Balanced'),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                                              ),
                                              Text(
                                                diff < 0
                                                    ? 'Counted cash is below the target closing cash.'
                                                    : (diff > 0 ? 'Counted cash is above the target closing cash.' : 'Counted cash matches the target closing cash.'),
                                                style: const TextStyle(fontSize: 12, color: AppColors.slate),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          CurrencyFormatter.formatVariance(diff),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: diff < 0 ? AppColors.bad : (diff > 0 ? AppColors.warn : AppColors.ok),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Handed over deposits badge
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.line),
                                    ),
                                    child: Row(
                                      children: [
                                        const StatusChip(label: 'Awaiting bank', type: ChipType.bank),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${CurrencyFormatter.formatNaira(state.totalHandedOverDeposits)} handed over to bank, awaiting Director credit alert verification (§5.5).',
                                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.account_balance),
                                      label: const Text('Hand Over Cash for Bank Deposit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.bank,
                                        minimumSize: const Size(0, 48),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: counted > 0
                                          ? () => _openBankDepositDialog(counted)
                                          : null,
                                    ),
                                  ),
                                  if (counted <= 0) ...[
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Count the physical notes in the safe before handing cash over to the bank.',
                                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                                    ),
                                  ],
                                  if (widget.onOpenExpenseEntry != null) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.receipt_long, color: AppColors.ink),
                                        label: const Text('Disburse / Record Safe Expense'),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: const BorderSide(color: AppColors.line),
                                        ),
                                        onPressed: widget.onOpenExpenseEntry,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.print_outlined, color: AppColors.primary),
                                      label: const Text('Print / Export Shift Summary'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        minimumSize: const Size(0, 48),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: const BorderSide(color: AppColors.primary),
                                      ),
                                      onPressed: () => ShiftSummaryExportDialog.show(context),
                                    ),
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
                  icon: const Icon(Icons.lock_clock),
                  onPressed: _saveCount,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                  label: const Text('Save cash count'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEqRow(String title, String val, {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isGreen ? AppColors.ok : AppColors.ink,
                fontSize: isBold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
