import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';
import 'operations_workspace.dart';
import 'status_chip.dart';

/// Station sales and collection summary, with responsive operational actions.
class ExecutiveHeroCard extends StatelessWidget {
  final double totalRevenue;
  final double pmsLitres;
  final double agoLitres;
  final double safeCashBalance;
  final double netVariance;
  final int pendingAuditCount;
  final String stationName;
  final VoidCallback? onDepositPressed;
  final VoidCallback? onAuditPressed;
  final VoidCallback? onExportPressed;

  const ExecutiveHeroCard({
    super.key,
    required this.totalRevenue,
    required this.pmsLitres,
    required this.agoLitres,
    required this.safeCashBalance,
    required this.netVariance,
    required this.pendingAuditCount,
    required this.stationName,
    this.onDepositPressed,
    this.onAuditPressed,
    this.onExportPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isBalanced = netVariance.abs() < 1;
    return WorkspaceSection(
      title: 'Sales & reconciliation',
      subtitle: stationName,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Recorded sales value',
                      style: TextStyle(
                          fontSize: 12, color: colors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(CurrencyFormatter.formatNaira(totalRevenue),
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                          color: colors.onSurface)),
                ]),
                StatusChip(
                  label: isBalanced
                      ? 'Collections balanced'
                      : 'Difference: ${CurrencyFormatter.formatVariance(netVariance)}',
                  type: isBalanced ? ChipType.ok : ChipType.warn,
                ),
              ]),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 650
                ? 4
                : constraints.maxWidth >= 360
                    ? 2
                    : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            final items = [
              ('PMS dispensed', CurrencyFormatter.formatLitres(pmsLitres)),
              ('AGO dispensed', CurrencyFormatter.formatLitres(agoLitres)),
              ('Cash balance', CurrencyFormatter.formatNaira(safeCashBalance)),
              ('Pending verification', '$pendingAuditCount shifts'),
            ];
            return Wrap(
                spacing: 16,
                runSpacing: 18,
                children: items
                    .map((item) => SizedBox(
                          width: width,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.$1,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant)),
                                const SizedBox(height: 7),
                                Text(item.$2,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600)),
                              ]),
                        ))
                    .toList());
          }),
          const SizedBox(height: 24),
          Divider(color: colors.outlineVariant),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (onAuditPressed != null)
              ElevatedButton.icon(
                  onPressed: onAuditPressed,
                  icon: const Icon(Icons.fact_check_outlined, size: 17),
                  label: const Text('Review submissions')),
            if (onDepositPressed != null)
              OutlinedButton.icon(
                  onPressed: onDepositPressed,
                  icon: const Icon(Icons.account_balance_outlined, size: 17),
                  label: const Text('Record deposit')),
            if (onExportPressed != null)
              TextButton.icon(
                  onPressed: onExportPressed,
                  icon: const Icon(Icons.ios_share, size: 17),
                  label: const Text('Export summary')),
          ]),
        ]),
      ),
    );
  }
}
