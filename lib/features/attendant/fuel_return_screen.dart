import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/evidence_photo_picker.dart';
import '../../state/station_app_state.dart';

enum NonSaleType { calibrationTest, generatorFuel, companyVehicle }

class FuelReturnScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const FuelReturnScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<FuelReturnScreen> createState() => _FuelReturnScreenState();
}

class _FuelReturnScreenState extends State<FuelReturnScreen> {
  final state = StationAppState.instance;
  NonSaleType _selectedType = NonSaleType.calibrationTest;
  late int _selectedNozzleNumber;
  final TextEditingController _litresController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  List<CompressedImageResult> _evidencePhotos = [];
  bool _evidenceAttached = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedNozzleNumber = state.nozzles.isNotEmpty ? state.nozzles.first.nozzleNumber : 1;
  }

  void _submit() {
    final litres = double.tryParse(_litresController.text.trim()) ?? 0.0;
    if (litres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          content: Text('Please enter valid fuel litres to return.'),
        ),
      );
      return;
    }

    final nozzle = state.nozzles.firstWhere(
      (n) => n.nozzleNumber == _selectedNozzleNumber,
      orElse: () => state.nozzles.first,
    );

    setState(() => _isSubmitting = true);
    try {
      state.recordFuelReturn(
        tankCode: nozzle.tankCode,
        litres: litres,
        reason: _reasonController.text.trim().isEmpty
            ? 'Calibration / non-sale return from Nozzle ${nozzle.nozzleNumber} (${_selectedType.name})'
            : _reasonController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.ok,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Non-sale return of ${CurrencyFormatter.formatLitres(litres)} recorded to Tank ${nozzle.tankCode} (§3.4).',
          ),
        ),
      );
      widget.onSuccess();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _litresController.dispose();
    _reasonController.dispose();
    super.dispose();
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
            Text('Fuel Return / Non-Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Calibration Tests & Generator Diesel (§3.4)', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Record pump test or fuel return',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Prevents calibration returns or internal fuel use from counting as an attendant cash shortage.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Entry Type', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<NonSaleType>(
                          value: _selectedType,
                          items: const [
                            DropdownMenuItem(
                              value: NonSaleType.calibrationTest,
                              child: Text('Pump Calibration / Meter Test Return (Poured back into Tank)'),
                            ),
                            DropdownMenuItem(
                              value: NonSaleType.generatorFuel,
                              child: Text('Station Generator Fuel (AGO Diesel Internal Use)'),
                            ),
                            DropdownMenuItem(
                              value: NonSaleType.companyVehicle,
                              child: Text('Company Operational Vehicle (Pre-approved fuel)'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _selectedType = v!),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Nozzle Used', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    value: _selectedNozzleNumber,
                                    items: state.nozzles.map((n) {
                                      return DropdownMenuItem<int>(
                                        value: n.nozzleNumber,
                                        child: Text('Nozzle ${n.nozzleNumber} · ${n.productName} (Tank ${n.tankCode})'),
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _selectedNozzleNumber = v);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Litres Withdrawn', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _litresController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. 20.0',
                                      suffixText: 'L',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Text('Notes / Authorized Reason', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _reasonController,
                          decoration: const InputDecoration(hintText: 'e.g. 20L check measure can calibration before shift start'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        EvidencePhotoPicker(
                          title: 'Pour-back / Calibration Photo (<150KB)',
                          photoType: 'calibration',
                          stationName: state.currentStationName,
                          staffName: state.currentUser.displayName,
                          bucketName: 'calibration-evidence',
                          maxPhotos: 1,
                          onPhotosChanged: (photos) {
                            setState(() {
                              _evidencePhotos = photos;
                              _evidenceAttached = photos.isNotEmpty;
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
              child: ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                onPressed: _isSubmitting ? null : _submit,
                label: Text(_isSubmitting ? 'Recording Pour-back...' : 'Log non-sale entry'),
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
