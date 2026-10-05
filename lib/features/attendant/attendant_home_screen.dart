import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                          'Your assigned nozzles and shift checklist.',
                          style: TextStyle(fontSize: 15, color: AppColors.muted),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PMS: ${CurrencyFormatter.formatNaira(state.pmsPrice)}/L | AGO: ${CurrencyFormatter.formatNaira(state.agoPrice)}/L',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
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
                                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
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

                const SizedBox(height: 12),

                // Shift Checklist Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This shift status',
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
                              : StatusChip(label: '$unconfirmedCount left to confirm', type: ChipType.warn),
                        ),
                        _buildChecklistRow(
                          'Submit closing readings',
                          hasClosingEntered
                              ? const StatusChip(label: 'Entered (Ready)', type: ChipType.ok)
                              : const StatusChip(label: 'Not started', type: ChipType.draft),
                        ),
                        _buildChecklistRow(
                          'Submit remittance',
                          const StatusChip(label: 'Pending', type: ChipType.draft),
                        ),
                        _buildChecklistRow(
                          'Credit sales recorded',
                          Text(
                            '${state.creditCustomers.where((c) => c.outstanding > 0).length}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
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
              child: ElevatedButton.icon(
                icon: const Icon(Icons.speed, size: 20),
                onPressed: widget.onOpenClosingReadings,
                label: const Text('Enter closing readings'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long, size: 18),
                onPressed: widget.onOpenRemittance,
                label: const Text('Remittance'),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
          trailing,
        ],
      ),
    );
  }
}
