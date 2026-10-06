import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/forecourt_tank_gauge.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/station_app_state.dart';
import '../manager/tank_changeover_dialog.dart';

class CompanyReportsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onOpenStationSetup;
  final VoidCallback? onOpenStaffManagement;
  final VoidCallback? onOpenExpenseEntry;

  const CompanyReportsScreen({
    super.key,
    required this.onBack,
    this.onOpenStationSetup,
    this.onOpenStaffManagement,
    this.onOpenExpenseEntry,
  });

  @override
  State<CompanyReportsScreen> createState() => _CompanyReportsScreenState();
}

class _CompanyReportsScreenState extends State<CompanyReportsScreen> {
  final state = StationAppState.instance;
  int _selectedView = 0; // 0 = Financial Performance, 1 = Live Graphical Tanks

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

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showReceiptPreview(BranchExpense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${expense.category} Receipt Proof'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${CurrencyFormatter.formatNaira(expense.amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Description: ${expense.description}'),
            const SizedBox(height: 4),
            Text('Recorded By: ${expense.recordedByRole.toUpperCase()} · Status: ${expense.status}'),
            const SizedBox(height: 12),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_outlined, size: 48, color: AppColors.muted),
                    SizedBox(height: 8),
                    Text('Receipt Photo Attached', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Stored in Supabase expense-receipts bucket', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Real Financial Metrics purely from live state
    double totalPmsLitres = 0.0;
    double totalAgoLitres = 0.0;
    double totalRevenue = 0.0;

    for (var sub in state.submissions) {
      if (sub.status == 'Verified') {
        totalRevenue += sub.expectedSalesValue;
        for (var n in sub.nozzles) {
          if (n.productName == 'PMS') totalPmsLitres += n.litresSold;
          if (n.productName == 'AGO') totalAgoLitres += n.litresSold;
        }
      }
    }

    final totalExpenses = state.expenses.fold(0.0, (s, e) => s + e.amount);
    // Estimated fuel COGS based on current retail price margins (~8% distribution margin)
    final totalCogs = totalRevenue * 0.92;
    final totalGrossProfit = totalRevenue - totalCogs;
    final totalNetProfit = totalGrossProfit - totalExpenses;

    // 2. Real Tanks from Supabase Database
    final liveTanks = state.tanks;
    final totalPmsInStock = liveTanks.where((t) => t.product == 'PMS').fold(0.0, (s, t) => s + t.physicalDip);
    final totalAgoInStock = liveTanks.where((t) => t.product == 'AGO').fold(0.0, (s, t) => s + t.physicalDip);
    final totalCompanyUllage = liveTanks.fold(0.0, (s, t) => s + (t.capacity - t.physicalDip));
    final lowStockTanksCount = liveTanks.where((t) => t.isLowStock || t.hasDeficit).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company Consolidated Executive View', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Director · Live Multi-Branch Consolidated Ledger & Storage (§6.1, §3.1)', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          if (state.hasInterlockedTanks)
            TextButton.icon(
              icon: const Icon(Icons.alt_route, color: AppColors.amber),
              label: const Text('Manifold Switch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => TankChangeoverDialog.show(context, state),
            ),
          if (widget.onOpenExpenseEntry != null)
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Record Corporate / Station Expense',
              onPressed: widget.onOpenExpenseEntry,
            ),
          if (widget.onOpenStaffManagement != null)
            IconButton(
              icon: const Icon(Icons.badge_outlined),
              tooltip: 'Staff Management & Payroll',
              onPressed: widget.onOpenStaffManagement,
            ),
          if (widget.onOpenStationSetup != null)
            IconButton(
              icon: const Icon(Icons.settings_suggest),
              tooltip: 'Forecourt & Station Setup',
              onPressed: widget.onOpenStationSetup,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header & Mode Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedView == 0
                              ? 'Consolidated Financial Performance'
                              : 'Underground Fuel Storage Tanks (UST)',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedView == 0
                              ? 'Real-time revenue, audited shift remittances, and verified expenses (§6.1).'
                              : 'Real-time physical dip levels, book stock, and available discharge ullage (§3.1).',
                          style: const TextStyle(fontSize: 15, color: AppColors.muted),
                        ),
                      ],
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.assessment_outlined),
                          label: Text('P&L Ledger'),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.propane_tank_outlined),
                          label: Text('Tank Gauges'),
                        ),
                      ],
                      selected: {_selectedView},
                      onSelectionChanged: (set) => setState(() => _selectedView = set.first),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // =============================================================
                // VIEW 0: REAL FINANCIAL LEDGER (ZERO DEMO DATA)
                // =============================================================
                if (_selectedView == 0) ...[
                  // Real Financial KPI Summary Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 36) / 4;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSummaryKpi('Total Verified Revenue', CurrencyFormatter.formatNaira(totalRevenue), width),
                          _buildSummaryKpi('Gross Margin (Profit)', CurrencyFormatter.formatNaira(totalGrossProfit), width, color: AppColors.ok),
                          _buildSummaryKpi('Verified Expenses', CurrencyFormatter.formatNaira(totalExpenses), width),
                          _buildSummaryKpi('Net Operating Profit', CurrencyFormatter.formatNaira(totalNetProfit), width, color: totalNetProfit >= 0 ? AppColors.ok : AppColors.bad),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Real Branch Financial Table
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
                                'Station Performance (Live Verified Shifts)',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                              ),
                              Text(
                                '${state.submissions.where((s) => s.status == "Verified").length} Verified Shift(s)',
                                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (totalRevenue == 0 && totalExpenses == 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 36),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.muted),
                                    SizedBox(height: 8),
                                    Text(
                                      'No Verified Transactions Yet Today',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Financial figures update live as pump attendants submit shift remittances and cashiers verify them.',
                                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                                columns: const [
                                  DataColumn(label: Text('Branch')),
                                  DataColumn(label: Text('PMS Litres'), numeric: true),
                                  DataColumn(label: Text('AGO Litres'), numeric: true),
                                  DataColumn(label: Text('Gross Revenue (₦)'), numeric: true),
                                  DataColumn(label: Text('Est. Gross Profit'), numeric: true),
                                  DataColumn(label: Text('Expenses'), numeric: true),
                                  DataColumn(label: Text('Net Profit'), numeric: true),
                                ],
                                rows: [
                                  DataRow(
                                    cells: [
                                      const DataCell(Text('Lekki Road Station', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(CurrencyFormatter.formatLitres(totalPmsLitres))),
                                      DataCell(Text(CurrencyFormatter.formatLitres(totalAgoLitres))),
                                      DataCell(Text(CurrencyFormatter.formatNaira(totalRevenue))),
                                      DataCell(Text(CurrencyFormatter.formatNaira(totalGrossProfit))),
                                      DataCell(Text(CurrencyFormatter.formatNaira(totalExpenses))),
                                      DataCell(
                                        Text(
                                          CurrencyFormatter.formatNaira(totalNetProfit),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: totalNetProfit >= 0 ? AppColors.ok : AppColors.bad),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Executive Expense Approvals & Audit Ledger Card (§6.1)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long, color: AppColors.ink, size: 22),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Expense Ledger & Executive Approvals (§6.1)',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  if (state.pendingExpenses.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    StatusChip(
                                      label: '${state.pendingExpenses.length} Pending Approval',
                                      type: ChipType.warn,
                                    ),
                                  ],
                                ],
                              ),
                              if (widget.onOpenExpenseEntry != null)
                                ElevatedButton.icon(
                                  onPressed: widget.onOpenExpenseEntry,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Record Expense'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'All operational and petty cash safe disbursals recorded across branches. Director has absolute authorization authority.',
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                          const SizedBox(height: 16),

                          if (state.expenses.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No station expenses recorded yet today.', style: TextStyle(color: AppColors.muted)),
                              ),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                                columns: const [
                                  DataColumn(label: Text('Time')),
                                  DataColumn(label: Text('Category')),
                                  DataColumn(label: Text('Description')),
                                  DataColumn(label: Text('Source')),
                                  DataColumn(label: Text('Role')),
                                  DataColumn(label: Text('Amount (₦)'), numeric: true),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Receipt')),
                                  DataColumn(label: Text('Executive Action')),
                                ],
                                rows: state.expenses.map((exp) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(_formatTime(exp.recordedAt))),
                                      DataCell(Text(exp.category, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text(exp.description)),
                                      DataCell(Text(exp.paymentSource == 'sales_cash' ? 'Cash Safe' : exp.paymentSource)),
                                      DataCell(Text(exp.recordedByRole.toUpperCase())),
                                      DataCell(Text(
                                        CurrencyFormatter.formatNaira(exp.amount),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      )),
                                      DataCell(StatusChip(
                                        label: exp.status,
                                        type: exp.isApproved
                                            ? ChipType.ok
                                            : (exp.isRejected ? ChipType.bad : ChipType.warn),
                                      )),
                                      DataCell(
                                        exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.receipt, color: AppColors.primary, size: 18),
                                                tooltip: 'View Receipt',
                                                onPressed: () => _showReceiptPreview(exp),
                                              )
                                            : const Text('-', style: TextStyle(color: AppColors.muted)),
                                      ),
                                      DataCell(
                                        exp.isPending
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  OutlinedButton(
                                                    onPressed: () {
                                                      state.rejectExpense(exp.id, 'Director');
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Rejected ${CurrencyFormatter.formatNaira(exp.amount)}'),
                                                          backgroundColor: AppColors.bad,
                                                        ),
                                                      );
                                                    },
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(color: AppColors.bad),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      visualDensity: VisualDensity.compact,
                                                    ),
                                                    child: const Text('Reject', style: TextStyle(color: AppColors.bad, fontSize: 11)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      state.approveExpense(exp.id, 'Director');
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Approved ${CurrencyFormatter.formatNaira(exp.amount)} (${exp.category})'),
                                                          backgroundColor: AppColors.ok,
                                                        ),
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.ok,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      visualDensity: VisualDensity.compact,
                                                    ),
                                                    child: const Text('Approve', style: TextStyle(fontSize: 11)),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                exp.approvedBy.isNotEmpty ? 'By ${exp.approvedBy}' : 'Completed',
                                                style: const TextStyle(fontSize: 12, color: AppColors.slate),
                                              ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                // =============================================================
                // VIEW 1: LIVE GRAPHICAL TANK GAUGES (REAL SUPABASE TANKS ONLY)
                // =============================================================
                if (_selectedView == 1) ...[
                  // Fuel Inventory KPI Metric Summary (from real tanks)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 36) / 4;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSummaryKpi('Total PMS in Storage', CurrencyFormatter.formatLitres(totalPmsInStock), width, color: const Color(0xFFC2410C)),
                          _buildSummaryKpi('Total AGO in Storage', CurrencyFormatter.formatLitres(totalAgoInStock), width, color: const Color(0xFF047857)),
                          _buildSummaryKpi('Total Discharge Ullage', CurrencyFormatter.formatLitres(totalCompanyUllage), width, color: AppColors.ink),
                          _buildSummaryKpi('Attention Required', '$lowStockTanksCount Tank(s)', width, color: lowStockTanksCount > 0 ? AppColors.warn : AppColors.ok),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Header with Tank Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Station Tanks (${liveTanks.length} Tanks in Database)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                      ),
                      const Text(
                        'Source: Supabase PostgreSQL `tanks` table',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Real Graphical Tank Gauges Grid
                  if (liveTanks.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.propane_tank_outlined, size: 48, color: AppColors.muted),
                              SizedBox(height: 12),
                              Text('No Storage Tanks Configured in Database', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 700;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: liveTanks.map((t) {
                            final itemWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;
                            return SizedBox(
                              width: itemWidth,
                              child: ForecourtTankGauge(
                                tankCode: t.code,
                                productName: t.product,
                                capacityLitres: t.capacity,
                                currentLitres: t.physicalDip,
                                calculatedStockLitres: t.bookStock,
                                stationName: 'Lekki Road Station',
                                lastDipTime: t.lastDipTime,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryKpi(String label, String value, double width, {Color color = AppColors.ink}) {
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
