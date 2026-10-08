import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/user_profile.dart';
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

  Future<bool> _confirmSafetyChange({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            child: Text(confirmLabel, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _toggleStationInterlock(bool value) async {
    final confirmed = await _confirmSafetyChange(
      title: value ? 'Enable interlocked manifold piping?' : 'Disable interlocked manifold piping?',
      message: value
          ? 'Enabling the station manifold equips the Branch Manager and Director with the changeover workflow to record valve shifts and split meter sales between twin tanks.'
          : 'Disabling the station manifold reverts this branch to fixed one-to-one pipe routing and removes the changeover workflow.',
      confirmLabel: value ? 'Enable Interlock' : 'Disable Interlock',
      confirmColor: value ? AppColors.primary : AppColors.bad,
    );
    if (!confirmed || !mounted) return;

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
    final confirmed = await _confirmSafetyChange(
      title: isInterlocked ? 'Interlock this tank?' : 'Release tank interlock?',
      message: isInterlocked
          ? 'Tank $tankCode will join its twin as a manifold-interlocked pair, allowing nozzles to be switched between the two tanks during changeover.'
          : 'Tank $tankCode will revert to independent, dedicated pipe routing. Nozzles will no longer be switchable to or from this tank during changeover.',
      confirmLabel: isInterlocked ? 'Interlock Tank' : 'Release Interlock',
      confirmColor: isInterlocked ? AppColors.primary : AppColors.bad,
    );
    if (!confirmed || !mounted) return;

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

  Future<void> _reassignNozzle(int nozzleNumber, String targetTankCode, {String? fromTankCode}) async {
    final confirmed = await _confirmSafetyChange(
      title: 'Re-pipe nozzle $nozzleNumber?',
      message: fromTankCode == null
          ? 'Nozzle $nozzleNumber will be re-piped to supply from Tank $targetTankCode.'
          : 'Nozzle $nozzleNumber will be re-piped from Tank $fromTankCode to Tank $targetTankCode. Forecourt deliveries from this nozzle follow the new routing immediately.',
      confirmLabel: 'Re-pipe Nozzle',
      confirmColor: AppColors.primary,
    );
    if (!confirmed || !mounted) return;

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

  void _showSetupResultSnackBar(String result, {required String createdMessage, required String failedMessage}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: switch (result) {
          'created' => AppColors.ok,
          'queued' => AppColors.warn,
          _ => AppColors.bad,
        },
        behavior: SnackBarBehavior.floating,
        content: switch (result) {
          'created' => Text(createdMessage),
          'queued' => const Text('Saved — will sync when online'),
          _ => Text(failedMessage),
        },
      ),
    );
  }

  Future<void> _showAddTankDialog() async {
    final codeController = TextEditingController();
    final capacityController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    String product = 'PMS';
    String error = '';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Storage Tank'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tank Code *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(hintText: 'T3'),
                      onChanged: (_) => setDialogState(() => error = ''),
                    ),
                    const SizedBox(height: 14),
                    const Text('Product *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: product,
                      items: const [
                        DropdownMenuItem(value: 'PMS', child: Text('PMS')),
                        DropdownMenuItem(value: 'AGO', child: Text('AGO')),
                      ],
                      onChanged: (v) => setDialogState(() {
                        if (v != null) product = v;
                        error = '';
                      }),
                    ),
                    const SizedBox(height: 14),
                    const Text('Capacity (L) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: capacityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(hintText: 'e.g. 15000'),
                      onChanged: (_) => setDialogState(() => error = ''),
                    ),
                    const SizedBox(height: 14),
                    const Text('Initial Stock (L) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: stockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(hintText: '0'),
                      onChanged: (_) => setDialogState(() => error = ''),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        error,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.bad),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final code = codeController.text.trim();
                        final capacity =
                            double.tryParse(capacityController.text.trim().replaceAll(',', '')) ?? 0.0;
                        final stock =
                            double.tryParse(stockController.text.trim().replaceAll(',', '')) ?? 0.0;
                        if (code.isEmpty) {
                          setDialogState(() => error = 'Enter a tank code.');
                          return;
                        }
                        if (capacity <= 0) {
                          setDialogState(() => error = 'Enter a capacity greater than 0 L.');
                          return;
                        }
                        if (stock < 0) {
                          setDialogState(() => error = 'Initial stock cannot be negative.');
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          error = '';
                        });
                        final result = await state.createTank(
                          code: code,
                          productCode: product,
                          capacityLitres: capacity,
                          initialStockLitres: stock,
                        );
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSetupResultSnackBar(
                          result,
                          createdMessage: 'Tank $code created',
                          failedMessage: 'Could not add tank',
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Add Tank'),
              ),
            ],
          );
        },
      ),
    );

    codeController.dispose();
    capacityController.dispose();
    stockController.dispose();
  }

  Future<void> _showAddNozzleDialog() async {
    final numberController = TextEditingController();
    final meterController = TextEditingController(text: '0');
    String product = 'PMS';
    String? tankCode;
    String error = '';
    bool isSubmitting = false;
    final tanks = state.tanks;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Dispenser Nozzle'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nozzle Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: numberController,
                      keyboardType: const TextInputType.numberWithOptions(),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: 'e.g. 4'),
                      onChanged: (_) => setDialogState(() => error = ''),
                    ),
                    const SizedBox(height: 14),
                    const Text('Product *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: product,
                      items: const [
                        DropdownMenuItem(value: 'PMS', child: Text('PMS')),
                        DropdownMenuItem(value: 'AGO', child: Text('AGO')),
                      ],
                      onChanged: (v) => setDialogState(() {
                        if (v != null) product = v;
                        error = '';
                      }),
                    ),
                    const SizedBox(height: 14),
                    const Text('Supplying Tank *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: tankCode,
                      isExpanded: true,
                      hint: Text(tanks.isEmpty ? 'No tanks registered yet' : 'Select tank'),
                      items: tanks.map((t) {
                        return DropdownMenuItem(
                          value: t.code,
                          child: Text(
                            'Tank ${t.code} (${t.product})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() {
                        tankCode = v;
                        error = '';
                      }),
                    ),
                    const SizedBox(height: 14),
                    const Text('Opening Meter (L) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: meterController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(hintText: '0'),
                      onChanged: (_) => setDialogState(() => error = ''),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        error,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.bad),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final number = int.tryParse(numberController.text.trim());
                        final meter =
                            double.tryParse(meterController.text.trim().replaceAll(',', '')) ?? 0.0;
                        if (number == null || number <= 0) {
                          setDialogState(() => error = 'Enter a nozzle number greater than 0.');
                          return;
                        }
                        if (tankCode == null) {
                          setDialogState(
                            () => error = tanks.isEmpty
                                ? 'Register a storage tank before adding a nozzle.'
                                : 'Select the supplying tank.',
                          );
                          return;
                        }
                        if (meter < 0) {
                          setDialogState(() => error = 'Opening meter cannot be negative.');
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          error = '';
                        });
                        final result = await state.createNozzle(
                          nozzleNumber: number,
                          productCode: product,
                          tankCode: tankCode!,
                          latestMeterReading: meter,
                        );
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSetupResultSnackBar(
                          result,
                          createdMessage: 'Nozzle $number created',
                          failedMessage: 'Could not add nozzle',
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Add Nozzle'),
              ),
            ],
          );
        },
      ),
    );

    numberController.dispose();
    meterController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (state.currentUser.role != UserRole.director) {
      return _buildRestrictedAccess();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Station & Forecourt Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              '${state.currentStationName} (${state.currentStationCode})',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        actions: [
          if (state.hasInterlockedTanks)
            TextButton.icon(
              icon: const Icon(Icons.alt_route, color: AppColors.amber),
              label: const Text('Execute Manifold Switch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => TankChangeoverDialog.show(context, state),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
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
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Row(
                              mainAxisSize: MainAxisSize.min,
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
                                color: state.hasInterlockedTanks ? AppColors.warnSurface : AppColors.lightEmerald,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                state.hasInterlockedTanks ? 'Interlocked Manifold Station' : 'Fixed Dedicated Piping',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: state.hasInterlockedTanks ? AppColors.warnInk : AppColors.okInk,
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
                            'Enable Interlocked Manifold Piping',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'When active, the Branch Manager and Director are equipped with the changeover workflow to record valve shifts and split meter sales between twin tanks.',
                            style: TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          value: state.hasInterlockedTanks,
                          activeThumbColor: AppColors.primary,
                          onChanged: _isSaving ? null : _toggleStationInterlock,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Underground Storage Tanks (UST) Configuration
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Underground Storage Tanks (UST)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Tank'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: _isSaving ? null : _showAddTankDialog,
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
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: tank.product == 'PMS' ? AppColors.warnSurface : AppColors.lightEmerald,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${tank.code} • ${tank.product}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: tank.product == 'PMS' ? AppColors.warnInk : AppColors.okInk,
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
                                    color: tank.isActiveSupply ? AppColors.lightEmerald : AppColors.warnSurface,
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
                                        color: tank.isActiveSupply ? AppColors.okInk : AppColors.warnInk,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tank.isActiveSupply ? 'ACTIVE SUPPLY' : 'STANDBY TWIN',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: tank.isActiveSupply ? AppColors.okInk : AppColors.warnInk,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Text('Physical Dip: ${CurrencyFormatter.formatLitres(tank.physicalDip)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              Text('Calculated Book: ${CurrencyFormatter.formatLitres(tank.bookStock)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                          if (state.hasInterlockedTanks) ...[
                            const Divider(color: AppColors.line),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Mark as Manifold Interlocked Twin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Allows nozzles to be dynamically toggled between this tank and its twin during changeover.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              value: tank.isInterlocked,
                              activeThumbColor: AppColors.primary,
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
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Dispenser Nozzle Plumbing Routing',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Nozzle'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: _isSaving ? null : _showAddNozzleDialog,
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
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Supplying Tank:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
                                      _reassignNozzle(nozzle.nozzleNumber, newTank, fromTankCode: nozzle.tankCode);
                                    }
                                  },
                                ),
                              ],
                            ),
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

  Widget _buildRestrictedAccess() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Station & Forecourt Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppColors.muted),
            const SizedBox(height: 16),
            const Text(
              'Restricted — director access required',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
