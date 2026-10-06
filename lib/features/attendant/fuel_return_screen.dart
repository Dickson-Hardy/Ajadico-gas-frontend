import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/evidence_photo_picker.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
import '../../state/station_app_state.dart';

enum NonSaleType { calibrationTest, generatorFuel, companyVehicle }

const Map<NonSaleType, String> _nonSaleLabels = {
  NonSaleType.calibrationTest: 'Pump Calibration / Meter Test Return',
  NonSaleType.generatorFuel: 'Station Generator Fuel (AGO Diesel)',
  NonSaleType.companyVehicle: 'Company Operational Vehicle',
};

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

class _FuelReturnScreenState extends State<FuelReturnScreen>
    with UnsavedWorkAware {
  final state = StationAppState.instance;
  NonSaleType _selectedType = NonSaleType.calibrationTest;
  int? _selectedNozzleNumber;
  final TextEditingController _litresController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _evidenceAttached = false;
  bool _isSubmitting = false;
  bool _dirty = false;

  String? _litresError;
  String? _photoError;

  @override
  bool get hasUnsavedWork => _dirty;

  @override
  void initState() {
    super.initState();
    if (state.nozzles.isNotEmpty) {
      _selectedNozzleNumber = state.nozzles.first.nozzleNumber;
    }
    ShellBackGuard.register(this);
  }

  @override
  void dispose() {
    ShellBackGuard.unregister(this);
    _litresController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (!hasUnsavedWork) {
      widget.onBack();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'This fuel return has entries that have not been recorded. Leaving now discards them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onBack();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bad,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  bool _validate() {
    final litres = double.tryParse(_litresController.text.trim()) ?? 0.0;
    setState(() {
      _litresError = litres <= 0 ? 'Enter the litres returned to the tank' : null;
      _photoError = !_evidenceAttached
          ? 'Attach at least one pour-back / calibration photo'
          : null;
    });
    return _litresError == null && _photoError == null;
  }

  void _submit() {
    if (state.nozzles.isEmpty) return;
    if (!_validate()) return;

    final nozzle = state.nozzles.firstWhere(
      (n) => n.nozzleNumber == _selectedNozzleNumber,
      orElse: () => state.nozzles.first,
    );
    final litres = double.tryParse(_litresController.text.trim()) ?? 0.0;
    final friendlyType = _nonSaleLabels[_selectedType] ?? 'Non-sale return';

    setState(() => _isSubmitting = true);
    try {
      state.recordFuelReturn(
        tankCode: nozzle.tankCode,
        litres: litres,
        reason: _reasonController.text.trim().isEmpty
            ? '$friendlyType from Nozzle ${nozzle.nozzleNumber}'
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Could not record the fuel return. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNozzles = state.nozzles.isNotEmpty;

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
            const Text('Fuel Return / Non-Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${state.currentUser.displayName} · Calibration Tests & Generator Diesel (§3.4)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          ForecourtSyncBar(stationName: '${state.currentStationName} · Forecourt'),

          Expanded(
            child: SingleChildScrollView(
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

                      if (!hasNozzles)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: const [
                                  Icon(Icons.local_gas_station_outlined, size: 48, color: AppColors.muted),
                                  SizedBox(height: 12),
                                  Text(
                                    'No active nozzles assigned to this shift',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Please contact your station manager or setup nozzles in Admin settings.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Entry Type', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<NonSaleType>(
                                  initialValue: _selectedType,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: NonSaleType.calibrationTest,
                                      child: Text(
                                        'Pump Calibration / Meter Test Return (Poured back into Tank)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: NonSaleType.generatorFuel,
                                      child: Text(
                                        'Station Generator Fuel (AGO Diesel Internal Use)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: NonSaleType.companyVehicle,
                                      child: Text(
                                        'Company Operational Vehicle (Pre-approved fuel)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedType = v;
                                        _dirty = true;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),

                                const Text('Nozzle Used', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedNozzleNumber,
                                  isExpanded: true,
                                  items: state.nozzles.map((n) {
                                    return DropdownMenuItem<int>(
                                      value: n.nozzleNumber,
                                      child: Text(
                                        'Nozzle ${n.nozzleNumber} · ${n.productName} (Tank ${n.tankCode})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedNozzleNumber = v;
                                        _dirty = true;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),

                                const Text('Litres Withdrawn *', style: TextStyle(fontSize: 14, color: AppColors.ink, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _litresController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 20.0',
                                    suffixText: 'L',
                                    errorText: _litresError,
                                    errorMaxLines: 2,
                                  ),
                                  onChanged: (_) => setState(() {
                                    _litresError = null;
                                    _dirty = true;
                                  }),
                                ),

                                const SizedBox(height: 16),
                                const Text('Notes / Authorized Reason', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _reasonController,
                                  decoration: const InputDecoration(hintText: 'e.g. 20L check measure can calibration before shift start'),
                                  maxLines: 2,
                                  onChanged: (_) => setState(() => _dirty = true),
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
                                      _evidenceAttached = photos.isNotEmpty;
                                      _photoError = null;
                                      _dirty = true;
                                    });
                                  },
                                ),
                                if (_photoError != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _photoError!,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.bad),
                                  ),
                                ],
                                if (_evidenceAttached && _photoError == null) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Evidence photo requirement satisfied.',
                                    style: TextStyle(fontSize: 12, color: AppColors.ok),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
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
                onPressed: (_isSubmitting || !hasNozzles || !_evidenceAttached)
                    ? null
                    : _submit,
                label: Text(_isSubmitting ? 'Recording Pour-back...' : 'Log non-sale entry'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _handleBack,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
