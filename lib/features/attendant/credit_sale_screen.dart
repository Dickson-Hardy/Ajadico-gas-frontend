import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/credit_customer.dart';
import '../../models/nozzle.dart';

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
  CreditCustomer? _selectedCustomer;
  int _selectedNozzleNumber = 1;
  final TextEditingController _litresController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();

  final double _pmsPrice = 1050.0;
  final double _agoPrice = 1320.0;
  bool _requisitionUploaded = false;

  double get _currentPrice => _selectedNozzleNumber == 3 ? _agoPrice : _pmsPrice;
  double get _litres => double.tryParse(_litresController.text.trim()) ?? 0.0;
  double get _totalAmount => _litres * _currentPrice;

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
        const SnackBar(content: Text('Please select a registered credit customer')),
      );
      return;
    }
    if (_litres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid fuel litres')),
      );
      return;
    }
    if (_vehicleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the vehicle registration number')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        content: Text(
          'Credit sale of ${CurrencyFormatter.formatNaira(_totalAmount)} logged for ${_selectedCustomer!.name}.',
        ),
      ),
    );
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final customers = CreditCustomer.getDemoCustomers();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Credit Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Attendant Entry · Pump Island', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Record credit fuel sale',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dispensed on signed requisition. Updates customer debt and attendant shift reconciliation.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select registered customer',
                          style: TextStyle(fontSize: 14, color: AppColors.muted),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<CreditCustomer>(
                          value: _selectedCustomer,
                          hint: const Text('Choose authorized account'),
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
                                  const Text('Dispensing Nozzle', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    value: _selectedNozzleNumber,
                                    items: const [
                                      DropdownMenuItem(value: 1, child: Text('Nozzle 1 · PMS (₦1050)')),
                                      DropdownMenuItem(value: 2, child: Text('Nozzle 2 · PMS (₦1050)')),
                                      DropdownMenuItem(value: 3, child: Text('Nozzle 3 · AGO (₦1320)')),
                                    ],
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
                                  const Text('Litres Dispensed', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _litresController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. 50.0',
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
                                  const Text('Vehicle Number', style: TextStyle(fontSize: 14, color: AppColors.muted)),
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
                                  const Text('Driver Name', style: TextStyle(fontSize: 14, color: AppColors.muted)),
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

                        // Requisition Photo Upload
                        InkWell(
                          onTap: () {
                            setState(() => _requisitionUploaded = !_requisitionUploaded);
                          },
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _requisitionUploaded ? Icons.check_circle : Icons.camera_alt,
                                    color: _requisitionUploaded ? AppColors.ok : AppColors.muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _requisitionUploaded
                                        ? 'Signed Requisition Document Attached'
                                        : 'Tap to photograph signed customer requisition',
                                    style: TextStyle(
                                      color: _requisitionUploaded ? AppColors.ok : AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Live Value Summary Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Credit Value',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
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
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Confirm credit sale'),
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
