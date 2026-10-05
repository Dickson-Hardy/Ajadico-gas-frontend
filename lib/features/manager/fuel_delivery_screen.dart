import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';

class FuelDeliveryScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const FuelDeliveryScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<FuelDeliveryScreen> createState() => _FuelDeliveryScreenState();
}

class _FuelDeliveryScreenState extends State<FuelDeliveryScreen> {
  String _selectedTank = 'T1 (PMS)';
  final TextEditingController _supplierController = TextEditingController(text: 'Matrix Energy Ltd');
  final TextEditingController _waybillNumberController = TextEditingController(text: 'WB-99412');
  final TextEditingController _statedLitresController = TextEditingController(text: '33000');
  final TextEditingController _dipBeforeController = TextEditingController(text: '8200');
  final TextEditingController _dipAfterController = TextEditingController(text: '41050');
  final TextEditingController _pricePerLitreController = TextEditingController(text: '940');
  bool _waybillPhotoAttached = true;

  double get _statedLitres => double.tryParse(_statedLitresController.text.trim()) ?? 0.0;
  double get _dipBefore => double.tryParse(_dipBeforeController.text.trim()) ?? 0.0;
  double get _dipAfter => double.tryParse(_dipAfterController.text.trim()) ?? 0.0;
  double get _receivedLitres => (_dipAfter > _dipBefore) ? (_dipAfter - _dipBefore) : 0.0;
  double get _discrepancy => _receivedLitres - _statedLitres;

  @override
  void dispose() {
    _supplierController.dispose();
    _waybillNumberController.dispose();
    _statedLitresController.dispose();
    _dipBeforeController.dispose();
    _dipAfterController.dispose();
    _pricePerLitreController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_receivedLitres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dip after delivery must be greater than dip before')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        content: Text(
          'Fuel delivery of ${CurrencyFormatter.formatLitres(_receivedLitres)} logged for Tank $_selectedTank (Discrepancy: ${CurrencyFormatter.formatLitres(_discrepancy)}).',
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
            Text('Record Fuel Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Tanker Discharge & Waybill Entry (§3.7–§3.9)', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Record fuel delivery',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Compare physical Before & After tank dips against stated truck waybill volume.',
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
                                  const Text('Receiving Tank', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedTank,
                                    items: const [
                                      DropdownMenuItem(value: 'T1 (PMS)', child: Text('Tank T1 · PMS (45,000 L)')),
                                      DropdownMenuItem(value: 'T2 (PMS)', child: Text('Tank T2 · PMS (45,000 L)')),
                                      DropdownMenuItem(value: 'T3 (AGO)', child: Text('Tank T3 · AGO (33,000 L)')),
                                    ],
                                    onChanged: (v) => setState(() => _selectedTank = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Supplier Name', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _supplierController,
                                    decoration: const InputDecoration(hintText: 'e.g. Matrix Energy'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Waybill Number', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _waybillNumberController,
                                    decoration: const InputDecoration(hintText: 'WB-12345'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Stated Litres (Waybill)', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _statedLitresController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(suffixText: 'L'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Dip BEFORE Delivery (L)', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _dipBeforeController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(suffixText: 'L'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Dip AFTER Delivery (L)', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _dipAfterController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(suffixText: 'L'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        InkWell(
                          onTap: () => setState(() => _waybillPhotoAttached = !_waybillPhotoAttached),
                          child: Container(
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _waybillPhotoAttached ? Icons.check_circle : Icons.camera_alt,
                                    color: _waybillPhotoAttached ? AppColors.ok : AppColors.muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _waybillPhotoAttached
                                        ? 'Waybill & Driver Sign-off Photo Attached'
                                        : 'Tap to photograph supplier waybill (§3.7)',
                                    style: TextStyle(
                                      color: _waybillPhotoAttached ? AppColors.ok : AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Delivery Reconciliation Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildRow('Stated Litres on Waybill', CurrencyFormatter.formatLitres(_statedLitres)),
                        const Divider(color: AppColors.line),
                        _buildRow('Actual Received Litres (Dip Diff)', CurrencyFormatter.formatLitres(_receivedLitres)),
                        const Divider(color: AppColors.line),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Discrepancy (Loss / Gain)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                            Row(
                              children: [
                                StatusChip(
                                  label: _discrepancy < 0
                                      ? 'Shortage ${CurrencyFormatter.formatLitres(_discrepancy)}'
                                      : (_discrepancy > 0 ? '+${CurrencyFormatter.formatLitres(_discrepancy)}' : 'Exact match'),
                                  type: _discrepancy < 0 ? ChipType.bad : ChipType.ok,
                                ),
                              ],
                            ),
                          ],
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
                child: const Text('Save fuel delivery record'),
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

  Widget _buildRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
          Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
        ],
      ),
    );
  }
}
