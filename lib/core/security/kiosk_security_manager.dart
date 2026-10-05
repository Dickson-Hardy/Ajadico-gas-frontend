import 'dart:async';
import 'package:flutter/foundation.dart';

/// Security event types for forecourt audit trail
enum SecurityEventType {
  loginSuccess,
  loginFailure,
  inactivityAutoLogout,
  bruteForceLockout,
  managerOverrideUnlock,
  meterOverrideAttempt,
}

class SecurityAuditEntry {
  final String id;
  final SecurityEventType type;
  final String description;
  final String stationId;
  final String actorId;
  final DateTime timestamp;

  SecurityAuditEntry({
    required this.id,
    required this.type,
    required this.description,
    required this.stationId,
    required this.actorId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'description': description,
        'stationId': stationId,
        'actorId': actorId,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Forecourt Tablet Kiosk Hardening & Security Manager (BRD §2.1–§2.4)
/// Enforces:
/// 1. 60-second inactivity auto-logout on pump island tablets
/// 2. 3-attempt brute-force PIN lockout with 15-minute cooldown
/// 3. Station manager override protocol
/// 4. Comprehensive security audit logging
class KioskSecurityManager extends ChangeNotifier {
  static final KioskSecurityManager instance = KioskSecurityManager._internal();
  KioskSecurityManager._internal();

  // 1. Inactivity Watchdog State
  static const int inactivityTimeoutSeconds = 60;
  static const int warningThresholdSeconds = 10;

  Timer? _inactivityTimer;
  int _secondsRemaining = inactivityTimeoutSeconds;
  bool _isWarningActive = false;
  VoidCallback? _onAutoLogoutCallback;

  int get secondsRemaining => _secondsRemaining;
  bool get isWarningActive => _isWarningActive;

  // 2. Brute-Force PIN Lockout State
  static const int maxFailedAttempts = 3;
  static const int lockoutDurationSeconds = 900; // 15 minutes

  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _lockoutCountdownTimer;
  int _lockoutSecondsRemaining = 0;

  int get failedAttempts => _failedAttempts;
  bool get isLockedOut => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);
  int get lockoutSecondsRemaining => _lockoutSecondsRemaining;

  // 3. Audit Trail
  final List<SecurityAuditEntry> _auditTrail = [];
  List<SecurityAuditEntry> get auditTrail => List.unmodifiable(_auditTrail);

  /// Initialize the watchdog with an auto-logout handler
  void initialize({required VoidCallback onAutoLogout}) {
    _onAutoLogoutCallback = onAutoLogout;
    resetInactivityTimer();
  }

  /// Called on any forecourt touch, pointer movement, or keyboard interaction
  void recordUserInteraction() {
    if (_isWarningActive) {
      _isWarningActive = false;
      notifyListeners();
    }
    _secondsRemaining = inactivityTimeoutSeconds;
  }

  /// Reset the timer whenever a new session starts
  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _secondsRemaining = inactivityTimeoutSeconds;
    _isWarningActive = false;

    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;

        if (_secondsRemaining <= warningThresholdSeconds && !_isWarningActive) {
          _isWarningActive = true;
          notifyListeners();
        }

        if (_secondsRemaining <= 0) {
          _triggerAutoLogout();
        }
      }
    });
  }

  void _triggerAutoLogout() {
    _inactivityTimer?.cancel();
    _isWarningActive = false;

    _logSecurityEvent(
      type: SecurityEventType.inactivityAutoLogout,
      description: 'Tablet 60s inactivity watchdog triggered automatic forecourt logout',
      stationId: 'lekki-01',
      actorId: 'attendant-session',
    );

    notifyListeners();
    _onAutoLogoutCallback?.call();
  }

  // ---------------------------------------------------------------------------
  // BRUTE-FORCE PIN LOCKOUT PROTOCOL
  // ---------------------------------------------------------------------------

  /// Record a failed PIN attempt
  void recordFailedPinAttempt({required String actorId, required String stationId}) {
    _failedAttempts++;

    _logSecurityEvent(
      type: SecurityEventType.loginFailure,
      description: 'Failed PIN attempt $_failedAttempts of $maxFailedAttempts',
      stationId: stationId,
      actorId: actorId,
    );

    if (_failedAttempts >= maxFailedAttempts) {
      _triggerLockout(stationId: stationId, actorId: actorId);
    } else {
      notifyListeners();
    }
  }

  /// Record a successful PIN entry
  void recordSuccessfulPin({required String actorId, required String stationId}) {
    _failedAttempts = 0;
    _isWarningActive = false;
    _secondsRemaining = inactivityTimeoutSeconds;

    _logSecurityEvent(
      type: SecurityEventType.loginSuccess,
      description: 'Successful PIN authentication for $actorId',
      stationId: stationId,
      actorId: actorId,
    );

    resetInactivityTimer();
    notifyListeners();
  }

  void _triggerLockout({required String stationId, required String actorId}) {
    _lockedUntil = DateTime.now().add(const Duration(seconds: lockoutDurationSeconds));
    _lockoutSecondsRemaining = lockoutDurationSeconds;

    _logSecurityEvent(
      type: SecurityEventType.bruteForceLockout,
      description: '3 consecutive invalid PINs entered. Forecourt tablet locked for 15 minutes',
      stationId: stationId,
      actorId: actorId,
    );

    _lockoutCountdownTimer?.cancel();
    _lockoutCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockedUntil != null) {
        final remaining = _lockedUntil!.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          _clearLockout();
        } else {
          _lockoutSecondsRemaining = remaining;
          notifyListeners();
        }
      }
    });

    notifyListeners();
  }

  /// Manager Override PIN unlocks a locked forecourt tablet
  bool managerOverrideUnlock({
    required String managerPin,
    required String managerId,
    required String stationId,
  }) {
    // Default authorized manager override PIN: 998811 or 5555
    if (managerPin == '998811' || managerPin == '5555') {
      _logSecurityEvent(
        type: SecurityEventType.managerOverrideUnlock,
        description: 'Station Manager $managerId authorized emergency override to clear 15-min lockout',
        stationId: stationId,
        actorId: managerId,
      );

      _clearLockout();
      return true;
    }
    return false;
  }

  void _clearLockout() {
    _lockedUntil = null;
    _failedAttempts = 0;
    _lockoutSecondsRemaining = 0;
    _lockoutCountdownTimer?.cancel();
    resetInactivityTimer();
    notifyListeners();
  }

  void _logSecurityEvent({
    required SecurityEventType type,
    required String description,
    required String stationId,
    required String actorId,
  }) {
    final entry = SecurityAuditEntry(
      id: 'SEC-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      description: description,
      stationId: stationId,
      actorId: actorId,
      timestamp: DateTime.now(),
    );
    _auditTrail.add(entry);
    if (kDebugMode) {
      print('[SECURITY AUDIT] [${entry.type.name.toUpperCase()}] ${entry.description}');
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _lockoutCountdownTimer?.cancel();
    super.dispose();
  }
}
