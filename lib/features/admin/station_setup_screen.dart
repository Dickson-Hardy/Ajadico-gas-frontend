import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../state/station_app_state.dart';
import '../manager/tank_changeover_dialog.dart';

/// Director & Admin Forecourt & Station Infrastructure Setup Screen (BRD §1, §3.1, §7)
/// Allows Central Management to configure pumps, tanks, interlocked manifolds, and nozzle plumbing.
class StationSetupScreen extends StatefulWidget {
  final VoidCallback onBack;

  const StationSetupScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<StationSetupScreen> createState() => _StationSetupScreenState();
}

class _StationSetupScreenState extends State<StationSetupScreen> {
  final state = StationAppState.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleStationInterlock(bool value) async {
    setState(() => _isSaving = true);
    final success = await state.updateStationInterlockConfig(value);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? AppColors.ok : AppColors.cherry,
          content: Text(
            success
                ? 'Station Interlocked Manifold Piping ${value ? "Enabled" : "Disabled"}.'
                : 'Failed to update station setting.',
          ),
        ),
      );
    }
  }

  Future<void> _toggleTankInterlock(String tankCode, bool isInterlocked) async {
    setState(() => _isSaving = true);
    final success = await state.updateTankInterlockConfig(tankCode, isInterlocked);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? AppColors.ok : AppColors.cherry,
          content: Text(
            success
                ? 'Tank $tankCode manifold interlock updated to ${isInterlocked ? "Interlocked Twin" : "Independent"}.'
                : 'Failed to update tank interlock status.',
          ),
        ),
      );
    }
  }

  Future<void> _reassignNozzle(int nozzleNumber, String targetTankCode) async {
    setState(() => _isSaving = true);
    final success = await state.assignNozzleSupplyingTank(nozzleNumber, targetTankCode);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? AppColors.ok : AppColors.cherry,
          content: Text(
            success
                ? 'Nozzle $nozzleNumber remapped to supply from Tank $targetTankCode.'
                : 'Failed to update nozzle pipe routing.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Station & Forecourt Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('${state.currentStationName} (${state.currentStationCode})', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          if (state.hasInterlockedTanks)
            TextButton.icon(
              icon: const Icon(Icons.alt_route, color: AppColors.amber),
              label: const Text('Execute Manifold Switch', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
              onPressed: () => TankChangeoverDialog.show(context, state),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Station Infrastructure Overview Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.business, color: AppColors.ink),
                                SizedBox(width: 10),
                                Text(
                                  'Station Manifold Architecture',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.ink),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: state.hasInterlockedTanks ? const Color(0xFFFEF3C7) : AppColors.lightEmerald,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                state.hasInterlockedTanks ? 'Interlocked Manifold Station (§3.1)' : 'Fixed Dedicated Piping (§3.1)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: state.hasInterlockedTanks ? const Color(0xFF92400E) : AppColors.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Configure whether this station utilizes shared manifold changeover valves between underground tanks (2 of 5 Ajadico branches), or fixed one-to-one pipe routing (3 branches).',
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.line),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Enable Interlocked Manifold Piping (BRD §3.1 & §7)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'When active, the Branch Manager and Director are equipped with the changeover workflow to record valve shifts and split meter sales between twin tanks.',
                            style: TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          value: state.hasInterlockedTanks,
                          activeColor: AppColors.primary,
                          onChanged: _isSaving ? null : _toggleStationInterlock,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Underground Storage Tanks (UST) Configuration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Underground Storage Tanks (UST)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    Text(
                      '${state.tanks.length} Tanks Registered',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ...state.tanks.map((tank) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: tank.product == 'PMS' ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${tank.code} • ${tank.product}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: tank.product == 'PMS' ? const Color(0xFF92400E) : const Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Capacity: ${CurrencyFormatter.formatLitres(tank.capacity)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              if (state.hasInterlockedTanks && tank.isInterlocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tank.isActiveSupply ? AppColors.lightEmerald : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: tank.isActiveSupply ? AppColors.emerald : AppColors.amber,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        tank.isActiveSupply ? Icons.check_circle : Icons.pause_circle_outline,
                                        size: 14,
                                        color: tank.isActiveSupply ? AppColors.emerald : const Color(0xFF92400E),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tank.isActiveSupply ? 'ACTIVE SUPPLY' : 'STANDBY TWIN',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: tank.isActiveSupply ? AppColors.emerald : const Color(0xFF92400E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text('Physical Dip: ${CurrencyFormatter.formatLitres(tank.physicalDip)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              const SizedBox(width: 16),
                              Text('Calculated Book: ${CurrencyFormatter.formatLitres(tank.bookStock)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                          if (state.hasInterlockedTanks) ...[
                            const Divider(color: AppColors.line),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Mark as Manifold Interlocked Twin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Allows nozzles to be dynamically toggled between this tank and its twin during changeover.', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              value: tank.isInterlocked,
                              activeColor: AppColors.primary,
                              onChanged: _isSaving ? null : (val) => _toggleTankInterlock(tank.code, val),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 20),

                // 3. Pump Island Dispensers & Nozzle Pipe Routing
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dispenser Nozzle Plumbing Routing',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    Text(
                      '${state.nozzles.length} Nozzles Configured',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ...state.nozzles.map((nozzle) {
                  final eligibleTanks = state.tanks.where((t) => t.product == nozzle.productName).toList();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'N${nozzle.nozzleNumber}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nozzle ${nozzle.nozzleNumber} (${nozzle.productName})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Latest Meter: ${CurrencyFormatter.formatLitres(nozzle.openingReading)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Supplying Tank:', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              const SizedBox(height: 4),
                              DropdownButton<String>(
                                value: nozzle.tankCode,
                                isDense: true,
                                underline: Container(height: 1, color: AppColors.primary),
                                items: eligibleTanks.map((t) {
                                  return DropdownMenuItem<String>(
                                    value: t.code,
                                    child: Text('Tank ${t.code} (${t.product})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: _isSaving ? null : (newTank) {
                                  if (newTank != null && newTank != nozzle.tankCode) {
                                    _reassignNozzle(nozzle.nozzleNumber, newTank);
                                  }
                                },
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
    );
  }
}
