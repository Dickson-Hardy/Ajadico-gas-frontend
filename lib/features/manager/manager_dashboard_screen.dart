import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/status_chip.dart';

class ManagerDashboardScreen extends StatelessWidget {
  final VoidCallback onOpenVerificationQueue;
  final VoidCallback onOpenCashCount;
  final VoidCallback onOpenCreditCustomers;
  final VoidCallback onLogout;

  const ManagerDashboardScreen({
    super.key,
    required this.onOpenVerificationQueue,
    required this.onOpenCashCount,
    required this.onOpenCreditCustomers,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manager Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Branch Manager · Lekki Road · Today', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Credit Customers',
            onPressed: onOpenCreditCustomers,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: onLogout,
          ),
        ],
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
                  'Today at Lekki Road',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Status of both shifts and what needs your attention.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // KPI Metric Tiles
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 24) / 3;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildKpiCard('PMS sold', '6,420 L', itemWidth),
                        _buildKpiCard('AGO sold', '2,150 L', itemWidth),
                        _buildKpiCard('Sales value', '₦9.58M', itemWidth),
                        _buildKpiCard('Credit given', '₦620,000', itemWidth),
                        _buildKpiCard('Expenses', '₦145,000', itemWidth),
                        _buildKpiCard('Deposits pending', '₦1.5M', itemWidth),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // 2 Operational Summary Cards: Needs Attention & Shift Status
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Needs attention
                        Expanded(
                          flex: isNarrow ? 0 : 1,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Needs attention',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildActionRow('Submissions to verify', const StatusChip(label: '3', type: ChipType.warn)),
                                  _buildActionRow('Unresolved differences', const StatusChip(label: '1', type: ChipType.bad)),
                                  _buildActionRow('Tank T2 dip vs calculated', const StatusChip(label: '−120 L', type: ChipType.bad)),
                                  _buildActionRow('Low stock: AGO T3', const StatusChip(label: 'Low', type: ChipType.warn)),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (!isNarrow) const SizedBox(width: 16),

                        // Shifts
                        Expanded(
                          flex: isNarrow ? 0 : 1,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Shifts',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildActionRow('Morning', const StatusChip(label: 'Verified', type: ChipType.ok)),
                                  _buildActionRow('Afternoon / evening', const StatusChip(label: 'In progress', type: ChipType.warn)),
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
                onPressed: onOpenVerificationQueue,
                child: const Text('Verification queue'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onOpenCashCount,
                child: const Text('Cash count'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delivery log form: Waybill & tank before/after dip entry')),
                  );
                },
                child: const Text('Record delivery'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(String label, Widget chip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
          chip,
        ],
      ),
    );
  }
}
