import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

class PriceChangeScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const PriceChangeScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<PriceChangeScreen> createState() => _PriceChangeScreenState();
}

class _PriceChangeScreenState extends State<PriceChangeScreen> with UnsavedWorkAware {
  final state = StationAppState.instance;

  String _selectedProduct = 'PMS';
  late TextEditingController _newPriceController;
  final TextEditingController _authorizedReasonController = TextEditingController();
  late Map<int, TextEditingController> _meterControllers;

  @override
  bool get hasUnsavedWork =>
      _authorizedReasonController.text.trim().isNotEmpty ||
      _newPriceController.text.trim() != _currentPriceText(_selectedProduct);

  String _currentPriceText(String product) =>
      (product == 'PMS' ? state.pmsPrice : state.agoPrice).toStringAsFixed(0);

  @override
  void initState() {
    super.initState();
    ShellBackGuard.register(this);
    _newPriceController = TextEditingController(text: _currentPriceText(_selectedProduct));
    _authorizedReasonController.addListener(_onReasonChanged);
    _meterControllers = {
      for (var n in state.nozzles)
        n.nozzleNumber: TextEditingController(
          text: (n.closingReading ?? n.openingReading).toStringAsFixed(1),
        )
    };
  }

  void _onReasonChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ShellBackGuard.unregister(this);
    _authorizedReasonController.removeListener(_onReasonChanged);
    _newPriceController.dispose();
    _authorizedReasonController.dispose();
    for (var c in _meterControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onProductChanged(String? prod) {
    if (prod == null) return;
    setState(() {
      _selectedProduct = prod;
      _newPriceController.text = _currentPriceText(prod);
    });
  }

  Future<void> _handleBack() async {
    if (!hasUnsavedWork) {
      widget.onBack();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard price change?'),
        content: const Text('This screen has unsaved price authorization input. Leaving now discards it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Editing')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.bad, foregroundColor: Colors.white),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true) widget.onBack();
  }

  Future<void> _submit() async {
    final reason = _authorizedReasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Enter a custom authorization directive before applying the price change.'),
        ),
      );
      return;
    }

    final newPrice = double.tryParse(_newPriceController.text.trim()) ?? 0.0;
    if (newPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please enter a valid retail price'),
        ),
      );
      return;
    }

    final oldPrice = _selectedProduct == 'PMS' ? state.pmsPrice : state.agoPrice;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply station-wide price change?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_selectedProduct: ${CurrencyFormatter.formatNaira(oldPrice)}/L  →  ${CurrencyFormatter.formatNaira(newPrice)}/L',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink),
            ),
            const SizedBox(height: 10),
            Text(
              'This applies immediately at every nozzle of all 5 branches. Transition meter readings are captured for each $_selectedProduct nozzle and prior sales stay locked at the old price (§2.9).',
              style: const TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 12),
            Text(
              'Directive: $reason',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Apply New Price', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Collect meter snapshots
    final Map<int, double> snapshots = {};
    for (var n in state.nozzles.where((n) => n.productName == _selectedProduct)) {
      final dial = double.tryParse(_meterControllers[n.nozzleNumber]?.text ?? '') ?? n.openingReading;
      snapshots[n.nozzleNumber] = dial;
    }

    try {
      state.authorizePriceChange(
        product: _selectedProduct,
        newPrice: newPrice,
        reason: reason,
        meterSnapshots: snapshots,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bad,
            behavior: SnackBarBehavior.floating,
            content: Text('Price change was not applied: $e'),
          ),
        );
      }
      return;
    }

    final appliedPrice = _selectedProduct == 'PMS' ? state.pmsPrice : state.agoPrice;
    if (appliedPrice != newPrice) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.bad,
            behavior: SnackBarBehavior.floating,
            content: Text('Price change did not take effect. Please retry.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '$_selectedProduct price changed to ${CurrencyFormatter.formatNaira(newPrice)}/L! Transition meter dials captured across all nozzles.',
        ),
      ),
    );

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    if (state.currentUser.role != UserRole.director) {
      return _buildRestrictedAccess();
    }

    final reasonReady = _authorizedReasonController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _handleBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fuel Price Authorization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Director · Central Price Governance (§2.8, §2.9)', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Authorize retail price adjustment',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'At a price change, the system captures transition meter readings across all nozzles. Previous sales are locked at old price; new sales calculate at new price (§2.9).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Product', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedProduct,
                                    items: [
                                      DropdownMenuItem(value: 'PMS', child: Text('PMS (Current: ${CurrencyFormatter.formatNaira(state.pmsPrice)})')),
                                      DropdownMenuItem(value: 'AGO', child: Text('AGO (Current: ${CurrencyFormatter.formatNaira(state.agoPrice)})')),
                                    ],
                                    onChanged: _onProductChanged,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('New Retail Price (₦/L) *', style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _newPriceController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(prefixText: '₦ '),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text('Authorization Directive / Commercial Justification *', style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _authorizedReasonController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. NNPC depot rate revision approved by Director',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          reasonReady
                              ? 'Recorded verbatim in the price authorization audit trail (§2.8).'
                              : 'Required — type a custom directive. Pre-filled directives are not accepted.',
                          style: TextStyle(
                            fontSize: 12,
                            color: reasonReady ? AppColors.muted : AppColors.bad,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Transition Meter Readings
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transition Meter Readings Snapshot',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter current physical meter reading on each $_selectedProduct nozzle at the moment of price change:',
                          style: const TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                        ...state.nozzles.where((n) => n.productName == _selectedProduct).map((n) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Nozzle ${n.nozzleNumber} (${n.productName})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Tank ${n.tankCode}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _meterControllers[n.nozzleNumber],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      suffixText: 'L',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
                icon: const Icon(Icons.security_update_good),
                onPressed: reasonReady ? _submit : null,
                label: const Text('Authorize & apply new price'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _handleBack,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictedAccess() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: const Text('Fuel Price Authorization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: AppColors.muted),
              const SizedBox(height: 16),
              const Text(
                'Restricted — director access required',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Central retail price governance is limited to the Director role (§2.8, §2.9).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
