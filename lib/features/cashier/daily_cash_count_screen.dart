import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';

class DailyCashCountScreen extends StatefulWidget {
  final VoidCallback onBack;

  const DailyCashCountScreen({super.key, required this.onBack});

  @override
  State<DailyCashCountScreen> createState() => _DailyCashCountScreenState();
}

class _DailyCashCountScreenState extends State<DailyCashCountScreen> {
  final state = StationAppState.instance;

  final Map<int, TextEditingController> _controllers = {};

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
    final count = int.tryParse(val.trim()) ?? 0;
    state.updateCashCount(denom, count);
  }

  void _saveCount() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Physical cash count saved: ${CurrencyFormatter.formatNaira(state.totalCountedCash)}. Variance: ${CurrencyFormatter.formatVariance(state.cashDrawerVariance)}',
        ),
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
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Physical Cash Audit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Station Safe Cash Count (§5.3)', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
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
                                            width: 100,
                                            child: TextField(
                                              controller: _controllers[d],
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                hintText: '0',
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                  _buildEqRow('+ Verified shift cash receipts', CurrencyFormatter.formatNaira(state.totalVerifiedCashReceipts), isGreen: true),
                                  _buildEqRow('− Cash expenses paid from drawer', CurrencyFormatter.formatNaira(state.totalPhysicalCashExpenses)),
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Safe Drawer Variance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      Text(
                                        CurrencyFormatter.formatVariance(diff),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: diff < 0 ? AppColors.bad : (diff > 0 ? AppColors.ok : AppColors.ink),
                                        ),
                                      ),
                                    ],
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
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_clock),
                onPressed: _saveCount,
                label: const Text('Save verified cash count & lock drawer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEqRow(String title, String val, {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.ink)),
          Text(
            val,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isGreen ? AppColors.ok : AppColors.ink,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
