import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';
import '../../core/widgets/shift_adjustment_ledger.dart';
import '../../models/shift_adjustment.dart';

class AttendantHomeScreen extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onLogout;
  final VoidCallback onOpenClosingReadings;
  final VoidCallback onOpenRemittance;
  final VoidCallback? onOpenCreditSale;
  final VoidCallback? onOpenFuelReturn;
  final VoidCallback? onOpenPumpExpense;

  const AttendantHomeScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onOpenClosingReadings,
    required this.onOpenRemittance,
    this.onOpenCreditSale,
    this.onOpenFuelReturn,
    this.onOpenPumpExpense,
  });

  @override
  State<AttendantHomeScreen> createState() => _AttendantHomeScreenState();
}

class _AttendantHomeScreenState extends State<AttendantHomeScreen> {
  final state = StationAppState.instance;

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

  void _confirmNozzle(int nozzleNumber) {
    state.confirmOpeningReading(nozzleNumber);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content:
            Text('${state.pumpLabel(nozzleNumber)} opening meter confirmed.'),
      ),
    );
  }

  Future<void> _openCashDropDialog() async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final acknowledgedDrops =
        state.totalAttendantAcknowledgedDrops(widget.user.id);
    final pendingDrops = state.totalAttendantPendingDrops(widget.user.id);
    final totalDropped = acknowledgedDrops + pendingDrops;

    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Add cash submission'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width < 480
                    ? MediaQuery.of(context).size.width - 80
                    : 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.ok.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.ok.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Drops Handed Over This Shift',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                  Text(
                                    pendingDrops > 0
                                        ? '${CurrencyFormatter.formatNaira(acknowledgedDrops)} acknowledged · ${CurrencyFormatter.formatNaira(pendingDrops)} pending'
                                        : 'All previously handed drops acknowledged',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.formatNaira(totalDropped),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ok),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Drop Amount (₦) *',
                          hintText: 'e.g. 100,000',
                          prefixText: '₦ ',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setDlgState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildQuickAddButton(
                              '+₦20,000', 20000, amountCtrl, setDlgState),
                          _buildQuickAddButton(
                              '+₦50,000', 50000, amountCtrl, setDlgState),
                          _buildQuickAddButton(
                              '+₦100,000', 100000, amountCtrl, setDlgState),
                          _buildQuickAddButton(
                              '+₦200,000', 200000, amountCtrl, setDlgState),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Notes / Denomination Breakdown (Optional)',
                          hintText: 'e.g. Drop #2, 100x ₦1,000 notes',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final amt = double.tryParse(
                            amountCtrl.text.replaceAll(',', '').trim()) ??
                        0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              const Text('Please enter a valid drop amount.'),
                          backgroundColor: AppColors.bad,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final saved = await state.recordInterimCashDrop(
                      amount: amt,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor:
                              saved == null ? AppColors.bad : AppColors.ok,
                          content: Text(saved == null
                              ? 'Could not record submission. Please try again.'
                              : 'Cash submission recorded locally; awaiting cashier confirmation.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Submit Drop to Cashier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ok,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    await Navigator.of(context).push(route);
    await route.completed;
    amountCtrl.dispose();
    notesCtrl.dispose();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End shift session?'),
        content: const Text(
          'Log out of this shared forecourt tablet? Any unsaved entries on other screens will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bad,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  /// Quick-add chips accumulate on top of whatever is already typed instead of
  /// overwriting the attendant's entry.
  Widget _buildQuickAddButton(
    String label,
    double amount,
    TextEditingController controller,
    StateSetter setDlgState,
  ) {
    return OutlinedButton(
      onPressed: () {
        setDlgState(() {
          final current =
              double.tryParse(controller.text.replaceAll(',', '').trim()) ??
                  0.0;
          controller.text = (current + amount).toStringAsFixed(0);
        });
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Future<void> _openLogPosDialog() async {
    String channel = 'pos_card';
    final amountCtrl = TextEditingController();
    final terminalCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();

    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Add POS / transfer'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record card swipe or customer bank transfer directly at pump.',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: channel,
                        decoration: const InputDecoration(
                          labelText: 'Payment Channel *',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'pos_card',
                              child:
                                  const Text('POS Card Payment (Debit Card)')),
                          DropdownMenuItem(
                              value: 'pos_transfer',
                              child: const Text(
                                  'POS Transfer (Terminal Dynamic Account)')),
                          DropdownMenuItem(
                              value: 'bank_transfer',
                              child:
                                  const Text('Direct Station Bank Transfer')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDlgState(() => channel = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount Paid (₦) *',
                          hintText: 'e.g. 25,000',
                          prefixText: '₦ ',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: terminalCtrl,
                              decoration: InputDecoration(
                                labelText: channel == 'bank_transfer'
                                    ? 'Bank Account / Name'
                                    : 'POS Terminal Name *',
                                hintText: channel == 'bank_transfer'
                                    ? 'Receiving bank and account'
                                    : 'Actual terminal identifier',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: refCtrl,
                              decoration: const InputDecoration(
                                labelText: 'RRN / Approval Ref',
                                hintText: 'e.g. 001928374',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: vehicleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Vehicle Plate (Optional)',
                          hintText: 'e.g. AAA-123-XY',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final amt = double.tryParse(
                            amountCtrl.text.replaceAll(',', '').trim()) ??
                        0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: const Text('Please enter a valid amount.'),
                          backgroundColor: AppColors.bad,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final saved = await state.recordPosTransaction(
                      paymentChannel: channel,
                      amount: amt,
                      terminalName: terminalCtrl.text.trim().isEmpty
                          ? null
                          : terminalCtrl.text.trim(),
                      referenceNumber: refCtrl.text.trim().isEmpty
                          ? null
                          : refCtrl.text.trim(),
                      customerVehicle: vehicleCtrl.text.trim().isEmpty
                          ? null
                          : vehicleCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor:
                              saved == null ? AppColors.bad : AppColors.ok,
                          content: Text(saved == null
                              ? 'Could not record payment. Please try again.'
                              : 'Payment recorded locally.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save Transaction'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pos,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    await Navigator.of(context).push(route);
    await route.completed;
    amountCtrl.dispose();
    terminalCtrl.dispose();
    refCtrl.dispose();
    vehicleCtrl.dispose();
  }

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(label),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600))
            ]),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shiftId = state.currentShiftId;
    final drops = state.cashDrops
        .where((d) => d.attendantId == widget.user.id && d.shiftId == shiftId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final payments = state.posTransactions
        .where((p) => p.attendantId == widget.user.id && p.shiftId == shiftId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final credits = state.creditSalesRecords
        .where((c) => c.attendantId == widget.user.id && c.shiftId == shiftId)
        .toList();
    final submitted = state.submissions
        .where((s) => s.attendantId == widget.user.id && s.shiftId == shiftId);
    final handover = submitted.isEmpty ? null : submitted.first;
    final totalDrops = drops.fold(0.0, (sum, d) => sum + d.amount);
    final confirmed = drops
        .where((d) => d.isAcknowledged)
        .fold(0.0, (sum, d) => sum + d.amount);
    final pending = totalDrops - confirmed;
    final nonCash = payments.fold(0.0, (sum, p) => sum + p.amount);
    final credit = credits.fold(0.0, (sum, c) => sum + c.amount);
    final readingsComplete = state.nozzles.isNotEmpty &&
        state.nozzles
            .every((n) => n.closingReading != null && n.isOpeningConfirmed);
    final sales = state.currentForecourtSalesValue;
    final adjustments = ShiftAdjustmentTotals(
        state.adjustmentsForShift(shiftId, widget.user.id));
    final expected =
        handover?.expectedSalesValue ?? sales - adjustments.approvedFuelValue;
    final amount = handover == null
        ? totalDrops + nonCash + credit + adjustments.approvedExpenses
        : handover.totalMoneyDeclared +
            handover.creditSalesDeclared +
            handover.approvedPumpExpenses;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shift'),
        actions: [
          IconButton(
              tooltip: state.isDarkMode ? 'Light mode' : 'Dark mode',
              onPressed: state.toggleTheme,
              icon: Icon(state.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined)),
          IconButton(
              tooltip: 'Sign out',
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(children: [
        ForecourtSyncBar(stationName: state.currentStationName),
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.user.displayName,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                      '${state.currentStationName} · ${DateFormat('EEE, d MMM yyyy').format(DateTime.now())}',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(
                      'Readings, submissions and final handover for this shift.',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  _section('1. Pump readings & sales', [
                    if (state.nozzles.isEmpty)
                      const Text(
                          'No assigned pumps. Ask your manager to configure this shift.'),
                    for (final nozzle in state.nozzles) ...[
                      Text('${nozzle.label} · ${nozzle.productName}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      _line('Opening meter',
                          '${nozzle.openingReading.toStringAsFixed(2)} L'),
                      _line(
                          'Closing meter',
                          nozzle.closingReading == null
                              ? 'Not recorded'
                              : '${nozzle.closingReading!.toStringAsFixed(2)} L'),
                      if (!nozzle.isOpeningConfirmed)
                        OutlinedButton(
                            onPressed: () =>
                                _confirmNozzle(nozzle.nozzleNumber),
                            child: const Text('Confirm opening reading')),
                      if (nozzle.closingReading != null)
                        Text(
                            '${nozzle.litresSold.toStringAsFixed(2)} L × ${CurrencyFormatter.formatNaira(nozzle.pricePerLitre, includeDecimals: true)}/L = ${CurrencyFormatter.formatNaira(nozzle.salesValue, includeDecimals: true)}'),
                      const Divider(height: 24),
                    ],
                    _line(
                        'Metered sales',
                        readingsComplete
                            ? CurrencyFormatter.formatNaira(sales)
                            : 'Awaiting complete readings'),
                    OutlinedButton.icon(
                        onPressed: handover != null
                            ? null
                            : widget.onOpenClosingReadings,
                        icon: const Icon(Icons.speed),
                        label: const Text('Record closing readings')),
                  ]),
                  _section('2. Cash submissions', [
                    if (drops.isEmpty)
                      const Text('No cash submitted during this shift yet.'),
                    for (var i = 0; i < drops.length; i++) ...[
                      _line(
                          'Submission ${i + 1} · ${DateFormat('HH:mm').format(drops[i].createdAt.toLocal())}',
                          CurrencyFormatter.formatNaira(drops[i].amount)),
                      Text(
                          drops[i].isAcknowledged
                              ? 'Confirmed by cashier'
                              : 'Awaiting cashier confirmation',
                          style: TextStyle(color: colors.onSurfaceVariant)),
                      if (drops[i].notes?.isNotEmpty ?? false)
                        Text(drops[i].notes!),
                      const Divider(height: 20),
                    ],
                    _line('Total cash submitted',
                        CurrencyFormatter.formatNaira(totalDrops)),
                    if (pending > 0)
                      _line('Awaiting confirmation',
                          CurrencyFormatter.formatNaira(pending)),
                    OutlinedButton.icon(
                        onPressed:
                            handover != null ? null : _openCashDropDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add cash submission')),
                  ]),
                  _section('3. Other payments & credit', [
                    if (payments.isEmpty && credits.isEmpty)
                      const Text('No other payments recorded.'),
                    for (final payment in payments)
                      _line(
                          '${payment.channelDisplayName} · ${DateFormat('HH:mm').format(payment.createdAt.toLocal())}',
                          CurrencyFormatter.formatNaira(payment.amount)),
                    for (final sale in credits)
                      _line('Credit · ${sale.customerName}',
                          CurrencyFormatter.formatNaira(sale.amount)),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton(
                          onPressed:
                              handover != null ? null : _openLogPosDialog,
                          child: const Text('Add POS / transfer')),
                      OutlinedButton(
                          onPressed:
                              handover != null ? null : widget.onOpenCreditSale,
                          child: const Text('Add credit sale')),
                    ]),
                  ]),
                  _section('4. Expenses & non-sale fuel', [
                    const Text(
                        'Only approved entries affect reconciliation. Fuel use is separate from cash spending.'),
                    const SizedBox(height: 12),
                    ShiftAdjustmentLedger(entries: adjustments.entries),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton(
                          onPressed: handover != null
                              ? null
                              : widget.onOpenPumpExpense,
                          child: const Text('Add pump expense')),
                      OutlinedButton(
                          onPressed:
                              handover != null ? null : widget.onOpenFuelReturn,
                          child: const Text('Fuel return / internal use')),
                    ]),
                  ]),
                  _section('5. Final cash handover', [
                    const Text(
                        'The remaining sales cash handed to the cashier at the end of this shift. Do not include earlier submissions again.'),
                    const SizedBox(height: 8),
                    _line(
                        'Final cash handed over',
                        handover == null
                            ? 'Not submitted'
                            : CurrencyFormatter.formatNaira(
                                handover.finalCashHandover)),
                    if (handover != null) Text(handover.status),
                    FilledButton.icon(
                        onPressed: handover != null ||
                                !state.closingReadingsSubmitted ||
                                pending > 0 ||
                                adjustments.hasPending
                            ? null
                            : widget.onOpenRemittance,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Review & submit final handover')),
                    if (handover == null && !state.closingReadingsSubmitted)
                      const Text(
                          'Save closing readings before the final handover.'),
                    if (pending > 0)
                      const Text(
                          'The cashier must confirm earlier cash submissions before you finalize.'),
                    if (adjustments.hasPending)
                      const Text(
                          'Resolve pending expenses and non-sale fuel entries before final handover.'),
                  ]),
                  _section('Shift reconciliation', [
                    _line(
                        'Gross metered value',
                        readingsComplete
                            ? CurrencyFormatter.formatNaira(sales)
                            : 'Not ready'),
                    _line(
                        'Approved non-sale fuel',
                        CurrencyFormatter.formatNaira(
                            handover?.approvedNonSaleFuel ??
                                adjustments.approvedFuelValue)),
                    _line(
                        'Expected collectible sales',
                        readingsComplete
                            ? CurrencyFormatter.formatNaira(expected)
                            : 'Not ready'),
                    _line(
                        'Approved cash expenses',
                        CurrencyFormatter.formatNaira(
                            handover?.approvedPumpExpenses ??
                                adjustments.approvedExpenses)),
                    _line(
                        handover == null
                            ? 'Recorded so far'
                            : 'Total accounted for',
                        CurrencyFormatter.formatNaira(amount)),
                    if (readingsComplete)
                      _line(
                          handover == null
                              ? 'Still to account for'
                              : 'Difference',
                          CurrencyFormatter.formatNaira(
                              handover == null
                                  ? expected - amount
                                  : handover.variance,
                              includeDecimals: true)),
                    const Text(
                        'Cash submissions + final handover + POS / transfers + credit sales + approved cash expenses. Approved non-sale fuel is excluded from collectible sales.'),
                  ]),
                ]),
          )),
        )),
      ]),
    );
  }
}
