import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/evidence_photo_picker.dart';
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

  final _bankController = TextEditingController();
  String get _selectedBank => _bankController.text.trim();
  String _selectedBearer = '';
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<CompressedImageResult> _slipPhotos = [];
  String _formError = '';
  bool _isSubmitting = false;
  bool _allowClose = false;
  bool _askingToClose = false;

  bool get _hasDraft =>
      [_amountController, _bankController, _tellerController, _notesController]
          .any((controller) => controller.text.trim().isNotEmpty) ||
      _slipPhotos.isNotEmpty;

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  void _closeAfterSave() {
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _requestClose() async {
    if (_isSubmitting || _askingToClose) return;
    if (_hasDraft) {
      _askingToClose = true;
      final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Discard deposit entry?'),
                  content: const Text(
                      'This deposit has not been recorded. Leaving discards the draft.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep editing')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Discard')),
                  ]));
      _askingToClose = false;
      if (discard != true || !mounted) return;
    }
    _closeAfterSave();
  }

  double? get _lastDepositAmount {
    if (state.deposits.isEmpty) return null;
    return state.deposits.first.amount;
  }

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _amountController,
      _bankController,
      _tellerController,
      _notesController
    ]) {
      controller.addListener(_draftChanged);
    }
    final roleName = state.currentUser.role == UserRole.manager
        ? 'Branch Manager'
        : (state.currentUser.role == UserRole.director
            ? 'Director'
            : 'Station Cashier');
    _selectedBearer = '${state.currentUser.displayName} ($roleName)';
  }

  @override
  void dispose() {
    _bankController.dispose();
    _amountController.dispose();
    _tellerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setAmount(double amt) {
    setState(() {
      _amountController.text = amt.toStringAsFixed(0);
      _formError = '';
    });
  }

  Future<void> _submitDeposit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final photoMissing = _slipPhotos.isEmpty;
    if (!formValid || photoMissing) {
      setState(() {
        _formError = photoMissing
            ? 'Attach the stamped bank teller photo before handing over cash.'
            : '';
      });
      return;
    }
    setState(() => _formError = '');

    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;

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
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Review Amount'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bad,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
              ),
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
        slipUrl:
            _slipPhotos.isNotEmpty ? _slipPhotos.first.remoteStorageUrl : '',
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;

      if (dep != null) {
        _closeAfterSave();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.ok,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Deposit of ${CurrencyFormatter.formatNaira(amt)} recorded. Awaiting bank confirmation.',
            ),
          ),
        );
        widget.onDepositRecorded();
      } else {
        setState(() {
          _isSubmitting = false;
          _formError =
              'Could not record this deposit. Please review the entries and retry.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _formError =
              'Could not record this deposit. Please review the entries and retry.';
        });
      }
    } finally {
      if (mounted && _formError.isEmpty) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> bearerOptions = [
      _selectedBearer,
      ...state.staff
          .where((user) =>
              user.isActive &&
              (user.stationId == state.currentStationId ||
                  user.id == state.currentUser.id))
          .map((user) => user.fullName),
    ].toSet().toList();

    return PopScope(
        canPop: !_isSubmitting && (_allowClose || !_hasDraft),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _requestClose();
        },
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
                          child: const Icon(Icons.account_balance,
                              color: AppColors.bank, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hand Over Cash for Bank Deposit',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ink),
                              ),
                              Text(
                                'Station Safe → Commercial Bank Account',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                          onPressed: _requestClose,
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.line),

                    if (_formError.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.badSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bad),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.bad, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formError,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.bad),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Safe Balance Context Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Available Cash in Safe:',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.muted)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            CurrencyFormatter.formatNaira(widget.availableCash),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ok),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick-fill chips
                    const Text('Quick Amount Presets',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.done_all,
                              size: 18, color: AppColors.ok),
                          label: const Text('All Safe Cash'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: AppColors.okSurface,
                            foregroundColor: AppColors.ink,
                            side: const BorderSide(color: AppColors.ok),
                          ),
                          onPressed: widget.availableCash > 0
                              ? () => _setAmount(widget.availableCash)
                              : null,
                        ),
                        if (_lastDepositAmount != null)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.history,
                                size: 18, color: AppColors.bank),
                            label: Text(
                                'Last deposit (${CurrencyFormatter.formatNaira(_lastDepositAmount!)})'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              backgroundColor: AppColors.lightBackground,
                              foregroundColor: AppColors.ink,
                            ),
                            onPressed: () => _setAmount(_lastDepositAmount!),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount Input
                    const Text('Amount to Deposit (₦) *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink),
                      validator: (v) {
                        final amt = double.tryParse((v ?? '').trim()) ?? 0.0;
                        if (amt <= 0)
                          return 'Enter a valid deposit amount greater than ₦0.';
                        return null;
                      },
                      decoration: const InputDecoration(
                        prefixText: '₦ ',
                        hintText: '0',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Target Commercial Bank Account
                    const Text('Target Company Bank Account *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _bankController,
                      decoration: const InputDecoration(
                        labelText: 'Bank and destination account',
                        hintText: 'Enter the actual deposit destination',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter the bank and destination account'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // Depositor / Bearer
                    const Text('Custody Bearer / Depositor *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBearer,
                      isExpanded: true,
                      items: bearerOptions
                          .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(b,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBearer = val);
                      },
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(height: 16),

                    // Stamped Teller Reference Number
                    const Text('Bank Teller / Transaction Ref No. *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _tellerController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the stamped bank teller or reference number.'
                          : null,
                      decoration: const InputDecoration(
                        hintText: 'Actual stamped teller or bank reference',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stamped Teller Slip Photo Attachment
                    const Text('Stamped Bank Teller Photo / Proof *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    EvidencePhotoPicker(
                      title: 'Stamped Bank Teller Slip',
                      photoType: 'bank_teller_slip',
                      stationName: state.currentStationName,
                      staffName: state.currentUser.displayName,
                      bucketName: 'bank-teller-slips',
                      maxPhotos: 1,
                      onPhotosChanged: (photos) {
                        setState(() {
                          _slipPhotos = photos;
                          if (photos.isNotEmpty) _formError = '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Operational Notes
                    const Text('Audit Notes / Memo (Optional)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_isSubmitting
                            ? 'Recording Deposit...'
                            : 'Record deposit'),
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
          ),
        ));
  }
}
