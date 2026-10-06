import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/evidence_photo_picker.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

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
  final state = StationAppState.instance;
  String _category = 'Generator Maintenance & Servicing';
  ExpensePaymentSource _paymentSource = ExpensePaymentSource.salesCash;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _receiptAttached = false;
  bool _isSubmitting = false;
  bool _isPreApproved = false;
  List<CompressedImageResult> _receiptPhotos = [];

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
        const SnackBar(
          backgroundColor: AppColors.bad,
          content: Text('Please enter a valid expense amount'),
        ),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          content: Text('Please enter a description for the expense'),
        ),
      );
      return;
    }

    final isCashier = state.currentUser.role == UserRole.cashier;
    final needsApproval = isCashier ? !_isPreApproved : (amount > 50000);

    setState(() => _isSubmitting = true);
    try {
      state.recordExpense(
        category: _category,
        amount: amount,
        paymentSource: _paymentSource == ExpensePaymentSource.salesCash ? 'Cash Drawer' : 'Direct Bank Transfer',
        description: _descriptionController.text.trim(),
        receiptUrl: _receiptPhotos.isNotEmpty ? _receiptPhotos.first.fileName : null,
        requiresApproval: needsApproval,
      );

      final statusMsg = needsApproval
          ? 'Expense of ${CurrencyFormatter.formatNaira(amount)} queued for Manager / Admin approval.'
          : 'Expense of ${CurrencyFormatter.formatNaira(amount)} recorded and approved.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: needsApproval ? AppColors.warn : AppColors.ok,
          behavior: SnackBarBehavior.floating,
          content: Text(statusMsg),
        ),
      );
      widget.onSuccess();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
            Text(
              state.currentUser.role == UserRole.cashier
                  ? 'Record Safe Expense Disbursal'
                  : 'Record Branch Expense',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              state.currentUser.role == UserRole.cashier
                  ? '${state.currentUser.displayName} · Station Cash Safe (§5.1, §5.2)'
                  : '${state.currentUser.displayName} · Manager / Admin Entry (§5.1, §5.2)',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
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

                if (state.currentUser.role == UserRole.cashier) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isPreApproved ? AppColors.ok.withOpacity(0.08) : AppColors.warn.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isPreApproved ? AppColors.ok : AppColors.warn),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPreApproved ? Icons.verified_user : Icons.pending_actions,
                          color: _isPreApproved ? AppColors.ok : AppColors.warn,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isPreApproved ? 'Pre-Approved by Station Manager' : 'Requires Manager / Admin Approval',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                              ),
                              Text(
                                _isPreApproved
                                    ? 'Cashier disburses funds based on verbal or written manager instruction.'
                                    : 'Expense will appear in Manager Dashboard queue for formal review & sign-off.',
                                style: const TextStyle(fontSize: 12, color: AppColors.slate),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPreApproved,
                          onChanged: (val) => setState(() => _isPreApproved = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

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

                        EvidencePhotoPicker(
                          title: 'Receipt / Invoice Photo (<150KB)',
                          photoType: 'expense_receipt',
                          stationName: state.currentStationName,
                          staffName: state.currentUser.displayName,
                          bucketName: 'expense-receipts',
                          maxPhotos: 1,
                          onPhotosChanged: (photos) {
                            setState(() {
                              _receiptPhotos = photos;
                              _receiptAttached = photos.isNotEmpty;
                            });
                          },
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
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save expense entry'),
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
