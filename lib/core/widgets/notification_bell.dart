import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../notifications/forecourt_notification.dart';
import '../notifications/notification_service.dart';
import '../../models/user_profile.dart';

/// Notification Bell with unread counter and interactive drawer
class NotificationBell extends StatelessWidget {
  final UserRole currentRole;
  final ValueChanged<String>? onNavigateToScreen;

  const NotificationBell({
    super.key,
    required this.currentRole,
    this.onNavigateToScreen,
  });

  @override
  Widget build(BuildContext context) {
    final notifService = NotificationService.instance;

    return AnimatedBuilder(
      animation: notifService,
      builder: (context, _) {
        final unreadCount = notifService.unreadCountForRole(currentRole);

        return IconButton(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
          ),
          tooltip: 'Forecourt Alerts ($unreadCount unread)',
          onPressed: () => _showNotificationSheet(context),
        );
      },
    );
  }

  void _showNotificationSheet(BuildContext context) {
    final notifService = NotificationService.instance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final list = notifService.notificationsForRole(currentRole);
            final unreadTotal = notifService.unreadCountForRole(currentRole);

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notifications_active, color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              const Text(
                                'Forecourt Alerts',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                              ),
                              if (unreadTotal > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unreadTotal new',
                                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              if (unreadTotal > 0)
                                TextButton(
                                  onPressed: () {
                                    notifService.markAllAsRead();
                                    setSheetState(() {});
                                  },
                                  child: const Text('Mark all read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (list.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 48, color: AppColors.emerald),
                                SizedBox(height: 12),
                                Text(
                                  'All caught up!',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'No pending operational alerts for your role.',
                                  style: TextStyle(fontSize: 13, color: AppColors.slate),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: list.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final notif = list[index];

                              return InkWell(
                                onTap: () {
                                  notifService.markAsRead(notif.id);
                                  setSheetState(() {});
                                  if (notif.actionRouteName != null && onNavigateToScreen != null) {
                                    Navigator.pop(ctx);
                                    onNavigateToScreen!(notif.actionRouteName!);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                  color: notif.isRead ? Colors.transparent : AppColors.primary.withOpacity(0.04),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Type Icon
                                      _buildTypeAvatar(notif.type),
                                      const SizedBox(width: 12),

                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notif.title,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                                      color: AppColors.ink,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  notif.timeAgo,
                                                  style: const TextStyle(fontSize: 11, color: AppColors.mutedSlate),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              notif.message,
                                              style: const TextStyle(fontSize: 13, color: AppColors.slate),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                if (notif.targetRole != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.ink.withOpacity(0.06),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      notif.targetRole!.name.toUpperCase(),
                                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.ink),
                                                    ),
                                                  ),
                                                if (notif.actionRouteName != null) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Tap to view ${notif.actionRouteName} →',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTypeAvatar(NotificationType type) {
    Color bg;
    Color iconColor;
    IconData icon;

    switch (type) {
      case NotificationType.critical:
        bg = const Color(0xFFFEE2E2);
        iconColor = Colors.redAccent;
        icon = Icons.error_outline;
        break;
      case NotificationType.warning:
        bg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFD97706);
        icon = Icons.warning_amber_rounded;
        break;
      case NotificationType.success:
        bg = const Color(0xFFDCFCE7);
        iconColor = AppColors.emerald;
        icon = Icons.check_circle_outline;
        break;
      case NotificationType.info:
        bg = const Color(0xFFEFF6FF);
        iconColor = AppColors.primary;
        icon = Icons.info_outline;
        break;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Icon(icon, color: iconColor, size: 18),
    );
  }
}
