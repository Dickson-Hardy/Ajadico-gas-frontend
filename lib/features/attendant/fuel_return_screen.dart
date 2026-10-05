import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

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
  NonSaleType _selectedType = NonSaleType.calibrationTest;
  int _selectedNozzleNumber = 1;
  final TextEditingController _litresController = TextEditingController(text: '20.0');
  final TextEditingController _reasonController = TextEditingController();
  bool _evidenceAttached = false;

  void _submit() {
    final litres = double.tryParse(_litresController.text.trim()) ?? 0.0;
    if (litres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid litres')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        content: Text(
          'Non-sale entry of ${CurrencyFormatter.formatLitres(litres)} submitted for manager approval (§3.4).',
        ),
      ),
    );
    widget.onSuccess();
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
                                    items: const [
                                      DropdownMenuItem(value: 1, child: Text('Nozzle 1 · PMS')),
                                      DropdownMenuItem(value: 2, child: Text('Nozzle 2 · PMS')),
                                      DropdownMenuItem(value: 3, child: Text('Nozzle 3 · AGO')),
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
                                  const Text('Litres Withdrawn', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _litresController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(suffixText: 'L'),
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

                        InkWell(
                          onTap: () => setState(() => _evidenceAttached = !_evidenceAttached),
                          child: Container(
                            height: 90,
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
                                    _evidenceAttached ? Icons.check_circle : Icons.camera_alt,
                                    color: _evidenceAttached ? AppColors.ok : AppColors.muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _evidenceAttached
                                        ? 'Pour-back / Calibration Photo Attached'
                                        : 'Tap to add calibration measure photo (§3.4)',
                                    style: TextStyle(
                                      color: _evidenceAttached ? AppColors.ok : AppColors.muted,
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
                child: const Text('Log non-sale entry'),
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
