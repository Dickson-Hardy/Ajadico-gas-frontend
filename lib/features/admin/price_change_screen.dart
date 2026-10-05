import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/nozzle.dart';

class PriceChangeScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const PriceChangeScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<PriceChangeScreen> createState() => _PriceChangeScreenState();
}

class _PriceChangeScreenState extends State<PriceChangeScreen> {
  String _selectedProduct = 'PMS';
  final TextEditingController _newPriceController = TextEditingController(text: '1080');
  final TextEditingController _authorizedReasonController = TextEditingController();

  final List<NozzleItem> _nozzles = NozzleItem.getDemoNozzles();
  late Map<int, TextEditingController> _meterControllers;

  @override
  void initState() {
    super.initState();
    _meterControllers = {
      for (var n in _nozzles)
        n.nozzleNumber: TextEditingController(text: n.openingReading.toStringAsFixed(1))
    };
  }

  @override
  void dispose() {
    _newPriceController.dispose();
    _authorizedReasonController.dispose();
    for (var c in _meterControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final newPrice = double.tryParse(_newPriceController.text.trim()) ?? 0.0;
    if (newPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid fuel price')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        content: Text(
          'Price change to ${CurrencyFormatter.formatNaira(newPrice)}/L authorized by Senior. Meter readings snapshot recorded (§2.9).',
        ),
      ),
    );
    widget.onSuccess();
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
            Text('Fuel Price Authorization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Senior / Central Management (§2.8, §2.9)', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Authorize price change',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Records meter reading snapshot at price change time to close old-price sales and start new-price period (§2.9).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Product', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedProduct,
                                    items: const [
                                      DropdownMenuItem(value: 'PMS', child: Text('PMS (Petrol) - Current: ₦1,050')),
                                      DropdownMenuItem(value: 'AGO', child: Text('AGO (Diesel) - Current: ₦1,320')),
                                    ],
                                    onChanged: (v) => setState(() => _selectedProduct = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('New Retail Price (₦/L)', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _newPriceController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(prefixText: '₦ '),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text('Authorization Directive / Reason', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _authorizedReasonController,
                          decoration: const InputDecoration(hintText: 'e.g. Market depot wholesale rate adjustment approved by Senior'),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Meter Snapshot Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transition Meter Readings Snapshot',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter current physical meter reading on each nozzle to lock the old-price period.',
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                        ..._nozzles.where((n) => n.productName == _selectedProduct).map((n) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text('Nozzle ${n.nozzleNumber} (${n.productName})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _meterControllers[n.nozzleNumber],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      suffixText: 'L',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
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
                child: const Text('Apply new price & split periods'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
