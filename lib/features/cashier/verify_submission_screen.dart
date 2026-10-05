import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';

class VerifySubmissionScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onVerified;

  const VerifySubmissionScreen({
    super.key,
    required this.onBack,
    required this.onVerified,
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

  void _verify(ShiftSubmission sub) {
    state.verifyShiftSubmission(
      submissionId: sub.id,
      cashierComment: _commentController.text.trim().isEmpty
          ? 'Audited and verified against POS printouts'
          : _commentController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ok,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Shift ${sub.id} verified! ${CurrencyFormatter.formatNaira(sub.cashDeclared)} added to cash drawer.',
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

    if (submissions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verify Submissions')),
        body: const Center(
          child: Text('No shift submissions waiting in verification queue.'),
        ),
      );
    }

    final currentIndex = _selectedSubmissionIndex < submissions.length ? _selectedSubmissionIndex : 0;
    final sub = submissions[currentIndex];

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
                  'Check declared cash in hand and compare card/transfer lines against POS slips before confirming (§4.2).',
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
                                  _buildCheckTile('Physical Drawer Cash', sub.cashDeclared, _cashChecked, (v) => setState(() => _cashChecked = v!)),
                                  _buildCheckTile('POS Card Swipes', sub.posCardDeclared, _posCardChecked, (v) => setState(() => _posCardChecked = v!)),
                                  _buildCheckTile('POS Terminal Account Transfer', sub.posTransferDeclared, _posTransferChecked, (v) => setState(() => _posTransferChecked = v!)),
                                  _buildCheckTile('Company Bank Direct Transfer', sub.bankTransferDeclared, _bankTransferChecked, (v) => setState(() => _bankTransferChecked = v!)),
                                  _buildCheckTile('Credit Sales on signed requisition', sub.creditSalesDeclared, _creditChecked, (v) => setState(() => _creditChecked = v!)),
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

                        // Right: Uploaded Evidence Slips & Comments
                        Expanded(
                          flex: isNarrow ? 0 : 5,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '3. Uploaded evidence slips',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 160,
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
                                          const Icon(Icons.receipt_long, size: 40, color: AppColors.bank),
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
                                            'Proof ${_currentEvidenceIndex + 1} of ${sub.evidencePhotos.length}',
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
