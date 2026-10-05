import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/nozzle.dart';
import '../../state/station_app_state.dart';

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
  final state = StationAppState.instance;

  String _selectedProduct = 'PMS';
  late TextEditingController _newPriceController;
  final TextEditingController _authorizedReasonController = TextEditingController(text: 'Depot wholesale price adjustment authorized by Director');
  late Map<int, TextEditingController> _meterControllers;

  @override
  void initState() {
    super.initState();
    _newPriceController = TextEditingController(
      text: (_selectedProduct == 'PMS' ? state.pmsPrice : state.agoPrice).toStringAsFixed(0),
    );
    _meterControllers = {
      for (var n in state.nozzles)
        n.nozzleNumber: TextEditingController(
          text: (n.closingReading ?? n.openingReading).toStringAsFixed(1),
        )
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

  void _onProductChanged(String? prod) {
    if (prod == null) return;
    setState(() {
      _selectedProduct = prod;
      _newPriceController.text = (prod == 'PMS' ? state.pmsPrice : state.agoPrice).toStringAsFixed(0);
    });
  }

  void _submit() {
    final newPrice = double.tryParse(_newPriceController.text.trim()) ?? 0.0;
    if (newPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please enter a valid retail price'),
        ),
      );
      return;
    }

    // Collect meter snapshots
    final Map<int, double> snapshots = {};
    for (var n in state.nozzles.where((n) => n.productName == _selectedProduct)) {
      final dial = double.tryParse(_meterControllers[n.nozzleNumber]?.text ?? '') ?? n.openingReading;
      snapshots[n.nozzleNumber] = dial;
    }

    state.authorizePriceChange(
      product: _selectedProduct,
      newPrice: newPrice,
      reason: _authorizedReasonController.text.trim(),
      meterSnapshots: snapshots,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '$_selectedProduct price changed to ${CurrencyFormatter.formatNaira(newPrice)}/L! Transition meter dials captured across all nozzles.',
        ),
      ),
    );

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final currentPrice = _selectedProduct == 'PMS' ? state.pmsPrice : state.agoPrice;

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
            Text('Director · Central Price Governance (§2.8, §2.9)', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Authorize retail price adjustment',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'At a price change, the system captures transition meter readings across all nozzles. Previous sales are locked at old price; new sales calculate at new price (§2.9).',
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
                                  const Text('Product', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedProduct,
                                    items: [
                                      DropdownMenuItem(value: 'PMS', child: Text('PMS (Current: ${CurrencyFormatter.formatNaira(state.pmsPrice)})')),
                                      DropdownMenuItem(value: 'AGO', child: Text('AGO (Current: ${CurrencyFormatter.formatNaira(state.agoPrice)})')),
                                    ],
                                    onChanged: _onProductChanged,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('New Retail Price (₦/L) *', style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.bold)),
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

                        const Text('Authorization Directive / Commercial Justification', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _authorizedReasonController,
                          decoration: const InputDecoration(hintText: 'e.g. NNPC depot rate revision approved by Director'),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Transition Meter Readings
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
                        Text(
                          'Enter current physical meter reading on each $_selectedProduct nozzle at the moment of price change:',
                          style: const TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                        ...state.nozzles.where((n) => n.productName == _selectedProduct).map((n) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Nozzle ${n.nozzleNumber} (${n.productName})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Tank ${n.tankCode}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
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
              child: ElevatedButton.icon(
                icon: const Icon(Icons.security_update_good),
                onPressed: _submit,
                label: const Text('Authorize & apply new price'),
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
