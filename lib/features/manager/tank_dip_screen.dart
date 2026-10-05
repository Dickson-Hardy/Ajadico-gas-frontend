import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';

class TankDipItem {
  final String code;
  final String product;
  final double capacity;
  final double calculatedStock;
  double? physicalDip;

  TankDipItem({
    required this.code,
    required this.product,
    required this.capacity,
    required this.calculatedStock,
    this.physicalDip,
  });

  double get variance {
    if (physicalDip == null) return 0.0;
    return physicalDip! - calculatedStock;
  }
}

class TankDipScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const TankDipScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<TankDipScreen> createState() => _TankDipScreenState();
}

class _TankDipScreenState extends State<TankDipScreen> {
  final List<TankDipItem> _tanks = [
    TankDipItem(code: 'T1', product: 'PMS', capacity: 45000, calculatedStock: 32100, physicalDip: 32100),
    TankDipItem(code: 'T2', product: 'PMS', capacity: 45000, calculatedStock: 28520, physicalDip: 28400),
    TankDipItem(code: 'T3', product: 'AGO', capacity: 33000, calculatedStock: 14200, physicalDip: 14200),
  ];

  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (var t in _tanks)
        t.code: TextEditingController(text: t.physicalDip?.toStringAsFixed(0) ?? '')
    };
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onDipChanged(TankDipItem tank, String val) {
    final parsed = double.tryParse(val.replaceAll(',', '').trim());
    setState(() {
      tank.physicalDip = parsed;
    });
  }

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.ok,
        content: Text('Daily tank dip readings saved. Stock variance updated in manager dashboard.'),
      ),
    );
    widget.onSuccess();
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
            Text('Daily Tank Dip Readings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Stock Audit & Dip Variance (§3.2, §3.3)', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  'Underground tank dip readings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Physical dip measurement compared with calculated meter/delivery book stock.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                ..._tanks.map((tank) {
                  final v = tank.variance;
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
                                'Tank ${tank.code} · ${tank.product}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              StatusChip(
                                label: v == 0
                                    ? 'Balanced'
                                    : (v < 0 ? '${CurrencyFormatter.formatLitres(v)}' : '+${CurrencyFormatter.formatLitres(v)}'),
                                type: v == 0 ? ChipType.ok : (v.abs() > 100 ? ChipType.bad : ChipType.warn),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Capacity', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    Text(
                                      CurrencyFormatter.formatLitres(tank.capacity),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Calculated Stock', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    Text(
                                      CurrencyFormatter.formatLitres(tank.calculatedStock),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Physical Dip (L)', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _controllers[tank.code],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter litres',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      onChanged: (val) => _onDipChanged(tank, val),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
                child: const Text('Save tank dip records'),
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
