import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

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
  bool _cashChecked = true;
  bool _posCardChecked = true;
  bool _bankTransferChecked = false;
  bool _creditChecked = true;

  int _currentEvidenceIndex = 1;
  final int _totalEvidence = 3;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _verify() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.ok,
        content: Text('Shift submission successfully verified.'),
      ),
    );
    widget.onVerified();
  }

  void _flagUnresolved() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.bad,
        content: Text('Submission flagged as unresolved. Added to manager queue & salary adjustment record.'),
      ),
    );
    widget.onVerified();
  }

  void _returnToAttendant() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Submission returned to attendant Amaka O. for correction.'),
      ),
    );
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verify Submission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Cashier · Chidi E.', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify: Amaka O., Morning shift',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Check each figure against its evidence, then verify or flag.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Entered Figures & Payments
                        Expanded(
                          flex: isNarrow ? 0 : 6,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Entered figures',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildReadingRow('Nozzle 1 PMS', '412,380.5 → 413,102.0'),
                                  _buildReadingRow('Nozzle 3 AGO', '201,775.5 → 202,198.0'),
                                  _buildReadingRow('Expected value', '₦1,250,000', isBold: true),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Payments',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCheckboxTile('Cash', '₦640,000', _cashChecked, (v) => setState(() => _cashChecked = v!)),
                                  _buildCheckboxTile('POS card', '₦310,000', _posCardChecked, (v) => setState(() => _posCardChecked = v!)),
                                  _buildCheckboxTile('Bank transfer', '₦120,000', _bankTransferChecked, (v) => setState(() => _bankTransferChecked = v!)),
                                  _buildCheckboxTile('Credit (2 entries)', '₦180,000', _creditChecked, (v) => setState(() => _creditChecked = v!)),
                                  const Divider(color: AppColors.line),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Difference', style: TextStyle(fontSize: 16, color: AppColors.ink)),
                                      Text(
                                        '₦0',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.ink,
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

                        // Right Column: Evidence & Comment
                        Expanded(
                          flex: isNarrow ? 0 : 5,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Evidence',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
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
                                            'POS printout $_currentEvidenceIndex of $_totalEvidence',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                                          ),
                                          const Text(
                                            'Terminal: POS-01 · ₦310,000',
                                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _currentEvidenceIndex > 1
                                              ? () => setState(() => _currentEvidenceIndex--)
                                              : null,
                                          child: const Text('Previous'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _currentEvidenceIndex < _totalEvidence
                                              ? () => setState(() => _currentEvidenceIndex++)
                                              : null,
                                          child: const Text('Next'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Comment', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _commentController,
                                    decoration: const InputDecoration(
                                      hintText: 'Add cashier remarks...',
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
              child: ElevatedButton(
                onPressed: _verify,
                child: const Text('Verify'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.bad),
                onPressed: _flagUnresolved,
                child: const Text('Flag unresolved'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _returnToAttendant,
                child: const Text('Return to attendant'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingRow(String title, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: isBold ? AppColors.ink : AppColors.muted, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile(String label, String amount, bool value, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
      secondary: Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
