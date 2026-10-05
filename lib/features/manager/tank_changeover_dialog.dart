import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../state/station_app_state.dart';

/// Modal dialog for recording an Interlocked Manifold Tank Switchover (BRD §3.1, §7)
/// Accessible by: Branch Manager & Director / Central Admin
class TankChangeoverDialog extends StatefulWidget {
  final StationAppState state;

  const TankChangeoverDialog({
    super.key,
    required this.state,
  });

  static Future<bool?> show(BuildContext context, StationAppState state) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TankChangeoverDialog(state: state),
    );
  }

  @override
  State<TankChangeoverDialog> createState() => _TankChangeoverDialogState();
}

class _TankChangeoverDialogState extends State<TankChangeoverDialog> {
  String _selectedProduct = 'PMS';
  String? _fromTank;
  String? _toTank;

  final Map<int, TextEditingController> _meterControllers = {};
  final TextEditingController _fromTankDipController = TextEditingController();
  final TextEditingController _toTankDipController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initSelection();
  }

  void _initSelection() {
    // Find interlocked tanks for PMS
    final interlocked = widget.state.tanks.where((t) => t.isInterlocked && t.product == _selectedProduct).toList();
    if (interlocked.length >= 2) {
      final active = interlocked.firstWhere((t) => t.isActiveSupply, orElse: () => interlocked[0]);
      final standby = interlocked.firstWhere((t) => !t.isActiveSupply, orElse: () => interlocked[1]);
      _fromTank = active.code;
      _toTank = standby.code;
    } else if (interlocked.isNotEmpty) {
      _fromTank = interlocked[0].code;
      _toTank = interlocked[0].code;
    }

    _fromTankDipController.text = (widget.state.tanks.firstWhere((t) => t.code == _fromTank, orElse: () => widget.state.tanks[0]).physicalDip).toStringAsFixed(0);
    _toTankDipController.text = (widget.state.tanks.firstWhere((t) => t.code == _toTank, orElse: () => widget.state.tanks[0]).physicalDip).toStringAsFixed(0);

    // Initialize meter controllers for affected nozzles
    final affected = widget.state.nozzles.where((n) => n.productName == _selectedProduct && n.tankCode == _fromTank).toList();
    for (final n in affected) {
      _meterControllers[n.nozzleNumber] = TextEditingController(text: n.openingReading.toStringAsFixed(1));
    }
  }

  @override
  void dispose() {
    for (final c in _meterControllers.values) {
      c.dispose();
    }
    _fromTankDipController.dispose();
    _toTankDipController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_fromTank == null || _toTank == null || _fromTank == _toTank) {
      setState(() => _errorMessage = 'Please select two different twin tanks for changeover.');
      return;
    }

    final affected = widget.state.nozzles.where((n) => n.productName == _selectedProduct && n.tankCode == _fromTank).toList();
    final Map<String, double> switchReadings = {};

    for (final n in affected) {
      final text = _meterControllers[n.nozzleNumber]?.text.trim() ?? '';
      final reading = double.tryParse(text);
      if (reading == null || reading < n.openingReading) {
        setState(() => _errorMessage = 'Nozzle ${n.nozzleNumber} meter reading cannot be less than opening (${n.openingReading.toStringAsFixed(1)} L).');
        return;
      }
      switchReadings['Nozzle ${n.nozzleNumber}'] = reading;
    }

    final fromDip = double.tryParse(_fromTankDipController.text.trim());
    final toDip = double.tryParse(_toTankDipController.text.trim());

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await widget.state.executeTankChangeover(
      productCode: _selectedProduct,
      fromTankCode: _fromTank!,
      toTankCode: _toTank!,
      switchReadings: switchReadings,
      fromTankDip: fromDip,
      toTankDip: toDip,
      notes: _notesController.text.trim().isEmpty ? 'Operational manifold switchover' : _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.ok,
            content: Text('Manifold Changeover Applied: Nozzles now drawing from Tank $_toTank.'),
          ),
        );
      } else {
        setState(() => _errorMessage = 'Failed to record changeover in remote database. Changes applied locally.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final affected = widget.state.nozzles.where((n) => n.productName == _selectedProduct && n.tankCode == _fromTank).toList();
    final mediaQuery = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: mediaQuery.viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.alt_route, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manifold Tank Changeover',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                          ),
                          Text(
                            'BRD §3.1 & §7 • Interlocked UST Operation',
                            style: TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.lightCherry,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cherry),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.cherry, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.cherry, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Product & Manifold Direction
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manifold Product:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PMS (Premium Motor Spirit)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Currently Supplying:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.emerald, width: 2),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: AppColors.emerald, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Tank $_fromTank (Active)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(Icons.arrow_forward, color: AppColors.muted),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Switch Manifold To:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.amber, width: 2),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.swap_horiz, color: AppColors.amber, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Tank $_toTank (Standby)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Affected Nozzle Transition Meter Readings (§7)
                    const Text(
                      '1. Transition Meter Readings (§7)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Input the current meter reading at the exact minute the physical valve was turned. This calculates litres drawn from Tank T1 prior to cutoff.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),

                    if (affected.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No nozzles are currently mapped to the active source tank.'),
                      )
                    else
                      ...affected.map((n) {
                        final controller = _meterControllers[n.nozzleNumber];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.ink,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Nozzle ${n.nozzleNumber}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shift Opening: ${CurrencyFormatter.formatLitres(n.openingReading)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: controller,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Current Switch Meter Reading',
                                        suffixText: 'Litres',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 16),

                    // Physical Dip Rod Verification
                    const Text(
                      '2. Physical Dip Rod Verification (Litres)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fromTankDipController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Tank $_fromTank Closing Dip',
                              suffixText: 'L',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _toTankDipController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Tank $_toTank Opening Dip',
                              suffixText: 'L',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Reason / Notes
                    const Text(
                      '3. Operational Justification / Reason',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Tank T1 reached 15% reorder point; switching to Tank T2.',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _handleConfirm,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Authorize & Apply Switch to Tank $_toTank',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
