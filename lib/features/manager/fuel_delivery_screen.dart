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
  List<CompressedImageResult> _waybillPhotos = [];
  bool _isSubmitting = false;

  double get _statedLitres => double.tryParse(_statedLitresController.text.trim()) ?? 0.0;
  double get _dipBefore => double.tryParse(_dipBeforeController.text.trim()) ?? 0.0;
  double get _dipAfter => double.tryParse(_dipAfterController.text.trim()) ?? 0.0;
  double get _receivedLitres => (_dipAfter > _dipBefore) ? (_dipAfter - _dipBefore) : 0.0;
  double get _discrepancy => _receivedLitres - _statedLitres;
  double get _purchasePrice => double.tryParse(_pricePerLitreController.text.trim()) ?? 940.0;

  @override
  void initState() {
    super.initState();
    if (state.tanks.isNotEmpty) {
      _selectedTank = state.tanks.first.code;
      if (state.tanks.first.physicalDip > 0) {
        _dipBeforeController.text = state.tanks.first.physicalDip.toStringAsFixed(0);
      }
    }
    _pricePerLitreController = TextEditingController(
      text: state.pmsPrice > 0 ? (state.pmsPrice * 0.90).toStringAsFixed(0) : '940',
    );
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
    if (_supplierController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please enter the petroleum supplier name.'),
        ),
      );
      return;
    }

    if (_waybillNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please enter the tanker waybill number.'),
        ),
      );
      return;
    }

    if (_statedLitres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please enter stated volume in litres from waybill.'),
        ),
      );
      return;
    }

    if (_receivedLitres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Dip after delivery must be greater than dip before.'),
        ),
      );
      return;
    }

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
            const Text('Record Fuel Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Tanker Discharge Audit (§3.7–§3.9)', style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
                        'Measure physical Before & After tank dip levels to calculate actual delivered volume and identify transit shortage/gain (BRD §3.7–§3.9).',
                        style: TextStyle(fontSize: 13, color: AppColors.slate),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Receiving Tank', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          value: _selectedTank,
                                          items: state.tanks.map((t) {
                                            return DropdownMenuItem(
                                              value: t.code,
                                              child: Text('Tank ${t.code} · ${t.product} (Cap: ${CurrencyFormatter.formatLitres(t.capacity)})'),
                                            );
                                          }).toList(),
                                          onChanged: (v) => setState(() => _selectedTank = v!),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: AppColors.lightBackground,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Supplier Name', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _supplierController,
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
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Waybill Number', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _waybillNumberController,
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
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Stated Litres on Waybill', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _statedLitresController,
                                          keyboardType: TextInputType.number,
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
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Dip BEFORE Discharge (L)', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _dipBeforeController,
                                          keyboardType: TextInputType.number,
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
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Dip AFTER Discharge (L)', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _dipAfterController,
                                          keyboardType: TextInputType.number,
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
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Purchase Price per Litre (₦/L)', style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _pricePerLitreController,
                                    keyboardType: TextInputType.number,
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
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Delivery Audit Summary Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Transit Discrepancy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                        Text(
                                          _discrepancy < 0
                                              ? 'Discharge shortage recorded against depot waybill'
                                              : (_discrepancy > 0 ? 'Surplus volume logged' : 'Exact match with waybill'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _discrepancy < 0 ? AppColors.bad : (_discrepancy > 0 ? AppColors.warn : AppColors.ok),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${_discrepancy >= 0 ? "+" : ""}${_discrepancy.toStringAsFixed(1)} L',
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
                    : const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
              ),
            ),
          ],
        ),
      ),
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
