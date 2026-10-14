import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/evidence_photo_picker.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
import '../../state/station_app_state.dart';
import '../../models/shift_adjustment.dart';

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
  List<CompressedImageResult> _evidencePhotos = [];
  bool _evidenceAttached = false;
  bool _isSubmitting = false;
  bool _dirty = false;

  String? _litresError;
  String? _photoError;
  String? _reasonError;

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
    final litres =
        double.tryParse(_litresController.text.trim().replaceAll(',', '')) ??
            0.0;
    setState(() {
      _litresError = !litres.isFinite || litres <= 0
          ? 'Enter a valid volume greater than zero'
          : null;
      _photoError = !_evidenceAttached
          ? 'Attach evidence of the return or internal fuel use'
          : null;
      _reasonError = _reasonController.text.trim().isEmpty
          ? 'Enter the purpose and authorization reference; include the plate for vehicle fuel.'
          : null;
    });
    return _litresError == null && _photoError == null && _reasonError == null;
  }

  void _submit() {
    if (state.nozzles.isEmpty) return;
    if (!_validate()) return;

    final nozzle = state.nozzles.firstWhere(
      (n) => n.nozzleNumber == _selectedNozzleNumber,
      orElse: () => state.nozzles.first,
    );
    final litres =
        double.tryParse(_litresController.text.trim().replaceAll(',', '')) ??
            0.0;
    final friendlyType = _nonSaleLabels[_selectedType] ?? 'Non-sale return';

    setState(() => _isSubmitting = true);
    try {
      final photoUrls = _evidencePhotos
          .map((p) => p.remoteStorageUrl)
          .whereType<String>()
          .toList();

      state.recordShiftAdjustment(
        kind: switch (_selectedType) {
          NonSaleType.calibrationTest => ShiftAdjustmentKind.calibrationReturn,
          NonSaleType.generatorFuel => ShiftAdjustmentKind.generatorFuel,
          NonSaleType.companyVehicle => ShiftAdjustmentKind.companyVehicle,
        },
        nozzleNumber: nozzle.nozzleNumber,
        litres: litres,
        reason: _reasonController.text.trim().isEmpty
            ? '$friendlyType from ${nozzle.label}'
            : _reasonController.text.trim(),
        evidence: photoUrls,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.ok,
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${CurrencyFormatter.formatLitres(litres)} recorded locally; awaiting approval.',
          ),
        ),
      );
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content:
              const Text('Could not record the fuel return. Please try again.'),
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
            const Text('Fuel Return / Non-Sale',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${state.currentUser.displayName} · Calibration Tests & Generator Diesel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          ForecourtSyncBar(
              stationName: '${state.currentStationName} · Forecourt'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record pump test or fuel return',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Record metered non-sale fuel. Only approved entries reduce your expected sales; calibration returns restore book stock, internal use does not.',
                        style: TextStyle(
                            fontSize: 15,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      if (!hasNozzles)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.local_gas_station_outlined,
                                      size: 48,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No active pumps assigned to this shift',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Please contact your station manager or setup pumps in Admin settings.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 14),
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
                                Text('Entry Type',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<NonSaleType>(
                                  initialValue: _selectedType,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: NonSaleType.calibrationTest,
                                      child: const Text(
                                        'Pump Calibration / Meter Test Return (Poured back into Tank)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: NonSaleType.generatorFuel,
                                      child: const Text(
                                        'Station Generator Fuel (AGO Diesel Internal Use)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: NonSaleType.companyVehicle,
                                      child: const Text(
                                        'Company Operational Vehicle (Requires approval)',
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
                                Text('Pump Used',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedNozzleNumber,
                                  isExpanded: true,
                                  items: state.nozzles.map((n) {
                                    return DropdownMenuItem<int>(
                                      value: n.nozzleNumber,
                                      child: Text(
                                        '${n.label} · ${n.productName} (Tank ${n.tankCode})',
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
                                Text('Litres Withdrawn *',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _litresController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'))
                                  ],
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
                                Text('Notes / Authorized Reason',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _reasonController,
                                  decoration: InputDecoration(
                                      errorText: _reasonError,
                                      errorMaxLines: 3,
                                      hintText:
                                          'e.g. 20L check measure can calibration before shift start'),
                                  maxLines: 2,
                                  onChanged: (_) =>
                                      setState(() => _dirty = true),
                                ),
                                const SizedBox(height: 16),
                                EvidencePhotoPicker(
                                  title: _selectedType ==
                                          NonSaleType.calibrationTest
                                      ? 'Pour-back evidence'
                                      : 'Internal fuel use evidence',
                                  photoType: 'calibration',
                                  stationName: state.currentStationName,
                                  staffName: state.currentUser.displayName,
                                  bucketName: 'calibration-evidence',
                                  maxPhotos: 1,
                                  onPhotosChanged: (photos) {
                                    setState(() {
                                      _evidencePhotos = photos;
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
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.bad),
                                  ),
                                ],
                                if (_evidenceAttached &&
                                    _photoError == null) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Evidence photo requirement satisfied.',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.ok),
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
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
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
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                onPressed: (_isSubmitting || !hasNozzles || !_evidenceAttached)
                    ? null
                    : _submit,
                label: Text(
                    _isSubmitting ? 'Saving entry...' : 'Submit for approval'),
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
