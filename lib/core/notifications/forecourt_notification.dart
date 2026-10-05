import '../../models/user_profile.dart';

enum NotificationType {
  info,
  success,
  warning,
  critical,
}

/// Represents an operational forecourt alert or event
class ForecourtNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final UserRole? targetRole; // null means broadcast to all staff
  final String? actionRouteName;
  bool isRead;

  ForecourtNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.targetRole,
    this.actionRouteName,
    this.isRead = false,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
