import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
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

class _ClosingReadingsScreenState extends State<ClosingReadingsScreen>
    with UnsavedWorkAware {
  final state = StationAppState.instance;
  late List<NozzleItem> _nozzles;
  final Map<int, TextEditingController> _controllers = {};

  /// Local draft buffer: nothing below is written to StationAppState until
  /// _submit() succeeds, so Cancel always leaves shared state untouched.
  final Map<int, double> _drafts = {};
  final Map<int, String?> _errors = {};
  bool _isSubmitting = false;

  @override
  bool get hasUnsavedWork =>
      _drafts.isNotEmpty && !state.closingReadingsSubmitted;

  @override
  void initState() {
    super.initState();
    _nozzles = state.nozzles;
    for (var n in _nozzles) {
      _controllers[n.nozzleNumber] = TextEditingController(
        text: n.closingReading?.toStringAsFixed(2) ?? '',
      );
      if (n.closingReading != null && n.closingReading! >= n.openingReading) {
        _drafts[n.nozzleNumber] = n.closingReading!;
      }
    }
    ShellBackGuard.register(this);
  }

  @override
  void dispose() {
    ShellBackGuard.unregister(this);
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _litresSoldFor(NozzleItem nozzle) {
    final closing = _drafts[nozzle.nozzleNumber];
    if (closing == null || closing < nozzle.openingReading) return 0.0;
    return closing - nozzle.openingReading;
  }

  double _salesValueFor(NozzleItem nozzle) =>
      _litresSoldFor(nozzle) * nozzle.pricePerLitre;

  double get _totalExpectedSales =>
      _nozzles.fold(0.0, (sum, item) => sum + _salesValueFor(item));

  void _onClosingChanged(NozzleItem nozzle, String val) {
    final cleaned = val.replaceAll(',', '').trim();
    setState(() {
      if (cleaned.isEmpty) {
        _drafts.remove(nozzle.nozzleNumber);
        _errors[nozzle.nozzleNumber] = null;
        return;
      }

      final parsed = double.tryParse(cleaned);
      if (parsed == null) {
        _errors[nozzle.nozzleNumber] = 'Invalid decimal number';
        _drafts.remove(nozzle.nozzleNumber);
      } else if (parsed < nozzle.openingReading) {
        _errors[nozzle.nozzleNumber] =
            'Closing reading cannot be less than opening (${CurrencyFormatter.formatLitres(nozzle.openingReading)})';
        _drafts.remove(nozzle.nozzleNumber);
      } else {
        _errors[nozzle.nozzleNumber] = null;
        _drafts[nozzle.nozzleNumber] = parsed;
      }
    });
  }

  void _handleBack() {
    if (!hasUnsavedWork) {
      widget.onBack();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'This screen still has meter readings that have not been submitted. Leaving now discards them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onBack();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bad,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (state.currentStationCode.isEmpty ||
        _nozzles.isEmpty ||
        _nozzles.any((n) => n.pricePerLitre <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: const Text(
              'Configure a station, pumps and retail prices before submitting readings.')));
      return;
    }
    bool hasError = false;
    final Map<int, double> readings = {};

    for (var n in _nozzles) {
      final draft = _drafts[n.nozzleNumber];
      if (draft != null) {
        readings[n.nozzleNumber] = draft;
      } else {
        hasError = true;
        // Keep a specific validation message; only fall back to the generic
        // one when the field is empty or has no error yet.
        if (_errors[n.nozzleNumber] == null) {
          _errors[n.nozzleNumber] = 'Please enter valid closing dial';
        }
      }
    }

    if (hasError) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: const Text(
              'Please correct meter reading errors before submitting.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      state.recordClosingReadings(readings);
      state.markClosingReadingsSubmitted();

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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content:
              const Text('Could not save closing readings. Please try again.'),
        ),
      );
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
          onPressed: _handleBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Closing Meter Readings',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${state.currentUser.displayName} · ${DateFormat('EEE dd MMM · h:mm a').format(DateTime.now())}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          ForecourtSyncBar(
              stationName: '${state.currentStationName} · Forecourt'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record closing pump meter dials',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type the mechanical dial on each dispenser nozzle. Litres and sales value calculate dynamically.',
                        style: TextStyle(
                            fontSize: 15,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),

                      // Nozzle Input Cards
                      if (_nozzles.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.local_gas_station_outlined,
                                      size: 48,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No active pumps assigned to this shift',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Please contact your station manager or setup pumps in Admin settings.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ..._nozzles.map((nozzle) {
                        final err = _errors[nozzle.nozzleNumber];
                        final litresSold = _litresSoldFor(nozzle);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${nozzle.label} · ${nozzle.productName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Tank ${nozzle.tankCode} · ${CurrencyFormatter.formatNaira(nozzle.pricePerLitre)}/L',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Opening Dial (L)',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant)),
                                          const SizedBox(height: 4),
                                          TextFormField(
                                            initialValue: nozzle.openingReading
                                                .toStringAsFixed(2),
                                            readOnly: true,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Closing Dial (L) *',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          TextField(
                                            controller: _controllers[
                                                nozzle.nozzleNumber],
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                  RegExp(r'[0-9.,]')),
                                            ],
                                            decoration: InputDecoration(
                                              hintText:
                                                  'e.g. ${(nozzle.openingReading + 500).toStringAsFixed(1)}',
                                              errorText: err,
                                              errorMaxLines: 2,
                                              suffixText: 'L',
                                            ),
                                            onChanged: (val) =>
                                                _onClosingChanged(nozzle, val),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Litres sold: ${CurrencyFormatter.formatLitres(litresSold)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium),
                                      const SizedBox(height: 6),
                                      Text(
                                        CurrencyFormatter.formatNaira(
                                            _salesValueFor(nozzle)),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Total expected sales',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text('Carried to remittance declaration',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                              const SizedBox(height: 12),
                              Text(
                                CurrencyFormatter.formatNaira(
                                    _totalExpectedSales),
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
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
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                onPressed: (_isSubmitting || _nozzles.isEmpty) ? null : _submit,
                label: const Text('Save dials & proceed to remittance'),
              ),
            ),
            const SizedBox(width: 12),
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
}
