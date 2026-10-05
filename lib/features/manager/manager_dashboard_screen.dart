import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/forecourt_tank_gauge.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenVerificationQueue;
  final VoidCallback onOpenCashCount;
  final VoidCallback onOpenCreditCustomers;
  final VoidCallback? onOpenTankDip;
  final VoidCallback? onOpenFuelDelivery;
  final VoidCallback onLogout;

  const ManagerDashboardScreen({
    super.key,
    required this.onOpenVerificationQueue,
    required this.onOpenCashCount,
    required this.onOpenCreditCustomers,
    this.onOpenTankDip,
    this.onOpenFuelDelivery,
    required this.onLogout,
  });

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
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

  @override
  Widget build(BuildContext context) {
    // Dynamic KPI Aggregation
    double pmsSold = 6420.0;
    double agoSold = 2150.0;
    for (var n in state.nozzles) {
      if (n.productName == 'PMS') pmsSold += n.litresSold;
      if (n.productName == 'AGO') agoSold += n.litresSold;
    }

    final totalSalesValue = state.submissions.fold(0.0, (s, sub) => s + sub.expectedSalesValue);
    final totalCreditGiven = state.creditCustomers.fold(0.0, (s, c) => s + c.outstanding);
    final totalExpenses = state.expenses.fold(0.0, (s, e) => s + e.amount) + 145000.0;
    final totalDepositsPending = state.deposits.where((d) => !d.isConfirmed).fold(0.0, (s, d) => s + d.amount);

    final pendingVerifications = state.submissions.where((s) => s.status == 'Pending Verification').length;
    final unresolvedDifferences = state.submissions.where((s) => s.status == 'Flagged Unresolved').length + state.salaryAdjustments.where((a) => a.status == 'Pending Review').length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Branch Manager Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${state.currentUser.displayName} · Lekki Road Station · Today', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Credit Customers',
            onPressed: widget.onOpenCreditCustomers,
          ),
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
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today at Lekki Road',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Real-time operational status, forecourt exceptions, and cash movements.',
                          style: TextStyle(fontSize: 15, color: AppColors.muted),
                        ),
                      ],
                    ),
                    StatusChip(
                      label: pendingVerifications > 0 ? '$pendingVerifications Submissions Need Audit' : 'All Clear',
                      type: pendingVerifications > 0 ? ChipType.warn : ChipType.ok,
                    ),
                  ],
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
                        _buildKpiCard('PMS Sold', CurrencyFormatter.formatLitres(pmsSold), itemWidth),
                        _buildKpiCard('AGO Sold', CurrencyFormatter.formatLitres(agoSold), itemWidth),
                        _buildKpiCard('Sales Value', CurrencyFormatter.formatNaira(totalSalesValue > 0 ? totalSalesValue : 9580000), itemWidth, isGreen: true),
                        _buildKpiCard('Credit Given', CurrencyFormatter.formatNaira(totalCreditGiven), itemWidth),
                        _buildKpiCard('Expenses', CurrencyFormatter.formatNaira(totalExpenses), itemWidth),
                        _buildKpiCard('Deposits Pending', CurrencyFormatter.formatNaira(totalDepositsPending > 0 ? totalDepositsPending : 1500000), itemWidth, isBlue: true),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Graphical Underground Storage Tanks (UST) Real-Time Levels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Underground Fuel Tanks (UST)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Live physical dip levels, calculated book stock & tanker discharge ullage.',
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                      ],
                    ),
                    if (widget.onOpenTankDip != null)
                      OutlinedButton.icon(
                        onPressed: widget.onOpenTankDip,
                        icon: const Icon(Icons.straighten, size: 16),
                        label: const Text('Record Daily Dip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Visual Tank Gauge Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 750;
                    return isMobile
                        ? Column(
                            children: state.tanks.map((t) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ForecourtTankGauge(
                                  tankCode: t.code,
                                  productName: t.product,
                                  capacityLitres: t.capacity,
                                  currentLitres: t.physicalDip,
                                  calculatedStockLitres: t.bookStock,
                                  lastDipTime: t.lastDipTime,
                                  onTap: widget.onOpenTankDip,
                                ),
                              );
                            }).toList(),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: state.tanks.map((t) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: ForecourtTankGauge(
                                    tankCode: t.code,
                                    productName: t.product,
                                    capacityLitres: t.capacity,
                                    currentLitres: t.physicalDip,
                                    calculatedStockLitres: t.bookStock,
                                    lastDipTime: t.lastDipTime,
                                    onTap: widget.onOpenTankDip,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                  },
                ),
                const SizedBox(height: 20),

                // Operational Summary Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Needs attention
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
                                  _buildActionRow(
                                    'Submissions to verify',
                                    StatusChip(label: '$pendingVerifications', type: pendingVerifications > 0 ? ChipType.warn : ChipType.ok),
                                  ),
                                  _buildActionRow(
                                    'Unresolved differences',
                                    StatusChip(label: '$unresolvedDifferences', type: unresolvedDifferences > 0 ? ChipType.bad : ChipType.ok),
                                  ),
                                  ...state.tanks.where((t) => t.hasDeficit).map((t) {
                                    return _buildActionRow(
                                      'Tank ${t.code} dip vs calculated',
                                      StatusChip(label: '${t.variance.toStringAsFixed(0)} L', type: ChipType.bad),
                                    );
                                  }),
                                  ...state.tanks.where((t) => t.isLowStock).map((t) {
                                    return _buildActionRow(
                                      'Low stock: ${t.product} ${t.code}',
                                      const StatusChip(label: 'Low', type: ChipType.warn),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (!isNarrow) const SizedBox(width: 16),

                        // Right: Shifts Status
                        Expanded(
                          flex: isNarrow ? 0 : 1,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Shift operations',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildActionRow(
                                    'Morning Shift',
                                    StatusChip(
                                      label: pendingVerifications > 0 ? 'Verification Pending' : 'Verified & Locked',
                                      type: pendingVerifications > 0 ? ChipType.warn : ChipType.ok,
                                    ),
                                  ),
                                  _buildActionRow(
                                    'Afternoon / Evening Shift',
                                    const StatusChip(label: 'In progress', type: ChipType.warn),
                                  ),
                                  const Divider(color: AppColors.line),
                                  const Text(
                                    'Active Prices (Authorized by Director):',
                                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PMS: ${CurrencyFormatter.formatNaira(state.pmsPrice)}/L | AGO: ${CurrencyFormatter.formatNaira(state.agoPrice)}/L',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                icon: const Icon(Icons.playlist_add_check),
                onPressed: widget.onOpenVerificationQueue,
                label: const Text('Verification queue'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.point_of_sale),
                onPressed: widget.onOpenCashCount,
                label: const Text('Cash count'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, double width, {bool isGreen = false, bool isBlue = false}) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isGreen ? AppColors.ok : (isBlue ? AppColors.bank : AppColors.ink),
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
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          chip,
        ],
      ),
    );
  }
}
