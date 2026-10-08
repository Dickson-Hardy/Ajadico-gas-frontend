import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
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

class _FuelDeliveryScreenState extends State<FuelDeliveryScreen> {
  final state = StationAppState.instance;

  String _selectedTank = 'T1';
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _waybillNumberController = TextEditingController();
  final TextEditingController _statedLitresController = TextEditingController();
  final TextEditingController _dipBeforeController = TextEditingController();
  final TextEditingController _dipAfterController = TextEditingController();
  late final TextEditingController _pricePerLitreController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<CompressedImageResult> _waybillPhotos = [];
  bool _photoRequiredError = false;
  bool _isSubmitting = false;

  double get _statedLitres => double.tryParse(_statedLitresController.text.trim()) ?? 0.0;
  double get _dipBefore => double.tryParse(_dipBeforeController.text.trim()) ?? 0.0;
  double get _dipAfter => double.tryParse(_dipAfterController.text.trim()) ?? 0.0;
  double get _receivedLitres => (_dipAfter > _dipBefore) ? (_dipAfter - _dipBefore) : 0.0;
  double get _discrepancy => _receivedLitres - _statedLitres;
  double get _purchasePrice => double.tryParse(_pricePerLitreController.text.trim()) ?? 0.0;

  double _retailPriceFor(String product) {
    if (product == 'AGO') return state.agoPrice;
    if (product == 'PMS') return state.pmsPrice;
    return state.pmsPrice;
  }

  String get _selectedTankProduct {
    for (final t in state.tanks) {
      if (t.code == _selectedTank) return t.product;
    }
    return 'PMS';
  }

  double? get _selectedTankDip {
    for (final t in state.tanks) {
      if (t.code == _selectedTank) return t.physicalDip;
    }
    return null;
  }

  void _seedPriceForProduct(String product) {
    final retail = _retailPriceFor(product);
    _pricePerLitreController.text = retail > 0 ? (retail * 0.90).toStringAsFixed(0) : '';
  }

  @override
  void initState() {
    super.initState();
    if (state.tanks.isNotEmpty) {
      _selectedTank = state.tanks.first.code;
      if (state.tanks.first.physicalDip > 0) {
        _dipBeforeController.text = state.tanks.first.physicalDip.toStringAsFixed(0);
      }
    }
    _pricePerLitreController = TextEditingController();
    _seedPriceForProduct(_selectedTankProduct);
  }

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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                'This shortage will be booked against Tank $_selectedTank and flagged for Manager review with the waybill evidence.',
                style: const TextStyle(fontSize: 13, color: AppColors.slate),
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
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.ok,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Fuel delivery of ${CurrencyFormatter.formatLitres(_receivedLitres)} added to Tank $_selectedTank! Queued into Offline Engine & synced.',
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
            content: Text('Could not record this fuel delivery. Please review the entries and retry.'),
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
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Record Fuel Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Tanker Discharge Audit', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Forecourt Sync Bar
          const ForecourtSyncBar(stationName: 'Lekki Road Station · Discharge Gantry'),

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
                        'Tanker Discharge Audit',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Measure physical Before & After tank dip levels to calculate actual delivered volume and identify transit shortage/gain.',
                        style: TextStyle(fontSize: 13, color: AppColors.slate),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _twoUp([
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Receiving Tank', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedTank,
                                      isExpanded: true,
                                      items: state.tanks.map((t) {
                                        return DropdownMenuItem(
                                          value: t.code,
                                          child: Text('Tank ${t.code} · ${t.product} (Cap: ${CurrencyFormatter.formatLitres(t.capacity)})'),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedTank = v ?? _selectedTank;
                                          final dip = _selectedTankDip;
                                          _dipBeforeController.text = (dip != null && dip > 0) ? dip.toStringAsFixed(0) : '';
                                          _seedPriceForProduct(_selectedTankProduct);
                                        });
                                      },
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.lightBackground,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Supplier Name', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _supplierController,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the petroleum supplier name.' : null,
                                      decoration: InputDecoration(
                                        hintText: 'e.g. Matrix Energy',
                                        filled: true,
                                        fillColor: AppColors.lightBackground,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ]),

                              const SizedBox(height: 16),

                              _twoUp([
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Waybill Number', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _waybillNumberController,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the tanker waybill number.' : null,
                                      decoration: InputDecoration(
                                        hintText: 'WB-12345',
                                        filled: true,
                                        fillColor: AppColors.lightBackground,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Stated Litres on Waybill', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _statedLitresController,
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        final val = double.tryParse((v ?? '').trim()) ?? 0.0;
                                        if (val <= 0) return 'Enter stated volume in litres from waybill.';
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        suffixText: 'L',
                                        filled: true,
                                        fillColor: AppColors.lightBackground,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ],
                                ),
                              ]),

                              const SizedBox(height: 16),

                              _twoUp([
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Dip BEFORE Discharge (L)', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _dipBeforeController,
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        final val = double.tryParse((v ?? '').trim());
                                        if (val == null || val < 0) return 'Enter the measured dip before discharge.';
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        suffixText: 'L',
                                        filled: true,
                                        fillColor: AppColors.lightBackground,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Dip AFTER Discharge (L)', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _dipAfterController,
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        final val = double.tryParse((v ?? '').trim());
                                        if (val == null) return 'Enter the measured dip after discharge.';
                                        if (val <= _dipBefore) return 'Dip after must be greater than dip before.';
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        suffixText: 'L',
                                        filled: true,
                                        fillColor: AppColors.lightBackground,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  const Text('Purchase Price per Litre (₦/L)', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _pricePerLitreController,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      final val = double.tryParse((v ?? '').trim());
                                      if (val == null || val <= 0) return 'Enter a purchase price per litre greater than ₦0.';
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      prefixText: '₦ ',
                                      filled: true,
                                      fillColor: AppColors.lightBackground,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Evidence Photo Picker (Phase 3)
                              EvidencePhotoPicker(
                                title: 'Waybill & Calibration Dip Chart Photo (<150KB)',
                                photoType: 'waybill',
                                stationName: 'Lekki Road',
                                staffName: state.currentUser.displayName,
                                bucketName: 'delivery-waybills',
                                onPhotosChanged: (photos) {
                                  setState(() {
                                    _waybillPhotos = photos;
                                    if (photos.isNotEmpty) _photoRequiredError = false;
                                  });
                                },
                              ),
                              if (_photoRequiredError) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Attach the waybill photo before confirming this discharge.',
                                  style: TextStyle(fontSize: 12, color: AppColors.bad),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Discharge Audit Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
                              const SizedBox(height: 12),
                              _buildSummaryRow('Waybill Quantity Stated', CurrencyFormatter.formatLitres(_statedLitres)),
                              const Divider(color: AppColors.border),
                              _buildSummaryRow('Actual Physical Volume Received', CurrencyFormatter.formatLitres(_receivedLitres)),
                              const Divider(color: AppColors.border),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Transit Discrepancy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                          const SizedBox(height: 6),
                                          StatusChip(
                                            label: _discrepancy < 0
                                                ? 'Shortage'
                                                : (_discrepancy > 0 ? 'Surplus' : 'Matched'),
                                            type: _discrepancy < 0
                                                ? ChipType.bad
                                                : (_discrepancy > 0 ? ChipType.warn : ChipType.ok),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _discrepancy < 0
                                                ? 'Discharge shortage recorded against depot waybill'
                                                : (_discrepancy > 0 ? 'Surplus volume logged' : 'Exact match with waybill'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _discrepancy < 0 ? AppColors.bad : (_discrepancy > 0 ? AppColors.warn : AppColors.ok),
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
                                        color: _discrepancy < 0 ? AppColors.bad : (_discrepancy > 0 ? AppColors.warn : AppColors.ok),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(color: AppColors.border),
                              _buildSummaryRow(
                                'Total Delivery Cost Valuation',
                                CurrencyFormatter.formatNaira(_receivedLitres * _purchasePrice),
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
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  label: Text(
                    _isSubmitting ? 'Confirming Discharge...' : 'Confirm Tanker Discharge',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
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
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
