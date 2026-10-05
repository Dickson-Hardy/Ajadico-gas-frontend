import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../offline/offline_sync_service.dart';
import '../security/kiosk_security_manager.dart';

/// Forecourt Network, Hardware Station, and Offline Outbox Status Bar
class ForecourtSyncBar extends StatelessWidget {
  final String stationName;
  final bool showStationName;

  const ForecourtSyncBar({
    super.key,
    this.stationName = 'Lekki Road Station',
    this.showStationName = true,
  });

  @override
  Widget build(BuildContext context) {
    final syncService = OfflineSyncService.instance;
    final securityManager = KioskSecurityManager.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([syncService, securityManager]),
      builder: (context, _) {
        final isOnline = syncService.isOnline;
        final isSyncing = syncService.isSyncing;
        final pending = syncService.pendingCount;
        final failed = syncService.failedCount;

        Color bannerBg;
        Color textColor;
        IconData statusIcon;
        String statusText;

        if (!isOnline) {
          bannerBg = const Color(0xFFFFFBEB); // Light amber
          textColor = const Color(0xFFB45309);
          statusIcon = Icons.wifi_off_rounded;
          statusText = 'OFFLINE MODE (Forecourt Outbox: $pending items queued)';
        } else if (isSyncing) {
          bannerBg = const Color(0xFFEFF6FF); // Light blue
          textColor = const Color(0xFF1D4ED8);
          statusIcon = Icons.sync_rounded;
          statusText = 'SYNCING: ${syncService.statusInfo.activeItemTitle ?? "Transmitting records..."}';
        } else if (failed > 0) {
          bannerBg = const Color(0xFFFEF2F2); // Light red
          textColor = const Color(0xFFB91C1C);
          statusIcon = Icons.error_outline_rounded;
          statusText = '$failed item(s) failed sync. Tap to retry.';
        } else if (pending > 0) {
          bannerBg = const Color(0xFFFFFBEB);
          textColor = const Color(0xFFB45309);
          statusIcon = Icons.cloud_queue_rounded;
          statusText = '$pending transaction(s) pending sync';
        } else {
          bannerBg = const Color(0xFFF0FDF4); // Light green
          textColor = const Color(0xFF15803D);
          statusIcon = Icons.cloud_done_rounded;
          statusText = 'ONLINE & CLOUD SYNCED';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bannerBg,
            border: Border(
              bottom: BorderSide(color: textColor.withOpacity(0.2), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Online / Sync status icon
              if (isSyncing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
                )
              else
                Icon(statusIcon, size: 16, color: textColor),
              const SizedBox(width: 8),

              // Status text
              Expanded(
                child: Row(
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showStationName) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.ink.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          stationName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Forecourt 60s Inactivity countdown chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: securityManager.secondsRemaining <= 15
                      ? Colors.redAccent.withOpacity(0.15)
                      : AppColors.slate.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 11,
                      color: securityManager.secondsRemaining <= 15 ? Colors.redAccent : AppColors.slate,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${securityManager.secondsRemaining}s',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: securityManager.secondsRemaining <= 15 ? Colors.redAccent : AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Sync / Retry button if items pending or failed
              if (pending > 0 || failed > 0)
                InkWell(
                  onTap: () {
                    if (failed > 0) {
                      syncService.retryFailedItems();
                    } else {
                      syncService.triggerSync();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: textColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      failed > 0 ? 'Retry' : 'Sync Now',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
