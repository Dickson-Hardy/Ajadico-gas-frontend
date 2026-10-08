import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';
import 'money_text.dart';

/// Premier Duotone / Gradient Hero Card for the Branch Manager and Executive View.
/// Highlights the "One Number That Matters" (Today's Total Forecourt Revenue)
/// paired with real-time volume dials and forecourt audit status.
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
    final isBalanced = netVariance.abs() < 1.0;
    final isShortage = netVariance < -1.0;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D5C52).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle ambient lighting glow
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emerald.withValues(alpha: 0.12),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Station Meta & Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.emerald,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                stationName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· Live Forecourt Operations',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),

                    // Quick Actions Row
                    Row(
                      children: [
                        if (onExportPressed != null)
                          IconButton(
                            icon: const Icon(Icons.print_outlined, color: Colors.white, size: 20),
                            tooltip: 'Export Shift Summary',
                            onPressed: onExportPressed,
                          ),
                        if (onDepositPressed != null)
                          ElevatedButton.icon(
                            onPressed: onDepositPressed,
                            icon: const Icon(Icons.account_balance, size: 16),
                            label: const Text('Bank Deposit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Brand gold rule — ties the hero to the Ajadico logo swoosh
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 56,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 18),

                // THE ONE NUMBER THAT MATTERS: Total Forecourt Revenue
                Text(
                  "TODAY'S TOTAL SALES VALUE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    MoneyText.hero(
                      totalRevenue,
                      fontSize: 38,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 14),
                    // Net Reconciliation Variance Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isBalanced
                            ? AppColors.emerald.withValues(alpha: 0.2)
                            : (isShortage ? AppColors.bad.withValues(alpha: 0.3) : AppColors.amber.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isBalanced ? AppColors.emerald : (isShortage ? AppColors.bad : AppColors.amber),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBalanced ? Icons.check_circle : (isShortage ? Icons.warning_amber_rounded : Icons.trending_up),
                            size: 14,
                            color: isBalanced ? AppColors.emerald : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isBalanced ? 'Balanced (₦0)' : CurrencyFormatter.formatVariance(netVariance),
                            style: AppTypography.monoNumeric(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Secondary Glassmorphic Pillars (Volume & Vault Cash)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      // PMS Volume
                      Expanded(
                        child: _buildMetricPillar(
                          label: 'PMS VOLUME',
                          value: CurrencyFormatter.formatLitres(pmsLitres),
                          icon: Icons.local_gas_station,
                          accentColor: AppColors.emerald,
                        ),
                      ),
                      Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                      // AGO Volume
                      Expanded(
                        child: _buildMetricPillar(
                          label: 'AGO VOLUME',
                          value: CurrencyFormatter.formatLitres(agoLitres),
                          icon: Icons.oil_barrel_outlined,
                          accentColor: AppColors.accent,
                        ),
                      ),
                      Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                      // Safe Cash
                      Expanded(
                        child: _buildMetricPillar(
                          label: 'SAFE CASH DRAWER',
                          value: CurrencyFormatter.formatNaira(safeCashBalance),
                          icon: Icons.lock_clock_outlined,
                          accentColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Pending Audit Callout (if any)
                if (pendingAuditCount > 0) ...[
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: onAuditPressed,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notification_important, size: 18, color: AppColors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$pendingAuditCount attendant shift submission${pendingAuditCount == 1 ? '' : 's'} waiting for verification',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'Review Queue →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPillar({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.monoNumeric(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
