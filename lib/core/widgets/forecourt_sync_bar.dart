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
          bannerBg = AppColors.warnSurface;
          textColor = AppColors.warn;
          statusIcon = Icons.wifi_off_rounded;
          statusText = 'OFFLINE MODE (Forecourt Outbox: $pending items queued)';
        } else if (isSyncing) {
          bannerBg = AppColors.lightBackground;
          textColor = AppColors.bank;
          statusIcon = Icons.sync_rounded;
          statusText = 'SYNCING: ${syncService.statusInfo.activeItemTitle ?? "Transmitting records..."}';
        } else if (failed > 0) {
          bannerBg = AppColors.badSurface;
          textColor = AppColors.bad;
          statusIcon = Icons.error_outline_rounded;
          statusText = '$failed item(s) failed sync. Tap to retry.';
        } else if (pending > 0) {
          bannerBg = AppColors.warnSurface;
          textColor = AppColors.warn;
          statusIcon = Icons.cloud_queue_rounded;
          statusText = '$pending transaction(s) pending sync';
        } else {
          bannerBg = AppColors.okSurface;
          textColor = AppColors.ok;
          statusIcon = Icons.cloud_done_rounded;
          statusText = 'ONLINE & CLOUD SYNCED';
        }

        Widget banner = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bannerBg,
            border: Border(
              bottom: BorderSide(color: textColor.withValues(alpha: 0.2), width: 1),
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
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showStationName)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          stationName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Forecourt 60s Inactivity countdown chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: securityManager.secondsRemaining <= 15
                      ? AppColors.lightCherry
                      : AppColors.slate.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: securityManager.secondsRemaining <= 15 ? AppColors.bad : AppColors.slate,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${securityManager.secondsRemaining}s',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: securityManager.secondsRemaining <= 15 ? AppColors.bad : AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Sync / Retry button if items pending or failed
              if (pending > 0 || failed > 0)
                TextButton(
                  onPressed: () {
                    if (failed > 0) {
                      syncService.retryFailedItems();
                    } else {
                      syncService.triggerSync();
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: textColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  child: Text(failed > 0 ? 'Retry' : 'Sync Now'),
                ),
            ],
          ),
        );

        if (failed > 0) {
          banner = InkWell(
            onTap: syncService.retryFailedItems,
            child: banner,
          );
        }

        return banner;
      },
    );
  }
}
