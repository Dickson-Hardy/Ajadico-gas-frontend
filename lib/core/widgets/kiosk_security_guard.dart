import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../offline/offline_sync_service.dart';
import '../security/kiosk_security_manager.dart';
import '../../state/station_app_state.dart';

/// Wraps the application with forecourt security watchdog and 15-minute lockout overlay
class KioskSecurityGuard extends StatefulWidget {
  final Widget child;
  final VoidCallback onLockedOutLogout;

  const KioskSecurityGuard({
    super.key,
    required this.child,
    required this.onLockedOutLogout,
  });

  @override
  State<KioskSecurityGuard> createState() => _KioskSecurityGuardState();
}

class _KioskSecurityGuardState extends State<KioskSecurityGuard> {
  final _securityManager = KioskSecurityManager.instance;
  final _syncService = OfflineSyncService.instance;

  @override
  void initState() {
    super.initState();
    _securityManager.addListener(_onSecurityStateChanged);
    _syncService.addListener(_onSecurityStateChanged);
  }

  @override
  void dispose() {
    _securityManager.removeListener(_onSecurityStateChanged);
    _syncService.removeListener(_onSecurityStateChanged);
    super.dispose();
  }

  void _onSecurityStateChanged() {
    if (mounted) setState(() {});
  }

  void _showManagerOverrideDialog() {
    final pinController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Manager Override PIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter an Authorized Station Manager PIN to unlock this tablet immediately.',
                style: TextStyle(fontSize: 13, color: AppColors.slate),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.lightBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: errorMessage,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.slate)),
            ),
            ElevatedButton(
              onPressed: () {
                final stationState = StationAppState.instance;
                final success = _securityManager.managerOverrideUnlock(
                  managerPin: pinController.text.trim(),
                  managerId: stationState.currentUser.id,
                  stationId: stationState.currentStationCode,
                );

                if (success) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lockout cleared via Station Manager Override'),
                      backgroundColor: AppColors.emerald,
                    ),
                  );
                } else {
                  setDialogState(() {
                    errorMessage = 'Invalid Manager Override PIN';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Authorize Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _securityManager.recordUserInteraction(),
      onPointerMove: (_) => _securityManager.recordUserInteraction(),
      child: Stack(
        children: [
          // Main Application Content
          widget.child,

          // 1. Inactivity Warning Banner (Appears at 50s idle time; offset
          // below the heads-up alert toast so the two never overlap)
          if (_securityManager.isWarningActive && !_securityManager.isLockedOut)
            Positioned(
              top: 104,
              left: 20,
              right: 20,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.ink, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Forecourt Inactivity Warning',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
                            ),
                            Text(
                              'Screen auto-locks in ${_securityManager.secondsRemaining}s to protect shift records. Tap screen to stay signed in.',
                              style: const TextStyle(fontSize: 12, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _securityManager.recordUserInteraction(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Stay Signed In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. 15-Minute Brute-Force Lockout Screen Overlay
          if (_securityManager.isLockedOut)
            Positioned.fill(
              child: Material(
                color: Colors.black.withValues(alpha: 0.92),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: Color(0xFFFEE2E2),
                          child: Icon(Icons.lock_clock, size: 40, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'FORECOURT TABLET LOCKED',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '3 consecutive invalid PIN attempts were entered. Forecourt island tablet is locked for security.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.slate),
                        ),
                        const SizedBox(height: 24),
                        // Countdown timer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            children: [
                              const Text('LOCKOUT COOLDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate)),
                              const SizedBox(height: 4),
                              Text(
                                '${(_securityManager.lockoutSecondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_securityManager.lockoutSecondsRemaining % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.redAccent,
                                  fontFeatures: [],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showManagerOverrideDialog,
                            icon: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                            label: const Text('Station Manager Override', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
