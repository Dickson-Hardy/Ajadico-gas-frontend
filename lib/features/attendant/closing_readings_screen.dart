import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/nozzle.dart';

class ClosingReadingsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(double totalExpectedSales) onSubmitSuccess;

  const ClosingReadingsScreen({
    super.key,
    required this.onBack,
    required this.onSubmitSuccess,
  });

  @override
  State<ClosingReadingsScreen> createState() => _ClosingReadingsScreenState();
}

class _ClosingReadingsScreenState extends State<ClosingReadingsScreen> {
  late List<NozzleItem> _nozzles;
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _nozzles = NozzleItem.getDemoNozzles();
    for (var n in _nozzles) {
      _controllers[n.nozzleNumber] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalExpectedSales {
    return _nozzles.fold(0.0, (sum, item) => sum + item.salesValue);
  }

  void _onClosingChanged(NozzleItem nozzle, String val) {
    final parsed = double.tryParse(val.replaceAll(',', ''));
    setState(() {
      nozzle.closingReading = parsed;
    });
  }

  void _submit() {
    for (var n in _nozzles) {
      if (n.closingReading == null || n.closingReading! < n.openingReading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nozzle ${n.nozzleNumber} closing reading must be greater than opening (${CurrencyFormatter.formatLitres(n.openingReading)})',
            ),
          ),
        );
        return;
      }
    }

    widget.onSubmitSuccess(_totalExpectedSales);
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
            Text('Closing Readings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Amaka O. · Morning shift', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Closing readings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Type each meter reading. Litres and value update as you type.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // Nozzle Cards
                ..._nozzles.map((nozzle) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nozzle ${nozzle.nozzleNumber} · ${nozzle.productName}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Opening (L)', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      initialValue: nozzle.openingReading.toStringAsFixed(1),
                                      readOnly: true,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Closing (L)', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _controllers[nozzle.nozzleNumber],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter closing',
                                      ),
                                      onChanged: (val) => _onClosingChanged(nozzle, val),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Price (₦/L)', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      initialValue: nozzle.pricePerLitre.toStringAsFixed(0),
                                      readOnly: true,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: 'Litres sold: ',
                                  style: const TextStyle(fontSize: 15, color: AppColors.muted),
                                  children: [
                                    TextSpan(
                                      text: CurrencyFormatter.formatLitres(nozzle.litresSold),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatNaira(nozzle.salesValue),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                // Total Expected Sales Summary Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total expected sales',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(_totalExpectedSales),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ok,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              flex: 2,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Submit readings'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Save draft'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
