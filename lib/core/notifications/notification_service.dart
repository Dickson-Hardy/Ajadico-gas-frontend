import 'package:flutter/foundation.dart';
import '../../models/user_profile.dart';
import 'forecourt_notification.dart';

/// Central Notification Service for Forecourt, Cashier, Manager, and Director
class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal() {
    _initSeedNotifications();
  }

  final List<ForecourtNotification> _notifications = [];
  ForecourtNotification? _latestHeadsUp;

  List<ForecourtNotification> get notifications => List.unmodifiable(_notifications);
  ForecourtNotification? get latestHeadsUp => _latestHeadsUp;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  int unreadCountForRole(UserRole role) {
    return _notifications
        .where((n) => !n.isRead && (n.targetRole == null || n.targetRole == role))
        .length;
  }

  List<ForecourtNotification> notificationsForRole(UserRole role) {
    return _notifications
        .where((n) => n.targetRole == null || n.targetRole == role)
        .toList();
  }

  /// Dispatch a new operational notification across the app
  void postNotification({
    required String title,
    required String message,
    required NotificationType type,
    UserRole? targetRole,
    String? actionRouteName,
  }) {
    final notification = ForecourtNotification(
      id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      targetRole: targetRole,
      actionRouteName: actionRouteName,
    );

    _notifications.insert(0, notification);
    _latestHeadsUp = notification;
    notifyListeners();
  }

  void dismissHeadsUp() {
    _latestHeadsUp = null;
    notifyListeners();
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    _latestHeadsUp = null;
    notifyListeners();
  }

  // Starts clean (0 demo notifications); populated dynamically by real-time operational events
  void _initSeedNotifications() {}
}
