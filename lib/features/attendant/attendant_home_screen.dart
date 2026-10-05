import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
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
}
