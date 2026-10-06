import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

class BankDepositDialog extends StatefulWidget {
  final double availableCash;
  final VoidCallback onDepositRecorded;

  const BankDepositDialog({
    super.key,
    required this.availableCash,
    required this.onDepositRecorded,
  });

  @override
  State<BankDepositDialog> createState() => _BankDepositDialogState();
}

class _BankDepositDialogState extends State<BankDepositDialog> {
  final state = StationAppState.instance;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _tellerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedBank = 'Zenith Bank — 1012984920 (Ajadico Ops)';
  String _selectedBearer = '';
  String _slipPhotoName = '';
  bool _isSubmitting = false;

  final List<String> _bankAccounts = [
    'Zenith Bank — 1012984920 (Ajadico Ops)',
    'GTBank — 0192847192 (Ajadico Revenue)',
    'First Bank — 2039481920 (Ajadico Bulk Sales)',
    'Access Bank — 0029481928 (Ajadico Operations)',
  ];

  @override
  void initState() {
    super.initState();
    final roleName = state.currentUser.role == UserRole.manager
        ? 'Branch Manager'
        : (state.currentUser.role == UserRole.director ? 'Director' : 'Station Cashier');
    _selectedBearer = '${state.currentUser.displayName} ($roleName)';
    _tellerController.text = 'TEL-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecond}';
    _slipPhotoName = 'teller_slip_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tellerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setAmount(double amt) {
    setState(() {
      _amountController.text = amt.toStringAsFixed(0);
    });
  }

  Future<void> _submitDeposit() async {
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please enter a valid deposit amount greater than ₦0.'),
        ),
      );
      return;
    }

    if (_tellerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please enter the stamped bank teller or reference number.'),
        ),
      );
      return;
    }

    if (amt > widget.availableCash && widget.availableCash > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warn),
              SizedBox(width: 8),
              Text('Deposit Exceeds Safe Cash'),
            ],
          ),
          content: Text(
            'The deposit amount of ${CurrencyFormatter.formatNaira(amt)} exceeds the currently computed safe cash (${CurrencyFormatter.formatNaira(widget.availableCash)}).\n\nDo you still wish to proceed with recording this deposit?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review Amount'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dep = await state.recordBankDeposit(
        amount: amt,
        bankName: _selectedBank,
        bearerName: _selectedBearer,
        tellerNumber: _tellerController.text.trim(),
        slipUrl: _slipPhotoName,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        if (dep != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.ok,
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Remitted ${CurrencyFormatter.formatNaira(amt)} to $_selectedBank! Awaiting Director credit alert confirmation.',
              ),
            ),
          );
          widget.onDepositRecorded();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.bad,
              behavior: SnackBarBehavior.floating,
              content: Text('Failed to record bank deposit. Please retry.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bad,
            behavior: SnackBarBehavior.floating,
            content: Text('Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> bearerOptions = [
      _selectedBearer,
      '${state.currentUser.displayName} (Station Cashier)',
      'Armored Bullion Van (Bank CIT Service)',
      'Branch Manager & Station Armed Security Escort',
    ].toSet().toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bank.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance, color: AppColors.bank, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hand Over Cash for Bank Deposit',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        Text(
                          'Station Safe → Commercial Bank Account (§5.4, §5.5)',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.line),

              // Safe Balance Context Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Cash in Safe:', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    Text(
                      CurrencyFormatter.formatNaira(widget.availableCash),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ok),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick-fill chips
              const Text('Quick Amount Presets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.done_all, size: 16, color: AppColors.ok),
                    label: const Text('All Safe Cash'),
                    onPressed: widget.availableCash > 0 ? () => _setAmount(widget.availableCash) : null,
                  ),
                  ActionChip(
                    label: const Text('₦500k'),
                    onPressed: () => _setAmount(500000),
                  ),
                  ActionChip(
                    label: const Text('₦1.0M'),
                    onPressed: () => _setAmount(1000000),
                  ),
                  ActionChip(
                    label: const Text('₦2.0M'),
                    onPressed: () => _setAmount(2000000),
                  ),
                  ActionChip(
                    label: const Text('₦3.5M'),
                    onPressed: () => _setAmount(3500000),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount Input
              const Text('Amount to Deposit (₦) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ink),
                decoration: const InputDecoration(
                  prefixText: '₦ ',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 16),

              // Target Commercial Bank Account
              const Text('Target Company Bank Account *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedBank,
                isExpanded: true,
                items: _bankAccounts.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBank = val);
                },
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
              const SizedBox(height: 16),

              // Depositor / Bearer
              const Text('Custody Bearer / Depositor *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedBearer,
                isExpanded: true,
                items: bearerOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBearer = val);
                },
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
              const SizedBox(height: 16),

              // Stamped Teller Reference Number
              const Text('Bank Teller / Transaction Ref No. *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _tellerController,
                decoration: const InputDecoration(
                  hintText: 'e.g. TEL-20261005-0914',
                ),
              ),
              const SizedBox(height: 16),

              // Stamped Teller Slip Photo Attachment
              const Text('Stamped Bank Teller Photo / Proof', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt, color: AppColors.bank, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _slipPhotoName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('Attached'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Stamped bank teller slip photo attached.'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Operational Notes
              const Text('Audit Notes / Memo (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Shift 1 sales cash banking',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSubmitting ? 'Recording Deposit...' : 'Hand Over Cash & Remit to Director'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bank,
                  ),
                  onPressed: _isSubmitting ? null : _submitDeposit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
