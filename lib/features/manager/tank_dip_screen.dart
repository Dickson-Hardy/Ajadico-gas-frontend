import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/forecourt_tank_gauge.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';

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
  final state = StationAppState.instance;
  late List<TankDipItem> _tanks;
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _initTanks();
  }

  void _initTanks() {
    _tanks = state.tanks.map((t) {
      return TankDipItem(
        code: t.code,
        product: t.product,
        capacity: t.capacity,
        calculatedStock: t.bookStock,
        physicalDip: t.physicalDip,
      );
    }).toList();

    _controllers = {
      for (var t in _tanks)
        t.code: TextEditingController(
          text: t.physicalDip != null ? t.physicalDip!.toStringAsFixed(0) : '',
        ),
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
    for (var t in _tanks) {
      final dipVal = t.physicalDip ?? t.calculatedStock;
      state.recordTankDipAudit(
        tankCode: t.code,
        physicalDipLitres: dipVal,
        dipStickCm: 0.0,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.ok,
        content: Text('Daily tank dip readings saved. Real-time variances updated across all manager & director screens.'),
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
            Text('Underground Storage Tanks (UST) · Physical Audit (§3.2, §3.3)', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
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
                  'Record manual dip stick readings to compare measured stock against calculated book stock.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                ..._tanks.map((tank) {
                  final v = tank.variance;
                  final currentLevel = tank.physicalDip ?? tank.calculatedStock;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Graphical Gauge showing dynamic live animation as manager types
                          ForecourtTankGauge(
                            tankCode: tank.code,
                            productName: tank.product,
                            capacityLitres: tank.capacity,
                            currentLitres: currentLevel,
                            calculatedStockLitres: tank.calculatedStock,
                          ),
                          const SizedBox(height: 16),

                          // Dip Input Field & Quick Adjustment
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Enter Measured Physical Dip (Litres):',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _controllers[tank.code],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. 32,100',
                                        suffixText: 'Litres',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onChanged: (val) => _onDipChanged(tank, val),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Audit Status', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 8),
                                    StatusChip(
                                      label: v == 0
                                          ? 'Balanced'
                                          : (v < 0 ? '${CurrencyFormatter.formatLitres(v)}' : '+${CurrencyFormatter.formatLitres(v)}'),
                                      type: v == 0 ? ChipType.ok : (v.abs() > 100 ? ChipType.bad : ChipType.warn),
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
                }),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Save & Submit Dip Audit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
