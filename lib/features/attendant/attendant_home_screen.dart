import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/interim_cash_drop.dart';
import '../../models/pos_transaction.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

class AttendantHomeScreen extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onLogout;
  final VoidCallback onOpenClosingReadings;
  final VoidCallback onOpenRemittance;

  const AttendantHomeScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onOpenClosingReadings,
    required this.onOpenRemittance,
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
        content: Text('Nozzle $nozzleNumber opening meter confirmed.'),
      ),
    );
  }

  void _openCashDropDialog() {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final estimatedPouch = state.attendantEstimatedCashInPouch;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.payments, color: AppColors.ok),
                  SizedBox(width: 8),
                  Text('Hand Over Interim Cash Drop', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Est. Cash in Pouch', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              Text('Forecourt Physical Cash', style: TextStyle(fontSize: 11, color: AppColors.slate)),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.formatNaira(estimatedPouch),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ok),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Drop Amount (₦) *',
                        hintText: 'e.g. 100,000',
                        prefixText: '₦ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('+₦50,000'),
                          onPressed: () {
                            setDlgState(() => amountCtrl.text = '50000');
                          },
                        ),
                        ActionChip(
                          label: const Text('+₦100,000'),
                          onPressed: () {
                            setDlgState(() => amountCtrl.text = '100000');
                          },
                        ),
                        ActionChip(
                          label: const Text('+₦150,000'),
                          onPressed: () {
                            setDlgState(() => amountCtrl.text = '150000');
                          },
                        ),
                        if (estimatedPouch > 0)
                          ActionChip(
                            label: const Text('All Pouch Cash'),
                            onPressed: () {
                              setDlgState(() => amountCtrl.text = estimatedPouch.toStringAsFixed(0));
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Denomination Breakdown (Optional)',
                        hintText: 'e.g. Drop #2, 100x ₦1,000 notes',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final amt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid drop amount.'),
                          backgroundColor: AppColors.bad,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await state.recordInterimCashDrop(
                      amount: amt,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.ok,
                          content: Text('Interim cash drop of ${CurrencyFormatter.formatNaira(amt)} submitted to Cashier.'),
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
  }

  void _openLogPosDialog() {
    String channel = 'pos_card';
    final amountCtrl = TextEditingController();
    final terminalCtrl = TextEditingController(text: 'Moniepoint POS 1');
    final refCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.point_of_sale, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Text('Log In-Between POS / Transfer Sale', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Record card swipe or customer bank transfer directly at pump (§4.4).',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: channel,
                        decoration: const InputDecoration(
                          labelText: 'Payment Channel *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pos_card', child: Text('POS Card Payment (Debit Card)')),
                          DropdownMenuItem(value: 'pos_transfer', child: Text('POS Transfer (Terminal Dynamic Account)')),
                          DropdownMenuItem(value: 'bank_transfer', child: Text('Direct Station Bank Transfer')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDlgState(() => channel = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount Paid (₦) *',
                          hintText: 'e.g. 25,000',
                          prefixText: '₦ ',
                          border: OutlineInputBorder(),
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
                                labelText: channel == 'bank_transfer' ? 'Bank Account / Name' : 'POS Terminal Name *',
                                hintText: channel == 'bank_transfer' ? 'Zenith Station Acc' : 'Moniepoint POS 1',
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
                                border: OutlineInputBorder(),
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
                          border: OutlineInputBorder(),
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
                    final amt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount.'),
                          backgroundColor: AppColors.bad,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await state.recordPosTransaction(
                      paymentChannel: channel,
                      amount: amt,
                      terminalName: terminalCtrl.text.trim().isEmpty ? null : terminalCtrl.text.trim(),
                      referenceNumber: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                      customerVehicle: vehicleCtrl.text.trim().isEmpty ? null : vehicleCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.ok,
                          content: Text('POS sale of ${CurrencyFormatter.formatNaira(amt)} logged successfully.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save Transaction'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nozzles = state.nozzles;
    final unconfirmedCount = nozzles.where((n) => !n.isOpeningConfirmed).length;
    final hasClosingEntered = nozzles.any((n) => n.closingReading != null);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendant Forecourt Home', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${widget.user.displayName} · Morning Shift · Lekki Road',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Forecourt Network, Hardware, and Offline Sync Outbox status
          const ForecourtSyncBar(stationName: 'Lekki Road Station · Island 1'),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${widget.user.displayName.split(" ")[0]}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Carry-forward opening readings & shift operations (BRD §2.5).',
                                style: TextStyle(fontSize: 13, color: AppColors.slate),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Text(
                              'PMS: ${CurrencyFormatter.formatNaira(state.pmsPrice)}/L | AGO: ${CurrencyFormatter.formatNaira(state.agoPrice)}/L',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Assigned Nozzles Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 600;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: nozzles.map((nozzle) {
                              return SizedBox(
                                width: isNarrow ? double.infinity : (constraints.maxWidth - 24) / 3,
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                            InkWell(
                                              onTap: nozzle.isOpeningConfirmed
                                                  ? null
                                                  : () => _confirmNozzle(nozzle.nozzleNumber),
                                              child: StatusChip(
                                                label: nozzle.isOpeningConfirmed
                                                    ? 'Confirmed'
                                                    : 'Confirm opening',
                                                type: nozzle.isOpeningConfirmed
                                                    ? ChipType.ok
                                                    : ChipType.warn,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Opening: ${CurrencyFormatter.formatLitres(nozzle.openingReading)} · Tank ${nozzle.tankCode}',
                                          style: const TextStyle(fontSize: 13, color: AppColors.slate),
                                        ),
                                        if (nozzle.closingReading != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Closing: ${CurrencyFormatter.formatLitres(nozzle.closingReading!)} (Sold: ${CurrencyFormatter.formatLitres(nozzle.litresSold)})',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ok),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      // Forecourt Pouch & Intra-Shift Collections Card (§2.6, §4.1, §4.4)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: state.attendantEstimatedCashInPouch > 150000
                                ? AppColors.amber.withOpacity(0.5)
                                : AppColors.border,
                            width: state.attendantEstimatedCashInPouch > 150000 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.ok.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.account_balance_wallet, color: AppColors.ok, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Forecourt Pouch & Intra-Shift Ledger',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                          ),
                                          Text(
                                            'In-between sales cash drops & POS card/transfer logger (§2.6, §4.4)',
                                            style: TextStyle(fontSize: 12, color: AppColors.slate),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (state.attendantEstimatedCashInPouch > 150000)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppColors.amber),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.amber),
                                          SizedBox(width: 4),
                                          Text(
                                            'High Cash in Pouch',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.amber),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Quick metrics grid
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 600;
                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _buildPouchMetricBox(
                                        'Est. Cash in Pouch',
                                        CurrencyFormatter.formatNaira(state.attendantEstimatedCashInPouch),
                                        state.attendantEstimatedCashInPouch > 150000 ? AppColors.amber : AppColors.ok,
                                        Icons.payments,
                                        isMobile ? (constraints.maxWidth - 10) / 2 : (constraints.maxWidth - 30) / 4,
                                      ),
                                      _buildPouchMetricBox(
                                        'Cash Dropped to Cashier',
                                        CurrencyFormatter.formatNaira(state.totalAttendantAcknowledgedDrops(widget.user.id)),
                                        AppColors.primary,
                                        Icons.archive_outlined,
                                        isMobile ? (constraints.maxWidth - 10) / 2 : (constraints.maxWidth - 30) / 4,
                                        subtitle: state.totalAttendantPendingDrops(widget.user.id) > 0
                                            ? '+${CurrencyFormatter.formatNaira(state.totalAttendantPendingDrops(widget.user.id))} pending'
                                            : 'All acknowledged',
                                      ),
                                      _buildPouchMetricBox(
                                        'POS / Card Slips',
                                        CurrencyFormatter.formatNaira(state.totalAttendantPosCard(widget.user.id)),
                                        const Color(0xFF6366F1),
                                        Icons.credit_card,
                                        isMobile ? (constraints.maxWidth - 10) / 2 : (constraints.maxWidth - 30) / 4,
                                      ),
                                      _buildPouchMetricBox(
                                        'Transfers Logged',
                                        CurrencyFormatter.formatNaira(state.totalAttendantPosTransfer(widget.user.id) + state.totalAttendantBankTransfer(widget.user.id)),
                                        const Color(0xFF0284C7),
                                        Icons.swap_horiz,
                                        isMobile ? (constraints.maxWidth - 10) / 2 : (constraints.maxWidth - 30) / 4,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Intra-shift Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _openCashDropDialog,
                                      icon: const Icon(Icons.arrow_circle_up, size: 18),
                                      label: const Text('Drop Cash to Cashier'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.ok,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _openLogPosDialog,
                                      icon: const Icon(Icons.point_of_sale, size: 18),
                                      label: const Text('Log POS / Bank Transfer'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Recent Drops & POS Slips Activity
                              if (state.cashDrops.where((d) => d.attendantId == widget.user.id).isNotEmpty ||
                                  state.posTransactions.where((p) => p.attendantId == widget.user.id).isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                const Text(
                                  "Today's Shift Submissions & POS Slips:",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate),
                                ),
                                const SizedBox(height: 8),
                                ...state.cashDrops
                                    .where((d) => d.attendantId == widget.user.id)
                                    .take(3)
                                    .map((drop) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.arrow_upward, size: 14, color: AppColors.ok),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Cash Drop: ${CurrencyFormatter.formatNaira(drop.amount)}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                                            ),
                                            if (drop.notes != null) ...[
                                              const SizedBox(width: 6),
                                              Text('(${drop.notes})', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                            ],
                                          ],
                                        ),
                                        StatusChip(
                                          label: drop.isAcknowledged ? 'Acknowledged' : 'Awaiting Cashier',
                                          type: drop.isAcknowledged ? ChipType.ok : ChipType.warn,
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                ...state.posTransactions
                                    .where((p) => p.attendantId == widget.user.id)
                                    .take(3)
                                    .map((pos) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.credit_card, size: 14, color: Color(0xFF6366F1)),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${pos.channelDisplayName}: ${CurrencyFormatter.formatNaira(pos.amount)}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                                            ),
                                            if (pos.referenceNumber != null) ...[
                                              const SizedBox(width: 6),
                                              Text('Ref: ${pos.referenceNumber}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          pos.terminalName ?? 'POS',
                                          style: const TextStyle(fontSize: 12, color: AppColors.slate, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Shift Checklist Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Shift Operational Checklist',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              const Divider(color: AppColors.border),
                              _buildChecklistRow(
                                'Confirm opening readings',
                                unconfirmedCount == 0
                                    ? const StatusChip(label: 'All Confirmed', type: ChipType.ok)
                                    : StatusChip(label: '$unconfirmedCount left to confirm', type: ChipType.warn),
                              ),
                              _buildChecklistRow(
                                'Submit closing readings',
                                hasClosingEntered
                                    ? const StatusChip(label: 'Entered (Ready)', type: ChipType.ok)
                                    : const StatusChip(label: 'Not started', type: ChipType.draft),
                              ),
                              _buildChecklistRow(
                                'Submit remittance declaration',
                                const StatusChip(label: '4 Channels', type: ChipType.draft),
                              ),
                              _buildChecklistRow(
                                'Active credit customers',
                                Text(
                                  '${state.creditCustomers.where((c) => c.outstanding > 0).length}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.speed, size: 20, color: Colors.white),
                onPressed: widget.onOpenClosingReadings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                label: const Text('Enter Closing Readings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long, size: 18, color: AppColors.ink),
                onPressed: widget.onOpenRemittance,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                label: const Text('Remittance', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onLogout,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistRow(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          trailing,
        ],
      ),
    );
  }

  Widget _buildPouchMetricBox(
    String label,
    String value,
    Color color,
    IconData icon,
    double width, {
    String? subtitle,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
