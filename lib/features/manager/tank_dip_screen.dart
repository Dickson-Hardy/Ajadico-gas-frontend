import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/shell_back_guard.dart';
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

class _TankDipScreenState extends State<TankDipScreen> with UnsavedWorkAware {
  final state = StationAppState.instance;
  late List<TankDipItem> _tanks;
  late Map<String, TextEditingController> _controllers;
  final Map<String, String> _fieldErrors = {};
  Map<String, String> _initialValues = {};
  bool _isSubmitting = false;

  @override
  bool get hasUnsavedWork {
    for (final entry in _controllers.entries) {
      if (entry.value.text.trim() != (_initialValues[entry.key] ?? '')) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _initTanks();
    ShellBackGuard.register(this);
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
          text: t.physicalDip?.toStringAsFixed(0) ?? '',
        ),
    };
    _initialValues = {
      for (var t in _tanks) t.code: _controllers[t.code]!.text,
    };
  }

  @override
  void dispose() {
    ShellBackGuard.unregister(this);
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateDip(TankDipItem tank) {
    final raw = _controllers[tank.code]!.text.trim();
    if (raw.isEmpty) return 'Enter the measured physical dip.';
    final parsed = double.tryParse(raw.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid number.';
    if (parsed < 0) return 'Dip cannot be negative.';
    if (parsed > tank.capacity) {
      return 'Exceeds capacity of ${CurrencyFormatter.formatLitres(tank.capacity)}.';
    }
    return null;
  }

  void _onDipChanged(TankDipItem tank, String val) {
    final parsed = double.tryParse(val.replaceAll(',', '').trim());
    setState(() {
      tank.physicalDip = parsed;
      if (parsed == null && val.trim().isEmpty) {
        _fieldErrors.remove(tank.code);
      } else {
        final error = _validateDip(tank);
        if (error == null) {
          _fieldErrors.remove(tank.code);
        } else {
          _fieldErrors[tank.code] = error;
        }
      }
    });
  }

  void _confirmDiscard(VoidCallback onDiscard) {
    if (!hasUnsavedWork) {
      onDiscard();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard dip readings?'),
        content: const Text('This screen still has dip entries that have not been submitted. Leaving now discards them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDiscard();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bad,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final errors = <String, String>{};
    for (var t in _tanks) {
      final error = _validateDip(t);
      if (error != null) errors[t.code] = error;
    }
    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      for (var t in _tanks) {
        state.recordTankDipAudit(
          tankCode: t.code,
          physicalDipLitres: t.physicalDip!,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.bad,
            content: Text('Could not save the tank dip readings. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _confirmDiscard(widget.onBack),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Tank Dip Readings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Underground Storage Tanks (UST) · Physical Audit', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  final entered = tank.physicalDip;
                  final currentLevel = entered ?? tank.calculatedStock;
                  final fieldError = _fieldErrors[tank.code];

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
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: 'e.g. 32,100',
                                        suffixText: 'Litres',
                                        errorText: fieldError,
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
                                      label: entered == null
                                          ? 'Not entered'
                                          : (v == 0
                                              ? 'Balanced'
                                              : '${v >= 0 ? '+' : '−'}${CurrencyFormatter.formatLitres(v.abs())}'),
                                      type: entered == null
                                          ? ChipType.draft
                                          : (v == 0 ? ChipType.ok : (v.abs() > 100 ? ChipType.bad : ChipType.warn)),
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
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmDiscard(widget.onBack),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Save & Submit Dip Audit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
