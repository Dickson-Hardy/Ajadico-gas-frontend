import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/evidence_photo_picker.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
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

  final TextEditingController _finalCashController = TextEditingController();
  final TextEditingController _posCardController = TextEditingController();
  final TextEditingController _posTransferController = TextEditingController();
  final TextEditingController _bankTransferController = TextEditingController();

  double get _creditSales => state.totalAttendantCreditSales();
  List<CompressedImageResult> _evidencePhotos = [];
  bool _isSubmitting = false;

  double get _acknowledgedDrops => state.totalAttendantAcknowledgedDrops();
  double get _finalCash => double.tryParse(_finalCashController.text.replaceAll(',', '')) ?? 0.0;
  double get _totalCash => _acknowledgedDrops + _finalCash;

  double get _expectedSalesValue {
    return state.nozzles.fold(0.0, (s, n) => s + n.salesValue);
  }

  double get _posCard => double.tryParse(_posCardController.text.replaceAll(',', '')) ?? 0.0;
  double get _posTransfer => double.tryParse(_posTransferController.text.replaceAll(',', '')) ?? 0.0;
  double get _bankTransfer => double.tryParse(_bankTransferController.text.replaceAll(',', '')) ?? 0.0;

  double get _moneyDeclared => _totalCash + _posCard + _posTransfer + _bankTransfer;
  double get _variance => (_moneyDeclared + _creditSales) - _expectedSalesValue;

  @override
  void initState() {
    super.initState();
    // Auto-prefill non-cash values from in-shift logged transactions if available
    final cardLogged = state.totalAttendantPosCard();
    if (cardLogged > 0) _posCardController.text = cardLogged.toStringAsFixed(0);

    final transferLogged = state.totalAttendantPosTransfer();
    if (transferLogged > 0) _posTransferController.text = transferLogged.toStringAsFixed(0);

    final bankLogged = state.totalAttendantBankTransfer();
    if (bankLogged > 0) _bankTransferController.text = bankLogged.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _finalCashController.dispose();
    _posCardController.dispose();
    _posTransferController.dispose();
    _bankTransferController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_moneyDeclared <= 0 && _creditSales <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please declare your sales cash and non-cash collections.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final photoUrls = _evidencePhotos
          .map((p) => p.remoteStorageUrl ?? p.fileName)
          .toList();

      state.submitRemittance(
        cash: _totalCash,
        posCard: _posCard,
        posTransfer: _posTransfer,
        bankTransfer: _bankTransfer,
        credit: _creditSales,
        evidencePhotos: photoUrls,
        finalCashHandover: _finalCash,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.ok,
          behavior: SnackBarBehavior.floating,
          content: Text('Remittance queued in Offline Engine & sent to Cashier Verification!'),
        ),
      );

      widget.onSubmitSuccess();
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
            const Text('Shift Remittance Declaration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Forecourt Morning Shift', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Live Forecourt Status Bar
          ForecourtSyncBar(stationName: '${state.currentStationName} · Forecourt'),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Declare Sales Collections',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Declare 4 payment channels: Cash, POS card, POS Transfer, and Bank Transfer. Photograph physical merchant slips for every non-cash channel (BRD §4.3).',
                        style: TextStyle(fontSize: 13, color: AppColors.slate),
                      ),
                      const SizedBox(height: 16),

                      // Expected Sales Value Header
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Target Expected Sales', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                  Text('Derived from meter opening vs closing readings', style: TextStyle(fontSize: 11, color: AppColors.mutedSlate)),
                                ],
                              ),
                              Text(
                                CurrencyFormatter.formatNaira(_expectedSalesValue),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Payment Declaration Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payment Declaration Channels (BRD §4.1–§4.3)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                              ),
                              const SizedBox(height: 14),
                              // 1. Physical Sales Cash Section
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.ok.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.ok.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '1. Physical Sales Cash',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink),
                                        ),
                                        Text(
                                          'Total: ${CurrencyFormatter.formatNaira(_totalCash)}',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ok),
                                        ),
                                      ],
                                    ),
                                    if (_acknowledgedDrops > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            '✓ Acknowledged Intra-Shift Drops:',
                                            style: TextStyle(fontSize: 12, color: AppColors.slate),
                                          ),
                                          Text(
                                            CurrencyFormatter.formatNaira(_acknowledgedDrops),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    const SizedBox(height: 4),
                                    _buildInputField(
                                      _acknowledgedDrops > 0
                                          ? 'Final Remaining Cash in Hand Handed Over Now'
                                          : 'Physical Sales Cash Handed Over to Cashier',
                                      _finalCashController,
                                      hint: 'e.g. 50,000',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                '2. POS Card Payments (Terminal merchant slips)',
                                _posCardController,
                                subtitle: state.totalAttendantPosCard() > 0 ? 'Pre-filled from in-shift POS slips' : null,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                '3. Customer Transfer to Station POS Terminal Account',
                                _posTransferController,
                                subtitle: state.totalAttendantPosTransfer() > 0 ? 'Pre-filled from in-shift POS slips' : null,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                '4. Direct Transfer to Company Bank Account',
                                _bankTransferController,
                                subtitle: state.totalAttendantBankTransfer() > 0 ? 'Pre-filled from in-shift bank transfers' : null,
                              ),
                              const SizedBox(height: 20),

                              // High-Efficiency Evidence Photo Picker Pipeline (Phase 3)
                              EvidencePhotoPicker(
                                title: 'POS Slips & Transfer Evidence (<150KB Watermarked)',
                                photoType: 'pos_slip',
                                stationName: state.currentStationName,
                                staffName: state.currentUser.displayName,
                                bucketName: 'remittance-evidence',
                                onPhotosChanged: (photos) {
                                  setState(() {
                                    _evidencePhotos = photos;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Reconciliation Calculation Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _buildSummaryRow('Credit Sales on signed requisitions', CurrencyFormatter.formatNaira(_creditSales)),
                              const Divider(color: AppColors.border),
                              _buildSummaryRow('Total Money Declared (Cash + POS + Bank)', CurrencyFormatter.formatNaira(_moneyDeclared)),
                              const Divider(color: AppColors.border),
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
                                              ? 'Shortfall will feed salary deduction register (§4.6)'
                                              : (_variance > 0 ? 'Excess recorded for management review' : 'Balanced shift account'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _variance < 0 ? AppColors.bad : (_variance > 0 ? AppColors.warn : AppColors.ok),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      CurrencyFormatter.formatVariance(_variance),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
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
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                label: Text(
                  _isSubmitting ? 'Submitting Remittance...' : 'Submit Shift Remittance',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {String? subtitle, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600))),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₦ ',
            hintText: hint,
            filled: true,
            fillColor: AppColors.lightBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
        ],
      ),
    );
  }
}
