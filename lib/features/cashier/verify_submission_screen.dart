import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/interim_cash_drop.dart';
import '../../models/pos_transaction.dart';
import '../../state/station_app_state.dart';

class VerifySubmissionScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onVerified;
  final VoidCallback? onOpenExpenseEntry;

  const VerifySubmissionScreen({
    super.key,
    required this.onBack,
    required this.onVerified,
    this.onOpenExpenseEntry,
  });

  @override
  State<VerifySubmissionScreen> createState() => _VerifySubmissionScreenState();
}

class _VerifySubmissionScreenState extends State<VerifySubmissionScreen> {
  final state = StationAppState.instance;

  int _selectedSubmissionIndex = 0;
  bool _cashChecked = true;
  bool _posCardChecked = true;
  bool _posTransferChecked = true;
  bool _bankTransferChecked = true;
  bool _creditChecked = true;

  int _currentEvidenceIndex = 0;
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _acknowledgingDropIds = {};
  bool _showItemizedDrops = false;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _acknowledgeDrop(InterimCashDrop drop) async {
    setState(() => _acknowledgingDropIds.add(drop.id));
    try {
      final ok = await state.acknowledgeCashDrop(drop.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.ok,
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Accepted cash drop of ${CurrencyFormatter.formatNaira(drop.amount)} from ${drop.attendantName} into Cash Safe!',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.bad,
              behavior: SnackBarBehavior.floating,
              content: Text('Failed to acknowledge cash drop. Please retry.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bad,
            behavior: SnackBarBehavior.floating,
            content: Text('Error acknowledging drop: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _acknowledgingDropIds.remove(drop.id));
      }
    }
  }

  void _verify(ShiftSubmission sub) {
    state.verifyShiftSubmission(
      submissionId: sub.id,
      cashierComment: _commentController.text.trim().isEmpty
          ? 'Audited and verified against interim cash drops and POS printouts'
          : _commentController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Shift ${sub.id} verified! ${CurrencyFormatter.formatNaira(sub.cashDeclared)} recorded in station safe.',
        ),
      ),
    );

    widget.onVerified();
  }

  void _flagUnresolved(ShiftSubmission sub) {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Please add a comment explaining why this submission is unresolved.'),
        ),
      );
      return;
    }

    state.flagShiftUnresolved(
      submissionId: sub.id,
      cashierComment: _commentController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.bad,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Shift flagged as unresolved! Shortfall of ${CurrencyFormatter.formatVariance(sub.variance)} routed to Director salary ledger.',
        ),
      ),
    );

    widget.onVerified();
  }

  @override
  Widget build(BuildContext context) {
    final submissions = state.submissions;
    final pendingDrops = state.cashDrops.where((d) => !d.isAcknowledged).toList();
    final acknowledgedDropsToday = state.cashDrops.where((d) => d.isAcknowledged).toList();

    // If no submissions are in queue, show the Live Cash Drops Hub
    if (submissions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cashier Verification Queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${state.currentUser.displayName} · Station Cashier Booth', style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
          actions: [
            if (widget.onOpenExpenseEntry != null)
              IconButton(
                icon: const Icon(Icons.receipt_long),
                tooltip: 'Disburse / Record Safe Expense',
                onPressed: widget.onOpenExpenseEntry,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 950),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pending Cash Drops Banner
                  if (pendingDrops.isNotEmpty) ...[
                    _buildPendingDropsBanner(pendingDrops),
                    const SizedBox(height: 20),
                  ],

                  // Queue Empty Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.muted),
                          const SizedBox(height: 16),
                          const Text(
                            'No End-of-Shift Submissions in Queue',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Attendants currently dispensing fuel on the forecourt have not yet submitted their shift closures. Intra-shift cash drops can be received and acknowledged above at any time.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Today's Acknowledged Cash Drops Log
                  if (acknowledgedDropsToday.isNotEmpty) ...[
                    const Text(
                      'Today\'s Acknowledged Mid-Shift Drops (§2.6)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    const SizedBox(height: 10),
                    ...acknowledgedDropsToday.map((drop) => _buildAcknowledgedDropTile(drop)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final currentIndex = _selectedSubmissionIndex < submissions.length ? _selectedSubmissionIndex : 0;
    final sub = submissions[currentIndex];

    // Compute drops and pos transactions for this submission
    final subDrops = sub.cashDrops.isNotEmpty
        ? sub.cashDrops
        : state.cashDrops.where((d) => d.attendantId == sub.attendantId).toList();

    final ackDrops = subDrops.where((d) => d.isAcknowledged).toList();
    final ackDropsTotal = ackDrops.fold(0.0, (sum, d) => sum + d.amount);
    final finalCashInHand = sub.finalCashHandover > 0
        ? sub.finalCashHandover
        : (sub.cashDeclared >= ackDropsTotal ? sub.cashDeclared - ackDropsTotal : sub.cashDeclared);

    final subPosTransactions = sub.posTransactions.isNotEmpty
        ? sub.posTransactions
        : state.posTransactions.where((p) => p.attendantId == sub.attendantId).toList();

    final cardTxs = subPosTransactions.where((p) => p.paymentChannel == 'pos_card').toList();
    final posTransferTxs = subPosTransactions.where((p) => p.paymentChannel == 'pos_transfer').toList();
    final bankTransferTxs = subPosTransactions.where((p) => p.paymentChannel == 'bank_transfer').toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cashier Verification Queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Station Cashier Booth', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          if (widget.onOpenExpenseEntry != null)
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Disburse / Record Safe Expense',
              onPressed: widget.onOpenExpenseEntry,
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: Alignment.center,
            child: StatusChip(
              label: '${submissions.where((s) => s.status == "Pending Verification").length} Pending',
              type: ChipType.warn,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Pending Drops Banner if any attendant has pending drops
                if (pendingDrops.isNotEmpty) ...[
                  _buildPendingDropsBanner(pendingDrops),
                  const SizedBox(height: 16),
                ],

                // Submission Selector if multiple
                if (submissions.length > 1) ...[
                  Row(
                    children: [
                      const Text('Select shift to audit:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<int>(
                          value: currentIndex,
                          isExpanded: true,
                          items: submissions.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final s = entry.value;
                            return DropdownMenuItem(
                              value: idx,
                              child: Text('${s.attendantName} (${s.shiftType}) - Expected: ${CurrencyFormatter.formatNaira(s.expectedSalesValue)} [${s.status}]'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedSubmissionIndex = val;
                                _currentEvidenceIndex = 0;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Audit: ${sub.attendantName} (${sub.shiftType} Shift)',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    StatusChip(
                      label: sub.status,
                      type: sub.status == 'Verified'
                          ? ChipType.ok
                          : (sub.status == 'Flagged Unresolved' ? ChipType.bad : ChipType.warn),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Audit physical cash (interim sweeps + final handoff) and verify card/transfer receipts against POS slips before confirming (§4.2).',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Entered Numbers & Verification Checkboxes
                        Expanded(
                          flex: isNarrow ? 0 : 6,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '1. Meter readings breakdown',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 10),
                                  ...sub.nozzles.map((n) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Nozzle ${n.nozzleNumber} (${n.productName})', style: const TextStyle(color: AppColors.muted)),
                                          Text(
                                            '${CurrencyFormatter.formatLitres(n.openingReading)} → ${CurrencyFormatter.formatLitres(n.closingReading ?? n.openingReading)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  const Divider(color: AppColors.line),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Target Expected Sales', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        CurrencyFormatter.formatNaira(sub.expectedSalesValue),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  const Text(
                                    '2. Check off physical money & proof',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 8),

                                  // Cash Tile with Itemized Interim Drops Sub-Card
                                  _buildCheckTile(
                                    'Physical Drawer Cash',
                                    sub.cashDeclared,
                                    _cashChecked,
                                    (v) => setState(() => _cashChecked = v!),
                                  ),

                                  // Sub-breakdown of cash: Drops + Final Handover
                                  Container(
                                    margin: const EdgeInsets.only(left: 36, bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.line),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '• Intra-Shift Sweeps (${ackDrops.length} drops):',
                                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                            ),
                                            Text(
                                              CurrencyFormatter.formatNaira(ackDropsTotal),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ok),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              '• Final Cash Handover at Close:',
                                              style: TextStyle(fontSize: 12, color: AppColors.muted),
                                            ),
                                            Text(
                                              CurrencyFormatter.formatNaira(finalCashInHand),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink),
                                            ),
                                          ],
                                        ),
                                        if (ackDrops.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => setState(() => _showItemizedDrops = !_showItemizedDrops),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _showItemizedDrops ? Icons.expand_less : Icons.expand_more,
                                                  size: 16,
                                                  color: AppColors.brandPrimary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _showItemizedDrops ? 'Hide itemized drop log' : 'View itemized drop log',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.brandPrimary, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_showItemizedDrops) ...[
                                            const SizedBox(height: 6),
                                            ...ackDrops.map((d) => Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    '  - ${_formatTime(d.createdAt)} (${d.notes ?? "Sweep"}):',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                                  ),
                                                  Text(
                                                    CurrencyFormatter.formatNaira(d.amount),
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            )),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),

                                  _buildCheckTile(
                                    'POS Card Swipes (${cardTxs.length} slips)',
                                    sub.posCardDeclared,
                                    _posCardChecked,
                                    (v) => setState(() => _posCardChecked = v!),
                                  ),
                                  _buildCheckTile(
                                    'POS Terminal Transfer (${posTransferTxs.length} slips)',
                                    sub.posTransferDeclared,
                                    _posTransferChecked,
                                    (v) => setState(() => _posTransferChecked = v!),
                                  ),
                                  _buildCheckTile(
                                    'Company Bank Direct Transfer (${bankTransferTxs.length} slips)',
                                    sub.bankTransferDeclared,
                                    _bankTransferChecked,
                                    (v) => setState(() => _bankTransferChecked = v!),
                                  ),
                                  _buildCheckTile(
                                    'Credit Sales on signed requisition',
                                    sub.creditSalesDeclared,
                                    _creditChecked,
                                    (v) => setState(() => _creditChecked = v!),
                                  ),
                                  const Divider(color: AppColors.line),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Shift Variance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      Text(
                                        CurrencyFormatter.formatVariance(sub.variance),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: sub.variance < 0 ? AppColors.bad : (sub.variance > 0 ? AppColors.ok : AppColors.ink),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (!isNarrow) const SizedBox(width: 16),

                        // Right: In-Shift POS Slips & Evidence Photos & Remarks
                        Expanded(
                          flex: isNarrow ? 0 : 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 3. In-Shift Digital POS Slips Audit
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            '3. In-Shift POS & Transfer Slips',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppColors.line),
                                            ),
                                            child: Text(
                                              '${subPosTransactions.length} slips',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (subPosTransactions.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.line),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.info_outline, size: 20, color: AppColors.muted),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'No individual POS slips logged in-between sales for this shift. Check physical thermal roll printouts.',
                                                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxHeight: 220),
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            itemCount: subPosTransactions.length,
                                            separatorBuilder: (_, __) => const Divider(height: 8, color: AppColors.line),
                                            itemBuilder: (context, idx) {
                                              final tx = subPosTransactions[idx];
                                              return _buildPosSlipAuditItem(tx);
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // 4. Uploaded Evidence Slips & Comments
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '4. Uploaded evidence slips',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        height: 140,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.line),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.receipt_long, size: 36, color: AppColors.bank),
                                              const SizedBox(height: 8),
                                              Text(
                                                sub.evidencePhotos.isNotEmpty
                                                    ? sub.evidencePhotos[_currentEvidenceIndex % sub.evidencePhotos.length]
                                                    : 'No evidence photo uploaded',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Proof ${_currentEvidenceIndex + 1} of ${sub.evidencePhotos.isEmpty ? 1 : sub.evidencePhotos.length}',
                                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (sub.evidencePhotos.length > 1) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: _currentEvidenceIndex > 0
                                                    ? () => setState(() => _currentEvidenceIndex--)
                                                    : null,
                                                child: const Text('Previous'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: _currentEvidenceIndex < sub.evidencePhotos.length - 1
                                                    ? () => setState(() => _currentEvidenceIndex++)
                                                    : null,
                                                child: const Text('Next'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 16),

                                      const Text('Cashier remarks / comments', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _commentController,
                                        decoration: const InputDecoration(
                                          hintText: 'Enter audit notes or shortage reason...',
                                        ),
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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
                icon: const Icon(Icons.check),
                onPressed: sub.status == 'Verified' ? null : () => _verify(sub),
                label: Text(sub.status == 'Verified' ? 'Already Verified' : 'Verify & accept into safe'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.bad),
                icon: const Icon(Icons.flag),
                onPressed: sub.status == 'Verified' ? null : () => _flagUnresolved(sub),
                label: const Text('Flag difference'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner showing pending mid-shift cash drops with one-tap cashier acknowledgement
  Widget _buildPendingDropsBanner(List<InterimCashDrop> pendingDrops) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warn.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warn.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.warn, size: 22),
              const SizedBox(width: 8),
              Text(
                'Incoming Intra-Shift Cash Drops (${pendingDrops.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Attendants on the forecourt have submitted cash to reduce pouch robbery/loss risk. Count physical notes and accept below:',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          ...pendingDrops.map((drop) {
            final isAcknowledging = _acknowledgingDropIds.contains(drop.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.ok.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: AppColors.ok, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${drop.attendantName} — ${CurrencyFormatter.formatNaira(drop.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Submitted at ${_formatTime(drop.createdAt)}${drop.notes != null ? " • ${drop.notes}" : ""}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ok,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: isAcknowledging ? null : () => _acknowledgeDrop(drop),
                    child: isAcknowledging
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Accept Cash'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Tile showing an acknowledged cash drop
  Widget _buildAcknowledgedDropTile(InterimCashDrop drop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.ok, size: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${drop.attendantName} • ${drop.notes ?? "Mid-shift sweep"}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                  ),
                  Text(
                    'Accepted at ${drop.acknowledgedAt != null ? _formatTime(drop.acknowledgedAt!) : _formatTime(drop.createdAt)} by ${drop.acknowledgedBy ?? "Cashier"}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          Text(
            CurrencyFormatter.formatNaira(drop.amount),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ok),
          ),
        ],
      ),
    );
  }

  /// List item displaying a single logged POS card / transfer transaction
  Widget _buildPosSlipAuditItem(PosTransaction tx) {
    IconData icon;
    Color iconColor;
    switch (tx.paymentChannel) {
      case 'pos_card':
        icon = Icons.credit_card;
        iconColor = AppColors.brandPrimary;
        break;
      case 'pos_transfer':
        icon = Icons.phonelink_ring;
        iconColor = AppColors.warn;
        break;
      case 'bank_transfer':
        icon = Icons.account_balance;
        iconColor = AppColors.bank;
        break;
      default:
        icon = Icons.payment;
        iconColor = AppColors.brandPrimary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tx.channelDisplayName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    Text(
                      CurrencyFormatter.formatNaira(tx.amount),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ok),
                    ),
                  ],
                ),
                Text(
                  '${tx.terminalName ?? "POS"} • Ref: ${tx.referenceNumber ?? "N/A"}${tx.customerVehicle != null ? " • Plate: ${tx.customerVehicle}" : ""} • ${_formatTime(tx.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckTile(String label, double amount, bool isChecked, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      value: isChecked,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
      secondary: Text(
        CurrencyFormatter.formatNaira(amount),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
