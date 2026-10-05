import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/nozzle.dart';
import '../../state/station_app_state.dart';

class ClosingReadingsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSubmitSuccess;

  const ClosingReadingsScreen({
    super.key,
    required this.onBack,
    required this.onSubmitSuccess,
  });

  @override
  State<ClosingReadingsScreen> createState() => _ClosingReadingsScreenState();
}

class _ClosingReadingsScreenState extends State<ClosingReadingsScreen> {
  final state = StationAppState.instance;
  late List<NozzleItem> _nozzles;
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _nozzles = state.nozzles;
    for (var n in _nozzles) {
      _controllers[n.nozzleNumber] = TextEditingController(
        text: n.closingReading?.toStringAsFixed(1) ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalExpectedSales {
    return _nozzles.fold(0.0, (sum, item) => sum + item.salesValue);
  }

  void _onClosingChanged(NozzleItem nozzle, String val) {
    final cleaned = val.replaceAll(',', '').trim();
    if (cleaned.isEmpty) {
      setState(() {
        nozzle.closingReading = null;
        _errors[nozzle.nozzleNumber] = null;
      });
      return;
    }

    final parsed = double.tryParse(cleaned);
    setState(() {
      if (parsed == null) {
        _errors[nozzle.nozzleNumber] = 'Invalid decimal number';
        nozzle.closingReading = null;
      } else if (parsed < nozzle.openingReading) {
        _errors[nozzle.nozzleNumber] = 'Closing reading cannot be less than opening (${CurrencyFormatter.formatLitres(nozzle.openingReading)})';
        nozzle.closingReading = null;
      } else {
        _errors[nozzle.nozzleNumber] = null;
        nozzle.closingReading = parsed;
      }
    });
  }

  void _quickFillDemo() {
    setState(() {
      _nozzles[0].closingReading = 413102.0; // 721.5 L
      _controllers[1]!.text = '413102.0';
      _errors[1] = null;

      _nozzles[1].closingReading = 388410.0; // 308.0 L
      _controllers[2]!.text = '388410.0';
      _errors[2] = null;

      _nozzles[2].closingReading = 201903.5; // 128.0 L
      _controllers[3]!.text = '201903.5';
      _errors[3] = null;
    });
  }

  void _submit() {
    bool hasError = false;
    final Map<int, double> readings = {};

    for (var n in _nozzles) {
      if (n.closingReading == null || n.closingReading! < n.openingReading) {
        _errors[n.nozzleNumber] = 'Please enter valid closing dial';
        hasError = true;
      } else {
        readings[n.nozzleNumber] = n.closingReading!;
      }
    }

    if (hasError) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please correct meter reading errors before submitting.'),
        ),
      );
      return;
    }

    state.recordClosingReadings(readings);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Closing readings submitted! Expected sales: ${CurrencyFormatter.formatNaira(_totalExpectedSales)}',
        ),
      ),
    );

    widget.onSubmitSuccess();
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
            const Text('Closing Meter Readings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Morning shift', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.auto_fix_high, color: Colors.white, size: 16),
            label: const Text('Fill Demo Values', style: TextStyle(color: Colors.white, fontSize: 13)),
            onPressed: _quickFillDemo,
          ),
        ],
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
                  'Record closing pump meter dials',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Type the mechanical dial on each dispenser nozzle. Litres and sales value calculate dynamically.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // Nozzle Input Cards
                ..._nozzles.map((nozzle) {
                  final err = _errors[nozzle.nozzleNumber];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nozzle ${nozzle.nozzleNumber} · ${nozzle.productName}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.ink.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Tank ${nozzle.tankCode} · ${CurrencyFormatter.formatNaira(nozzle.pricePerLitre)}/L',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Opening Dial (L)', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      initialValue: nozzle.openingReading.toStringAsFixed(1),
                                      readOnly: true,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Closing Dial (L) *', style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _controllers[nozzle.nozzleNumber],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. ${(nozzle.openingReading + 500).toStringAsFixed(1)}',
                                        errorText: err,
                                        errorMaxLines: 2,
                                        suffixText: 'L',
                                      ),
                                      onChanged: (val) => _onClosingChanged(nozzle, val),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    text: 'Litres sold: ',
                                    style: const TextStyle(fontSize: 14, color: AppColors.muted),
                                    children: [
                                      TextSpan(
                                        text: CurrencyFormatter.formatLitres(nozzle.litresSold),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatNaira(nozzle.salesValue),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ok,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                // Total Summary Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Expected Sales Value',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                            Text('Carried to remittance declaration', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(_totalExpectedSales),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ok,
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
                icon: const Icon(Icons.check_circle_outline),
                onPressed: _submit,
                label: const Text('Save dials & proceed to remittance'),
              ),
            ),
            const SizedBox(width: 12),
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
