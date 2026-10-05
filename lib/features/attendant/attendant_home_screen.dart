import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/nozzle.dart';
import '../../models/user_profile.dart';

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
  late List<NozzleItem> _nozzles;

  @override
  void initState() {
    super.initState();
    _nozzles = NozzleItem.getDemoNozzles();
  }

  void _confirmNozzle(int index) {
    setState(() {
      _nozzles[index].isOpeningConfirmed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nozzle ${_nozzles[index].nozzleNumber} opening reading confirmed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unconfirmedCount = _nozzles.where((n) => !n.isOpeningConfirmed).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendant Home', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${widget.user.displayName} · Morning shift · Lekki Road',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, ${widget.user.displayName.split(" ")[0]}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your nozzles and what is left to submit.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // Assigned Nozzles Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _nozzles.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final nozzle = entry.value;
                        return SizedBox(
                          width: isNarrow ? double.infinity : (constraints.maxWidth - 24) / 3,
                          child: Card(
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
                                      GestureDetector(
                                        onTap: nozzle.isOpeningConfirmed
                                            ? null
                                            : () => _confirmNozzle(idx),
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
                                    'Opening ${CurrencyFormatter.formatLitres(nozzle.openingReading)} · Tank ${nozzle.tankCode}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // Shift Progress Checklist Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This shift',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        const Divider(color: AppColors.line),
                        _buildChecklistRow(
                          'Confirm opening readings',
                          unconfirmedCount == 0
                              ? const StatusChip(label: 'All Confirmed', type: ChipType.ok)
                              : StatusChip(label: '$unconfirmedCount left', type: ChipType.warn),
                        ),
                        _buildChecklistRow(
                          'Submit closing readings',
                          const StatusChip(label: 'Not started', type: ChipType.draft),
                        ),
                        _buildChecklistRow(
                          'Submit remittance',
                          const StatusChip(label: 'Not started', type: ChipType.draft),
                        ),
                        _buildChecklistRow(
                          'Credit entries today',
                          const Text(
                            '2',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
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
                onPressed: widget.onOpenClosingReadings,
                child: const Text('Submit closing readings'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onOpenRemittance,
                child: const Text('Remittance'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onLogout,
                child: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistRow(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, color: AppColors.ink),
          ),
          trailing,
        ],
      ),
    );
  }
}
