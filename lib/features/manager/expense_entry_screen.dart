import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/navigation/shell_back_guard.dart';
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

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> with UnsavedWorkAware {
  final state = StationAppState.instance;
  String _category = 'Generator Maintenance & Servicing';
  ExpensePaymentSource _paymentSource = ExpensePaymentSource.salesCash;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
  bool get hasUnsavedWork =>
      _amountController.text.trim().isNotEmpty || _descriptionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    ShellBackGuard.register(this);
  }

  @override
  void dispose() {
    ShellBackGuard.unregister(this);
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _confirmDiscard(VoidCallback onDiscard) {
    if (!hasUnsavedWork) {
      onDiscard();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard expense entry?'),
        content: const Text('This expense has not been saved yet. Leaving now discards what you typed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDiscard();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bad,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.bad,
            behavior: SnackBarBehavior.floating,
            content: Text('Could not save this expense. Please review the entries and retry.'),
          ),
        );
      }
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
          tooltip: 'Back',
          onPressed: () => _confirmDiscard(widget.onBack),
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
                  ? '${state.currentUser.displayName} · Station Cash Safe'
                  : '${state.currentUser.displayName} · Manager / Admin Entry',
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
                  'Sales cash expenses are deducted from drawer cash; bank-paid expenses are excluded.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                if (state.currentUser.role == UserRole.cashier) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isPreApproved
                          ? AppColors.ok.withValues(alpha: 0.08)
                          : AppColors.warn.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
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
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expense Category', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                          const SizedBox(height: 16),

                          const Text('Amount (₦)', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: (v) {
                              final amount = double.tryParse((v ?? '').replaceAll(',', '').trim()) ?? 0.0;
                              if (amount <= 0) return 'Enter a valid expense amount greater than ₦0.';
                              return null;
                            },
                            decoration: const InputDecoration(
                              prefixText: '₦ ',
                              hintText: 'e.g. 15,000',
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text('Payment Source', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                          const SizedBox(height: 6),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              Widget tileA = const RadioListTile<ExpensePaymentSource>(
                                value: ExpensePaymentSource.salesCash,
                                title: Text('Sales Cash (Deducts from drawer)'),
                              );
                              Widget tileB = const RadioListTile<ExpensePaymentSource>(
                                value: ExpensePaymentSource.bankTransfer,
                                title: Text('Direct Bank Transfer'),
                              );
                              final Widget group = constraints.maxWidth < 520
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [tileA, tileB],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(child: tileA),
                                        Expanded(child: tileB),
                                      ],
                                    );
                              return RadioGroup<ExpensePaymentSource>(
                                groupValue: _paymentSource,
                                onChanged: (val) {
                                  if (val != null) setState(() => _paymentSource = val);
                                },
                                child: group,
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          const Text('Description & Vendor', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _descriptionController,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a description for the expense.' : null,
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
                              });
                            },
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
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
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
                  onPressed: () => _confirmDiscard(widget.onBack),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
