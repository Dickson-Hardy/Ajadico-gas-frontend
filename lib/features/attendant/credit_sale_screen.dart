import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/camera_compression_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/evidence_photo_picker.dart';
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

class _CreditSaleScreenState extends State<CreditSaleScreen> {
  final state = StationAppState.instance;

  CreditCustomer? _selectedCustomer;
  int _selectedNozzleNumber = 1;
  final TextEditingController _litresController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();

  List<CompressedImageResult> _requisitionPhotos = [];
  bool _requisitionUploaded = false;
  bool _isSubmitting = false;

  double get _currentPrice {
    if (state.nozzles.isEmpty) return state.pmsPrice;
    final nozzle = state.nozzles.firstWhere(
      (n) => n.nozzleNumber == _selectedNozzleNumber,
      orElse: () => state.nozzles.first,
    );
    return nozzle.pricePerLitre;
  }

  double get _litres => double.tryParse(_litresController.text.trim()) ?? 0.0;
  double get _totalAmount => _litres * _currentPrice;

  @override
  void initState() {
    super.initState();
    if (state.creditCustomers.isNotEmpty) {
      _selectedCustomer = state.creditCustomers.first;
    }
  }

  @override
  void dispose() {
    _litresController.dispose();
    _vehicleController.dispose();
    _driverController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          content: Text('Please select an authorized credit customer'),
        ),
      );
      return;
    }
    if (_litres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          content: Text('Please enter valid fuel litres'),
        ),
      );
      return;
    }
    if (_vehicleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          content: Text('Please enter the vehicle registration plate number'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      state.recordCreditSale(
        customerId: _selectedCustomer!.id,
        nozzleNumber: _selectedNozzleNumber,
        litres: _litres,
        vehiclePlate: _vehicleController.text.trim(),
        driverName: _driverController.text.trim(),
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = state.creditCustomers;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pump Credit Sale Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Authorized Fleet Dispensing (§4.8)', style: const TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Record credit fuel dispensing',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dispensed on signed requisition. Updates the customer ledger balance and ensures attendant shift remittance reconciles without shortage (§4.8).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Authorized Credit Customer', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<CreditCustomer>(
                          value: _selectedCustomer,
                          hint: const Text('Choose customer account'),
                          items: customers.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text('${c.name} (Debt: ${CurrencyFormatter.formatNaira(c.outstanding)})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCustomer = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Dispenser Nozzle', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    value: _selectedNozzleNumber,
                                    items: state.nozzles.map((n) {
                                      return DropdownMenuItem(
                                        value: n.nozzleNumber,
                                        child: Text('Nozzle ${n.nozzleNumber} · ${n.productName} (${CurrencyFormatter.formatNaira(n.pricePerLitre)})'),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() => _selectedNozzleNumber = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Litres Dispensed *', style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _litresController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. 100.0',
                                      suffixText: 'L',
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
                                  const Text('Vehicle Number Plate *', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _vehicleController,
                                    decoration: const InputDecoration(hintText: 'e.g. KSF-821-XA'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Driver Name', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _driverController,
                                    decoration: const InputDecoration(hintText: 'Driver name'),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Live Value Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Credit Value',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
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
                onPressed: _isSubmitting ? null : _submit,
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
