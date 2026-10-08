import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_typography.dart';

/// Modern empty-state art view for tables, queues, and search filters.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  /// Preset for zero pending audits / clean shift queue
  const EmptyStateView.allClear({
    super.key,
    this.title = 'All Shift Audits Cleared',
    this.message = 'No pending submissions requiring verification. The forecourt is fully reconciled.',
    this.actionLabel,
    this.onAction,
  })  : icon = Icons.verified_outlined,
        iconColor = AppColors.ok;

  /// Preset for zero records found in queries/lists
  const EmptyStateView.noRecords({
    super.key,
    this.title = 'No Records Found',
    this.message = 'No transactions or submissions match the current filter or shift period.',
    this.actionLabel,
    this.onAction,
  })  : icon = Icons.folder_open_outlined,
        iconColor = AppColors.slate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = iconColor ?? (isDark ? AppColors.darkMuted : AppColors.muted);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Concentric layered art container
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: effectiveColor,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title(
                fontSize: 17,
                color: isDark ? AppColors.darkInk : AppColors.ink,
              ),
            ),

            const SizedBox(height: 6),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontSize: 13,
                  color: isDark ? AppColors.darkMuted : AppColors.muted,
                ),
              ),
            ),

            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
