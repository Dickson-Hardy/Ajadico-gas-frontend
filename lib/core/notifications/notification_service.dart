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

  void _initSeedNotifications() {
    _notifications.addAll([
      ForecourtNotification(
        id: 'NOTIF-01',
        title: 'New Shift Remittance',
        message: 'Amaka O. submitted Morning shift (₦1,250,000) for cashier audit.',
        type: NotificationType.info,
        timestamp: DateTime.now().subtract(const Duration(minutes: 42)),
        targetRole: UserRole.cashier,
        actionRouteName: '09 Verify Submission',
        isRead: false,
      ),
      ForecourtNotification(
        id: 'NOTIF-02',
        title: 'Underground Tank Deficit Alert',
        message: 'Tank T2 (PMS) physical dip has -120L variance against calculated book stock.',
        type: NotificationType.warning,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        targetRole: UserRole.manager,
        actionRouteName: '12 Tank Dip Audit',
        isRead: false,
      ),
      ForecourtNotification(
        id: 'NOTIF-03',
        title: 'Salary Shortage Deduction Pending',
        message: 'Bello S. morning shift shortfall of ₦4,500 requires Director authorization.',
        type: NotificationType.critical,
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        targetRole: UserRole.director,
        actionRouteName: '19 Salary Deductions',
        isRead: false,
      ),
      ForecourtNotification(
        id: 'NOTIF-04',
        title: 'Commercial Bank Deposit Awaiting Alert',
        message: '₦500,000 handed over by Cashier Chidi E. awaiting commercial bank SMS/email credit alert.',
        type: NotificationType.info,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        targetRole: UserRole.director,
        actionRouteName: '20 Bank Deposits',
        isRead: true,
      ),
    ]);
  }
}
