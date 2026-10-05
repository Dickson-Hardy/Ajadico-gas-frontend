import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../state/station_app_state.dart';

class RemittanceScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSubmitSuccess;

  const RemittanceScreen({
    super.key,
    required this.onBack,
    required this.onSubmitSuccess,
  });

  @override
  State<RemittanceScreen> createState() => _RemittanceScreenState();
}

class _RemittanceScreenState extends State<RemittanceScreen> {
  final state = StationAppState.instance;

  final TextEditingController _cashController = TextEditingController(text: '640000');
  final TextEditingController _posCardController = TextEditingController(text: '310000');
  final TextEditingController _posTransferController = TextEditingController(text: '120000');
  final TextEditingController _bankTransferController = TextEditingController(text: '0');

  final double _creditSales = 180000.0;
  final List<String> _attachedReceipts = ['POS Terminal 01 Slip (₦310k)', 'Customer Bank Alert Slip (₦120k)'];

  double get _expectedSalesValue {
    final computed = state.nozzles.fold(0.0, (s, n) => s + n.salesValue);
    return computed > 0 ? computed : 1250000.0;
  }

  double get _cash => double.tryParse(_cashController.text.replaceAll(',', '')) ?? 0.0;
  double get _posCard => double.tryParse(_posCardController.text.replaceAll(',', '')) ?? 0.0;
  double get _posTransfer => double.tryParse(_posTransferController.text.replaceAll(',', '')) ?? 0.0;
  double get _bankTransfer => double.tryParse(_bankTransferController.text.replaceAll(',', '')) ?? 0.0;

  double get _moneyDeclared => _cash + _posCard + _posTransfer + _bankTransfer;
  double get _variance => (_moneyDeclared + _creditSales) - _expectedSalesValue;

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
      _attachedReceipts.add('POS Slip #${_attachedReceipts.length + 1} (${DateTime.now().hour}:${DateTime.now().minute})');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.bank,
        behavior: SnackBarBehavior.floating,
        content: Text('POS receipt photo #${_attachedReceipts.length} attached.'),
      ),
    );
  }

  void _submit() {
    if (_moneyDeclared <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please declare your sales cash and non-cash collections.'),
        ),
      );
      return;
    }

    state.submitRemittance(
      cash: _cash,
      posCard: _posCard,
      posTransfer: _posTransfer,
      bankTransfer: _bankTransfer,
      credit: _creditSales,
      evidencePhotos: _attachedReceipts,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content: Text('Remittance submitted to Cashier Verification Queue in real-time!'),
      ),
    );

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shift Remittance Declaration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Morning shift', style: const TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Declare sales collections',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Breakdown sales across Cash, POS card, and Transfers. Attach physical merchant slips for every non-cash channel.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // Expected Sales Value Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Expected Sales', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                            Text('Derived from dispenser meter readings', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(_expectedSalesValue),
                          style: const TextStyle(
                            fontSize: 26,
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
                          'Payment declaration channels',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        const SizedBox(height: 14),
                        _buildInputField('1. Physical Sales Cash handed to cashier', _cashController),
                        const SizedBox(height: 12),
                        _buildInputField('2. POS Card Payments (Terminal merchant slips)', _posCardController),
                        const SizedBox(height: 12),
                        _buildInputField('3. Customer Transfer to Station POS Terminal Account', _posTransferController),
                        const SizedBox(height: 12),
                        _buildInputField('4. Direct Transfer to Company Bank Account', _bankTransferController),
                        const SizedBox(height: 16),

                        // Receipt Upload Box
                        InkWell(
                          onTap: _addEvidencePhoto,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.camera_alt, color: AppColors.bank, size: 30),
                                const SizedBox(height: 8),
                                Text(
                                  _attachedReceipts.isEmpty
                                      ? 'Tap to photograph POS printout or bank slip'
                                      : '${_attachedReceipts.length} slip(s) attached · Tap to snap another',
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_attachedReceipts.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: _attachedReceipts.map((r) {
                                      return Chip(
                                        backgroundColor: AppColors.card,
                                        label: Text(r, style: const TextStyle(fontSize: 11)),
                                        avatar: const Icon(Icons.receipt, size: 14, color: AppColors.bank),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Reconciliation Calculation Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryRow('Credit Sales on signed requisitions', CurrencyFormatter.formatNaira(_creditSales)),
                        const Divider(color: AppColors.line),
                        _buildSummaryRow('Total Money Declared (Cash + POS + Bank)', CurrencyFormatter.formatNaira(_moneyDeclared)),
                        const Divider(color: AppColors.line),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Attendant Difference', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                  Text(
                                    _variance < 0
                                        ? 'Shortfall will feed salary deduction register'
                                        : (_variance > 0 ? 'Excess recorded for management review' : 'Balanced account'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _variance < 0 ? AppColors.bad : (_variance > 0 ? AppColors.warn : AppColors.ok),
                                    ),
                                  ),
                                ],
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
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                onPressed: _submit,
                label: const Text('Submit shift remittance'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Back to home'),
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
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500)),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink)),
        ],
      ),
    );
  }
}
