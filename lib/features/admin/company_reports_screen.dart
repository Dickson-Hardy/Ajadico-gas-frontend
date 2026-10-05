import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

class BranchReportItem {
  final String branchName;
  final double pmsLitres;
  final double agoLitres;
  final double grossRevenue;
  final double cogs;
  final double operatingExpenses;

  BranchReportItem({
    required this.branchName,
    required this.pmsLitres,
    required this.agoLitres,
    required this.grossRevenue,
    required this.cogs,
    required this.operatingExpenses,
  });

  double get grossProfit => grossRevenue - cogs;
  double get netProfit => grossProfit - operatingExpenses;
}

class CompanyReportsScreen extends StatelessWidget {
  final VoidCallback onBack;

  const CompanyReportsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final branches = [
      BranchReportItem(
        branchName: 'Lekki Road Station',
        pmsLitres: 142000,
        agoLitres: 48000,
        grossRevenue: 212500000,
        cogs: 191250000,
        operatingExpenses: 3450000,
      ),
      BranchReportItem(
        branchName: 'Ikeja Branch',
        pmsLitres: 125000,
        agoLitres: 39000,
        grossRevenue: 182730000,
        cogs: 164450000,
        operatingExpenses: 2890000,
      ),
      BranchReportItem(
        branchName: 'Victoria Island Station',
        pmsLitres: 168000,
        agoLitres: 62000,
        grossRevenue: 258240000,
        cogs: 232410000,
        operatingExpenses: 4120000,
      ),
      BranchReportItem(
        branchName: 'Surulere Station',
        pmsLitres: 98000,
        agoLitres: 24000,
        grossRevenue: 134580000,
        cogs: 121120000,
        operatingExpenses: 2150000,
      ),
      BranchReportItem(
        branchName: 'Ajah Terminal',
        pmsLitres: 110000,
        agoLitres: 31000,
        grossRevenue: 156420000,
        cogs: 140770000,
        operatingExpenses: 2680000,
      ),
    ];

    final totalRevenue = branches.fold(0.0, (s, b) => s + b.grossRevenue);
    final totalGrossProfit = branches.fold(0.0, (s, b) => s + b.grossProfit);
    final totalExpenses = branches.fold(0.0, (s, b) => s + b.operatingExpenses);
    final totalNetProfit = totalGrossProfit - totalExpenses;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company Consolidated Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Senior · 5 Branch Stations Consolidated P&L (§6.1, §6.4)', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
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
                  'Multi-branch profit & performance',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Consolidated monthly figures across all five stations (§6.1). Fuel inventory treated as stock on hand (§6.6).',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // Top KPI Summary Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 36) / 4;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildSummaryKpi('Total Company Revenue', CurrencyFormatter.formatNaira(totalRevenue), width),
                        _buildSummaryKpi('Gross Margin (Profit)', CurrencyFormatter.formatNaira(totalGrossProfit), width, color: AppColors.ok),
                        _buildSummaryKpi('Operating Expenses', CurrencyFormatter.formatNaira(totalExpenses), width),
                        _buildSummaryKpi('Net Operating Profit', CurrencyFormatter.formatNaira(totalNetProfit), width, color: AppColors.ok),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // 5 Stations Comparative Table
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Branch Breakdown (Current Month)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                            columns: const [
                              DataColumn(label: Text('Branch')),
                              DataColumn(label: Text('PMS Litres'), numeric: true),
                              DataColumn(label: Text('AGO Litres'), numeric: true),
                              DataColumn(label: Text('Revenue (₦)'), numeric: true),
                              DataColumn(label: Text('Gross Profit'), numeric: true),
                              DataColumn(label: Text('Expenses'), numeric: true),
                              DataColumn(label: Text('Net Profit'), numeric: true),
                            ],
                            rows: branches.map((b) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(b.branchName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(CurrencyFormatter.formatLitres(b.pmsLitres))),
                                  DataCell(Text(CurrencyFormatter.formatLitres(b.agoLitres))),
                                  DataCell(Text(CurrencyFormatter.formatNaira(b.grossRevenue))),
                                  DataCell(Text(CurrencyFormatter.formatNaira(b.grossProfit))),
                                  DataCell(Text(CurrencyFormatter.formatNaira(b.operatingExpenses))),
                                  DataCell(
                                    Text(
                                      CurrencyFormatter.formatNaira(b.netProfit),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ok),
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
