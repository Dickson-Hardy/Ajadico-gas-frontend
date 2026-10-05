import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

class RemittanceScreen extends StatefulWidget {
  final double expectedSalesValue;
  final VoidCallback onBack;
  final VoidCallback onSubmitSuccess;

  const RemittanceScreen({
    super.key,
    this.expectedSalesValue = 1250000.0,
    required this.onBack,
    required this.onSubmitSuccess,
  });

  @override
  State<RemittanceScreen> createState() => _RemittanceScreenState();
}

class _RemittanceScreenState extends State<RemittanceScreen> {
  final TextEditingController _cashController = TextEditingController(text: '0');
  final TextEditingController _posCardController = TextEditingController(text: '0');
  final TextEditingController _posTransferController = TextEditingController(text: '0');
  final TextEditingController _bankTransferController = TextEditingController(text: '0');

  final double _creditSales = 180000.0; // Registered credit sales for this shift
  int _attachedReceiptCount = 0;

  double get _cash => double.tryParse(_cashController.text.replaceAll(',', '')) ?? 0.0;
  double get _posCard => double.tryParse(_posCardController.text.replaceAll(',', '')) ?? 0.0;
  double get _posTransfer => double.tryParse(_posTransferController.text.replaceAll(',', '')) ?? 0.0;
  double get _bankTransfer => double.tryParse(_bankTransferController.text.replaceAll(',', '')) ?? 0.0;

  double get _moneyDeclared => _cash + _posCard + _posTransfer + _bankTransfer;
  double get _variance => (_moneyDeclared + _creditSales) - widget.expectedSalesValue;

  @override
  void dispose() {
    _cashController.dispose();
    _posCardController.dispose();
    _posTransferController.dispose();
    _bankTransferController.dispose();
    super.dispose();
  }

  void _addEvidencePhoto() {
    setState(() {
      _attachedReceiptCount++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('POS receipt / transfer screenshot #$_attachedReceiptCount attached.'),
      ),
    );
  }

  void _submit() {
    if (_moneyDeclared <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please declare your payment amounts')),
      );
      return;
    }

    widget.onSubmitSuccess();
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
            Text('Remittance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  'Remittance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Declare how the sales were paid. Upload a receipt for every non-cash line.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // Expected Sales Value Banner
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Expected sales value',
                          style: TextStyle(fontSize: 16, color: AppColors.muted),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(widget.expectedSalesValue),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Payment Declaration Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment declaration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildInputField('Cash', _cashController),
                        const SizedBox(height: 12),
                        _buildInputField('POS card', _posCardController),
                        const SizedBox(height: 12),
                        _buildInputField('Transfer to station POS account', _posTransferController),
                        const SizedBox(height: 12),
                        _buildInputField('Transfer to company bank account', _bankTransferController),
                        const SizedBox(height: 16),

                        // Receipt Upload Box
                        InkWell(
                          onTap: _addEvidencePhoto,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.line,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_alt, color: AppColors.muted, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  _attachedReceiptCount == 0
                                      ? 'Tap to add POS printout or bank receipt photo'
                                      : '$_attachedReceiptCount receipt photo(s) attached · Tap to add more',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
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

                // Reconciliation Breakdown Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          'Credit sales (not money received)',
                          CurrencyFormatter.formatNaira(_creditSales),
                        ),
                        const Divider(color: AppColors.line),
                        _buildSummaryRow(
                          'Money declared',
                          CurrencyFormatter.formatNaira(_moneyDeclared),
                        ),
                        const Divider(color: AppColors.line),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Difference',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatVariance(_variance),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: _variance < 0 ? AppColors.bad : (_variance > 0 ? AppColors.ok : AppColors.ink),
                                ),
                              ),
                            ],
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
                child: const Text('Submit remittance'),
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

  Widget _buildInputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: '₦ ',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
