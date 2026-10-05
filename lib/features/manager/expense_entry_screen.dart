import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

enum ExpensePaymentSource { salesCash, bankTransfer }

class ExpenseEntryScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const ExpenseEntryScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  String _category = 'Generator Maintenance';
  ExpensePaymentSource _paymentSource = ExpensePaymentSource.salesCash;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _receiptAttached = false;

  final List<String> _categories = [
    'Generator Maintenance & Servicing',
    'Station Cleaning & Forecourt Care',
    'Utilities (NEPA / Water)',
    'Stationery & POS Paper Rolls',
    'Local Security / Guard Allowance',
    'Minor Pump / Hose Repairs',
    'Other Operational Expenses',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount')),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description for the expense')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        content: Text(
          'Expense of ${CurrencyFormatter.formatNaira(amount)} recorded under $_category (${_paymentSource == ExpensePaymentSource.salesCash ? "Cash Drawer" : "Bank Transfer"}).',
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
            Text('Record Branch Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Cashier / Manager Entry (§5.1, §5.2)', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Record station expense',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sales cash expenses are deducted from drawer cash; bank-paid expenses are excluded (§5.2).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Expense Category', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _category,
                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _category = v!),
                        ),
                        const SizedBox(height: 16),

                        const Text('Amount (₦)', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            prefixText: '₦ ',
                            hintText: 'e.g. 15,000',
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text('Payment Source', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<ExpensePaymentSource>(
                                value: ExpensePaymentSource.salesCash,
                                groupValue: _paymentSource,
                                title: const Text('Sales Cash (Deducts from drawer)'),
                                onChanged: (v) => setState(() => _paymentSource = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<ExpensePaymentSource>(
                                value: ExpensePaymentSource.bankTransfer,
                                groupValue: _paymentSource,
                                title: const Text('Direct Bank Transfer'),
                                onChanged: (v) => setState(() => _paymentSource = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        const Text('Description & Vendor', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(hintText: 'Detailed explanation of purchase and vendor name...'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        InkWell(
                          onTap: () => setState(() => _receiptAttached = !_receiptAttached),
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
                                    _receiptAttached ? Icons.check_circle : Icons.camera_alt,
                                    color: _receiptAttached ? AppColors.ok : AppColors.muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _receiptAttached
                                        ? 'Receipt / Invoice Photo Attached'
                                        : 'Tap to photograph physical receipt or invoice',
                                    style: TextStyle(
                                      color: _receiptAttached ? AppColors.ok : AppColors.muted,
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
                child: const Text('Save expense entry'),
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
