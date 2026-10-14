import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/evidence_photo_picker.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';

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

class _FuelDeliveryScreenState extends State<FuelDeliveryScreen>
    with UnsavedWorkAware {
  final state = StationAppState.instance;

  String _selectedTank = '';
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _waybillNumberController =
      TextEditingController();
  final TextEditingController _statedLitresController = TextEditingController();
  final TextEditingController _dipBeforeController = TextEditingController();
  final TextEditingController _dipAfterController = TextEditingController();
  late final TextEditingController _pricePerLitreController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<CompressedImageResult> _waybillPhotos = [];
  bool _photoRequiredError = false;
  bool _isSubmitting = false;
  String _initialDipBefore = '';

  double get _statedLitres =>
      double.tryParse(_statedLitresController.text.trim()) ?? 0.0;
  double get _dipBefore =>
      double.tryParse(_dipBeforeController.text.trim()) ?? 0.0;
  double get _dipAfter =>
      double.tryParse(_dipAfterController.text.trim()) ?? 0.0;
  double get _receivedLitres =>
      (_dipAfter > _dipBefore) ? (_dipAfter - _dipBefore) : 0.0;
  double get _discrepancy => _receivedLitres - _statedLitres;
  double get _purchasePrice =>
      double.tryParse(_pricePerLitreController.text.trim()) ?? 0.0;

  double? get _selectedTankDip {
    for (final t in state.tanks) {
      if (t.code == _selectedTank) return t.physicalDip;
    }
    return null;
  }

  @override
  bool get hasUnsavedWork =>
      _supplierController.text.trim().isNotEmpty ||
      _waybillNumberController.text.trim().isNotEmpty ||
      _statedLitresController.text.trim().isNotEmpty ||
      _dipBeforeController.text != _initialDipBefore ||
      _dipAfterController.text.trim().isNotEmpty ||
      _pricePerLitreController.text.trim().isNotEmpty ||
      _waybillPhotos.isNotEmpty;

  Future<void> _handleBack() async {
    if (_isSubmitting) return;
    if (hasUnsavedWork) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Discard fuel delivery?'),
                  content: const Text(
                      'This delivery has not been saved. Leaving discards the draft.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep editing')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Discard')),
                  ]));
      if (discard != true || !mounted) return;
    }
    widget.onBack();
  }

  @override
  void initState() {
    super.initState();
    if (state.tanks.isNotEmpty) {
      _selectedTank = state.tanks.first.code;
      if (state.tanks.first.physicalDip > 0) {
        _dipBeforeController.text =
            state.tanks.first.physicalDip.toStringAsFixed(0);
      }
    }
    _pricePerLitreController = TextEditingController();
    _initialDipBefore = _dipBeforeController.text;
    ShellBackGuard.register(this);
  }

  @override
  void dispose() {
    ShellBackGuard.unregister(this);
    _supplierController.dispose();
    _waybillNumberController.dispose();
    _statedLitresController.dispose();
    _dipBeforeController.dispose();
    _dipAfterController.dispose();
    _pricePerLitreController.dispose();
    super.dispose();
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() ?? false;
    final photoMissing = _waybillPhotos.isEmpty;
    setState(() => _photoRequiredError = photoMissing);
    if (!formValid || photoMissing) return;

    if (_discrepancy < 0) {
      _confirmShortage();
      return;
    }
    _recordDelivery();
  }

  void _confirmShortage() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm transit shortage'),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warnSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warn),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Received volume is ${CurrencyFormatter.formatLitres(_discrepancy.abs())} below the waybill figure of ${CurrencyFormatter.formatLitres(_statedLitres)}.',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'This shortage will be booked against Tank $_selectedTank and flagged for Manager review with the waybill evidence.',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _recordDelivery();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bad,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Record Shortage'),
          ),
        ],
      ),
    );
  }

  void _recordDelivery() {
    setState(() => _isSubmitting = true);
    try {
      state.recordFuelDelivery(
        tankCode: _selectedTank,
        supplier: _supplierController.text.trim(),
        waybillNumber: _waybillNumberController.text.trim(),
        statedLitres: _statedLitres,
        dipBefore: _dipBefore,
        dipAfter: _dipAfter,
        purchasePrice: _purchasePrice,
        waybillReferences: _waybillPhotos
            .map((photo) => photo.remoteStorageUrl)
            .whereType<String>()
            .toList(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.ok,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Delivery of ${CurrencyFormatter.formatLitres(_receivedLitres)} recorded for Tank $_selectedTank. Check the sync indicator for upload status.',
          ),
        ),
      );

      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.bad,
            behavior: SnackBarBehavior.floating,
            content: const Text(
                'Could not record this fuel delivery. Please review the entries and retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _twoUp(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [children[0], const SizedBox(height: 16), children[1]],
          );
        }
        return Row(
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 12),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _handleBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Record Fuel Delivery',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Tanker Discharge Audit',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Forecourt Sync Bar
          ForecourtSyncBar(stationName: state.currentStationName),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tanker Discharge Audit',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Measure physical Before & After tank dip levels to calculate actual delivered volume and identify transit shortage/gain.',
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _twoUp([
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Receiving Tank',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedTank.isEmpty
                                            ? null
                                            : _selectedTank,
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                                ? 'Configure and select a tank'
                                                : null,
                                        isExpanded: true,
                                        items: state.tanks.map((t) {
                                          return DropdownMenuItem(
                                            value: t.code,
                                            child: Text(
                                                'Tank ${t.code} · ${t.product} (Cap: ${CurrencyFormatter.formatLitres(t.capacity)})'),
                                          );
                                        }).toList(),
                                        onChanged: (v) {
                                          setState(() {
                                            _selectedTank = v ?? _selectedTank;
                                            final dip = _selectedTankDip;
                                            _dipBeforeController.text =
                                                (dip != null && dip > 0)
                                                    ? dip.toStringAsFixed(0)
                                                    : '';
                                            _initialDipBefore =
                                                _dipBeforeController.text;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Supplier Name',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _supplierController,
                                        validator: (v) => (v == null ||
                                                v.trim().isEmpty)
                                            ? 'Enter the petroleum supplier name.'
                                            : null,
                                        decoration: InputDecoration(
                                          hintText: 'Supplier company name',
                                          filled: true,
                                          fillColor: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ]),

                                const SizedBox(height: 16),

                                _twoUp([
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Waybill Number',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _waybillNumberController,
                                        validator: (v) => (v == null ||
                                                v.trim().isEmpty)
                                            ? 'Enter the tanker waybill number.'
                                            : null,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Supplier waybill reference',
                                          filled: true,
                                          fillColor: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Stated Litres on Waybill',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _statedLitresController,
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          final val = double.tryParse(
                                                  (v ?? '').trim()) ??
                                              0.0;
                                          if (val <= 0)
                                            return 'Enter stated volume in litres from waybill.';
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          suffixText: 'L',
                                          filled: true,
                                          fillColor: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ]),

                                const SizedBox(height: 16),

                                _twoUp([
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Dip BEFORE Discharge (L)',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _dipBeforeController,
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          final val =
                                              double.tryParse((v ?? '').trim());
                                          if (val == null || val < 0)
                                            return 'Enter the measured dip before discharge.';
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          suffixText: 'L',
                                          filled: true,
                                          fillColor: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Dip AFTER Discharge (L)',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _dipAfterController,
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          final val =
                                              double.tryParse((v ?? '').trim());
                                          if (val == null)
                                            return 'Enter the measured dip after discharge.';
                                          if (val <= _dipBefore)
                                            return 'Dip after must be greater than dip before.';
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          suffixText: 'L',
                                          filled: true,
                                          fillColor: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ]),

                                const SizedBox(height: 16),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Purchase Price per Litre (₦/L)',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _pricePerLitreController,
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        final val =
                                            double.tryParse((v ?? '').trim());
                                        if (val == null || val <= 0)
                                          return 'Enter a purchase price per litre greater than ₦0.';
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        prefixText: '₦ ',
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLow,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Evidence Photo Picker (Phase 3)
                                EvidencePhotoPicker(
                                  title:
                                      'Waybill & Calibration Dip Chart Photo',
                                  photoType: 'waybill',
                                  stationName: state.currentStationName,
                                  staffName: state.currentUser.displayName,
                                  bucketName: 'delivery-waybills',
                                  onPhotosChanged: (photos) {
                                    setState(() {
                                      _waybillPhotos = photos;
                                      if (photos.isNotEmpty)
                                        _photoRequiredError = false;
                                    });
                                  },
                                ),
                                if (_photoRequiredError) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Attach the waybill photo before confirming this discharge.',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.bad),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Delivery Audit Summary Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Discharge Audit Summary',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface)),
                              const SizedBox(height: 12),
                              _buildSummaryRow(
                                  'Waybill Quantity Stated',
                                  CurrencyFormatter.formatLitres(
                                      _statedLitres)),
                              Divider(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                              _buildSummaryRow(
                                  'Actual Physical Volume Received',
                                  CurrencyFormatter.formatLitres(
                                      _receivedLitres)),
                              Divider(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Transit Discrepancy',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface)),
                                          const SizedBox(height: 6),
                                          StatusChip(
                                            label: _statedLitres <= 0 ||
                                                    _dipAfterController.text
                                                        .trim()
                                                        .isEmpty
                                                ? 'Awaiting measurements'
                                                : _discrepancy < 0
                                                    ? 'Shortage'
                                                    : (_discrepancy > 0
                                                        ? 'Surplus'
                                                        : 'Matched'),
                                            type: _statedLitres <= 0 ||
                                                    _dipAfterController.text
                                                        .trim()
                                                        .isEmpty
                                                ? ChipType.draft
                                                : _discrepancy < 0
                                                    ? ChipType.bad
                                                    : (_discrepancy > 0
                                                        ? ChipType.warn
                                                        : ChipType.ok),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _statedLitres <= 0 ||
                                                    _dipAfterController.text
                                                        .trim()
                                                        .isEmpty
                                                ? 'Enter waybill and dip measurements to compare volumes.'
                                                : _discrepancy < 0
                                                    ? 'Discharge shortage recorded against depot waybill'
                                                    : (_discrepancy > 0
                                                        ? 'Surplus volume logged'
                                                        : 'Exact match with waybill'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _discrepancy < 0
                                                  ? AppColors.bad
                                                  : (_discrepancy > 0
                                                      ? AppColors.warn
                                                      : AppColors.ok),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${_discrepancy >= 0 ? '+' : '−'}${CurrencyFormatter.formatLitres(_discrepancy.abs())}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: _discrepancy < 0
                                            ? AppColors.bad
                                            : (_discrepancy > 0
                                                ? AppColors.warn
                                                : AppColors.ok),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                              _buildSummaryRow(
                                'Total Delivery Cost Valuation',
                                CurrencyFormatter.formatNaira(
                                    _receivedLitres * _purchasePrice),
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
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 18),
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  label: Text(
                    _isSubmitting
                        ? 'Confirming Discharge...'
                        : 'Confirm Tanker Discharge',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Back to Dashboard',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
