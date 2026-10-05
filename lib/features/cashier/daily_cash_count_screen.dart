import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';

class DailyCashCountScreen extends StatefulWidget {
  final VoidCallback onBack;

  const DailyCashCountScreen({super.key, required this.onBack});

  @override
  State<DailyCashCountScreen> createState() => _DailyCashCountScreenState();
}

class _DailyCashCountScreenState extends State<DailyCashCountScreen> {
  final Map<int, int> _counts = {
    1000: 0,
    500: 0,
    200: 0,
    100: 0,
    50: 0,
    20: 0,
    10: 0,
  };

  // Expected Cash equation numbers
  final double _openingCash = 120000.0;
  final double _cashReceipts = 640000.0;
  final double _cashExpenses = 45000.0;
  final double _handedOverForDeposit = 500000.0;

  double get _expectedClosingCash =>
      _openingCash + _cashReceipts - _cashExpenses - _handedOverForDeposit; // 215,000

  double get _totalCounted {
    double sum = 0;
    _counts.forEach((denom, count) {
      sum += (denom * count);
    });
    return sum;
  }

  double get _variance => _totalCounted - _expectedClosingCash;

  void _onCountChanged(int denom, String val) {
    final count = int.tryParse(val.trim()) ?? 0;
    setState(() {
      _counts[denom] = count;
    });
  }

  void _saveCount() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        content: Text('Daily physical cash count saved. Total: ${CurrencyFormatter.formatNaira(_totalCounted)}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final denoms = [1000, 500, 200, 100, 50, 20, 10];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Cash Count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Cashier · Chidi E. · Lekki Road', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Daily cash count',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Count the notes. Expected cash is worked out for you.',
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
                        // Left: Denominations Table
                        Expanded(
                          flex: isNarrow ? 0 : 6,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Denominations',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  ...denoms.map((d) {
                                    final subtotal = d * (_counts[d] ?? 0);
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 70,
                                            child: Text(
                                              '₦$d',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: 100,
                                            child: TextFormField(
                                              initialValue: _counts[d] == 0 ? '' : _counts[d].toString(),
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
                                              fontSize: 16,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (!isNarrow) const SizedBox(width: 16),

                        // Right: Expected Closing Cash & Reconciliation Formula
                        Expanded(
                          flex: isNarrow ? 0 : 5,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Expected closing cash',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEqRow('Opening cash', CurrencyFormatter.formatNaira(_openingCash)),
                                  _buildEqRow('+ Cash receipts', CurrencyFormatter.formatNaira(_cashReceipts)),
                                  _buildEqRow('− Cash expenses', CurrencyFormatter.formatNaira(_cashExpenses)),
                                  _buildEqRow('− Handed over for deposit', CurrencyFormatter.formatNaira(_handedOverForDeposit)),
                                  const Divider(color: AppColors.line),
                                  _buildEqRow(
                                    'Expected',
                                    CurrencyFormatter.formatNaira(_expectedClosingCash),
                                    isBold: true,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Counted', style: TextStyle(fontSize: 16, color: AppColors.ink)),
                                      Text(
                                        CurrencyFormatter.formatNaira(_totalCounted),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Difference', style: TextStyle(fontSize: 16, color: AppColors.ink)),
                                      Text(
                                        CurrencyFormatter.formatVariance(_variance),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: _variance < 0 ? AppColors.bad : (_variance > 0 ? AppColors.ok : AppColors.ink),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
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
                                            '${CurrencyFormatter.formatNaira(_handedOverForDeposit)} handed over, awaiting Senior bank alert confirmation.',
                                            style: const TextStyle(fontSize: 13, color: AppColors.muted),
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
              child: ElevatedButton(
                onPressed: _saveCount,
                child: const Text('Save count'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEqRow(String title, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.ink)),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
        ],
      ),
    );
  }
}
