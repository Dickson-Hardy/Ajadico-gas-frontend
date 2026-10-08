import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/evidence_photo_picker.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
import '../../models/credit_customer.dart';
import '../../state/station_app_state.dart';

class CreditSaleScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const CreditSaleScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<CreditSaleScreen> createState() => _CreditSaleScreenState();
}

class _CreditSaleScreenState extends State<CreditSaleScreen>
    with UnsavedWorkAware {
  final state = StationAppState.instance;

  CreditCustomer? _selectedCustomer;
  int? _selectedNozzleNumber;
  final TextEditingController _litresController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();

  List<CompressedImageResult> _requisitionPhotos = [];
  bool _requisitionUploaded = false;
  bool _isSubmitting = false;
  bool _dirty = false;

  String? _customerError;
  String? _litresError;
  String? _vehicleError;
  String? _photoError;

  double get _currentPrice {
    if (state.nozzles.isEmpty) return state.pmsPrice;
    for (final n in state.nozzles) {
      if (n.nozzleNumber == _selectedNozzleNumber) return n.pricePerLitre;
    }
    return state.nozzles.first.pricePerLitre;
  }

  double get _litres => double.tryParse(_litresController.text.trim()) ?? 0.0;
  double get _totalAmount => _litres * _currentPrice;

  String get _selectedNozzleLabel {
    for (final n in state.nozzles) {
      if (n.nozzleNumber == _selectedNozzleNumber) {
        return 'Nozzle ${n.nozzleNumber} · ${n.productName} (Tank ${n.tankCode})';
      }
    }
    return '—';
  }

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
    _vehicleController.dispose();
    _driverController.dispose();
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
          'This credit sale has entries that have not been recorded. Leaving now discards them.',
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
    setState(() {
      _customerError = _selectedCustomer == null
          ? 'Select an authorized credit customer'
          : null;
      _litresError =
          _litres <= 0 ? 'Enter the litres dispensed on the requisition' : null;
      _vehicleError = _vehicleController.text.trim().isEmpty
          ? 'Enter the vehicle registration plate number'
          : null;
      _photoError =
          !_requisitionUploaded ? 'Attach the signed requisition slip photo' : null;
    });
    return _customerError == null &&
        _litresError == null &&
        _vehicleError == null &&
        _photoError == null;
  }

  void _showConfirmation() {
    final customer = _selectedCustomer!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record credit sale?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This debits ${customer.name}\'s ledger and counts toward your shift remittance.',
              style: const TextStyle(fontSize: 14, color: AppColors.slate),
            ),
            const SizedBox(height: 12),
            _buildSummaryLine('Customer', customer.name),
            _buildSummaryLine('Nozzle', _selectedNozzleLabel),
            _buildSummaryLine('Litres', CurrencyFormatter.formatLitres(_litres)),
            _buildSummaryLine('Total', CurrencyFormatter.formatNaira(_totalAmount)),
            _buildSummaryLine('Vehicle plate', _vehicleController.text.trim()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm & debit customer'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_validate()) return;
    if (state.nozzles.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final photoUrls = _requisitionPhotos
          .map((p) => p.remoteStorageUrl)
          .whereType<String>()
          .toList();

      state.recordCreditSale(
        customerId: _selectedCustomer!.id,
        nozzleNumber: _selectedNozzleNumber!,
        litres: _litres,
        vehiclePlate: _vehicleController.text.trim(),
        driverName: _driverController.text.trim(),
        evidencePhotos: photoUrls,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.ok,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Credit sale of ${CurrencyFormatter.formatNaira(_totalAmount)} logged for ${_selectedCustomer!.name}!',
          ),
        ),
      );

      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Could not record the credit sale. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = state.creditCustomers;
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
            const Text('Pump Credit Sale Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${state.currentUser.displayName} · Authorized Fleet Dispensing',
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
                        'Record credit fuel dispensing',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dispensed on signed requisition. Updates the customer ledger balance and ensures attendant shift remittance reconciles without shortage.',
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
                                const Text('Authorized Credit Customer *', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<CreditCustomer>(
                                  initialValue: _selectedCustomer,
                                  isExpanded: true,
                                  hint: const Text('Select customer'),
                                  items: customers.map((c) {
                                    return DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        '${c.name} (Debt: ${CurrencyFormatter.formatNaira(c.outstanding)})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedCustomer = val;
                                      _customerError = null;
                                      _dirty = true;
                                    });
                                  },
                                ),
                                if (_customerError != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _customerError!,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.bad),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                const Text('Dispenser Nozzle', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedNozzleNumber,
                                  isExpanded: true,
                                  items: state.nozzles.map((n) {
                                    return DropdownMenuItem(
                                      value: n.nozzleNumber,
                                      child: Text(
                                        'Nozzle ${n.nozzleNumber} · ${n.productName} (${CurrencyFormatter.formatNaira(n.pricePerLitre)})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() {
                                    _selectedNozzleNumber = v;
                                    _dirty = true;
                                  }),
                                ),
                                const SizedBox(height: 16),

                                const Text('Litres Dispensed *', style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _litresController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 100.0',
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

                                const Text('Vehicle Number Plate *', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _vehicleController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. KSF-821-XA',
                                    errorText: _vehicleError,
                                  ),
                                  onChanged: (_) => setState(() {
                                    _vehicleError = null;
                                    _dirty = true;
                                  }),
                                ),
                                const SizedBox(height: 16),

                                const Text('Driver Name', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _driverController,
                                  decoration: const InputDecoration(hintText: 'Driver name'),
                                  onChanged: (_) => setState(() => _dirty = true),
                                ),

                                const SizedBox(height: 16),

                                EvidencePhotoPicker(
                                  title: 'Signed Customer Requisition Slip (<150KB)',
                                  photoType: 'requisition',
                                  stationName: state.currentStationName,
                                  staffName: state.currentUser.displayName,
                                  bucketName: 'credit-requisitions',
                                  maxPhotos: 1,
                                  onPhotosChanged: (photos) {
                                    setState(() {
                                      _requisitionPhotos = photos;
                                      _requisitionUploaded = photos.isNotEmpty;
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
                                if (!_requisitionUploaded && _photoError == null) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'The signed requisition photo is required before this sale can be recorded.',
                                    style: TextStyle(fontSize: 12, color: AppColors.warnInk),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      if (hasNozzles)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total Credit Value',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  CurrencyFormatter.formatNaira(_totalAmount),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ink,
                                  ),
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
                    : const Icon(Icons.check),
                onPressed: (_isSubmitting || !hasNozzles || !_requisitionUploaded)
                    ? null
                    : _showConfirmation,
                label: Text(
                  _isSubmitting
                      ? 'Logging Credit Dispensing...'
                      : 'Confirm credit sale & debit customer',
                ),
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
