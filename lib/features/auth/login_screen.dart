import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/supabase_repository.dart';
import '../../core/security/kiosk_security_manager.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ajadico_logo.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

/// Redesigned Login Screen implementing Option 3:
/// - Door 1: Forecourt Shift Staff (Username/Staff ID + PIN for Attendants & Cashiers)
/// - Door 2: Management & Executive Portal (Email/ID + Password/Key for Managers & Directors)
class LoginScreen extends StatefulWidget {
  final Function(UserProfile user) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // Mode 0 = Forecourt Staff (Attendant & Cashier), Mode 1 = Management (Manager & Director)
  int _activeDoor = 0;

  // Door 1 (Forecourt Staff) Controllers & State
  final TextEditingController _staffUsernameCtrl = TextEditingController();
  String _staffPin = '';
  bool _isStaffAuthenticating = false;
  String? _staffAuthError;

  // Door 2 (Management) Controllers & State
  final TextEditingController _mgmtUsernameCtrl = TextEditingController();
  final TextEditingController _mgmtPasswordCtrl = TextEditingController();
  bool _isMgmtAuthenticating = false;
  String? _mgmtAuthError;
  bool _obscureMgmtPassword = true;

  final _security = KioskSecurityManager.instance;

  @override
  void initState() {
    super.initState();
    _security.addListener(_onSecurityChanged);
    StationAppState.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _staffUsernameCtrl.dispose();
    _mgmtUsernameCtrl.dispose();
    _mgmtPasswordCtrl.dispose();
    _security.removeListener(_onSecurityChanged);
    StationAppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onSecurityChanged() {
    if (mounted) setState(() {});
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // DOOR 1: FORECOURT STAFF LOGIN (ATTENDANTS & CASHIERS)
  // ---------------------------------------------------------------------------
  void _onStaffKeyPress(String key) {
    if (_staffPin.length < 6 && !_isStaffAuthenticating && !_security.isLockedOut) {
      setState(() {
        _staffPin += key;
        _staffAuthError = null;
      });
    }
  }

  void _onStaffPinClear() {
    setState(() {
      _staffPin = '';
      _staffAuthError = null;
    });
  }

  Future<void> _submitStaffLogin() async {
    final username = _staffUsernameCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _staffAuthError = 'Please enter your Username or Staff ID');
      return;
    }
    if (_staffPin.length < 4) {
      setState(() => _staffAuthError = 'Please enter at least 4 digits for your PIN');
      return;
    }

    setState(() {
      _isStaffAuthenticating = true;
      _staffAuthError = null;
    });

    final currentStation = StationAppState.instance.currentStationCode.toLowerCase();
    final liveStaff = StationAppState.instance.staff;

    // Find staff profile by username / displayName / fullName / phone
    UserProfile? matchedUser;
    for (final u in liveStaff) {
      if (u.isActive &&
          (u.displayName.equalsIgnoreCase(username) ||
              u.fullName.equalsIgnoreCase(username) ||
              (u.phone != null && u.phone!.trim() == username) ||
              u.id.equalsIgnoreCase(username))) {
        matchedUser = u;
        break;
      }
    }

    // If no direct database match, check partial name match
    if (matchedUser == null) {
      for (final u in liveStaff) {
        if (u.isActive &&
            (u.displayName.toLowerCase().contains(username.toLowerCase()) ||
                u.fullName.toLowerCase().contains(username.toLowerCase()))) {
          matchedUser = u;
          break;
        }
      }
    }

    if (matchedUser == null) {
      setState(() {
        _isStaffAuthenticating = false;
        _staffPin = '';
        _staffAuthError = 'Staff username not found. Check spelling or ask the Station Manager.';
      });
      return;
    }

    // If user is actually an executive trying to log in at the staff door
    if (matchedUser.role == UserRole.manager || matchedUser.role == UserRole.director) {
      setState(() {
        _isStaffAuthenticating = false;
        _staffAuthError = 'This is an executive account. Please switch to the "Management" tab.';
      });
      return;
    }

    // Verify PIN against Supabase or offline fallback
    try {
      final repo = SupabaseRepository.instance;
      final effectiveStation = matchedUser.stationId ?? StationAppState.instance.currentStationId;

      if (!repo.isConnected) {
        // Offline: only the station manager override PIN is honored (no hardcoded demo PINs)
        if (_security.validateManagerOverridePin(_staffPin)) {
          _security.recordSuccessfulPin(actorId: matchedUser.id, stationId: effectiveStation);
          setState(() => _isStaffAuthenticating = false);
          widget.onLoginSuccess(matchedUser);
          return;
        }
        setState(() {
          _isStaffAuthenticating = false;
          _staffPin = '';
          _staffAuthError =
              'Terminal offline — staff PIN cannot be verified. Connect to the internet, or ask the Station Manager to use the override PIN.';
        });
        return;
      }

      final res = await repo.verifyAttendantPin(
        stationId: effectiveStation,
        profileId: matchedUser.id,
        pin: _staffPin,
      );

      if (res['success'] == true) {
        _security.recordSuccessfulPin(actorId: matchedUser.id, stationId: currentStation);
        setState(() => _isStaffAuthenticating = false);
        widget.onLoginSuccess(matchedUser);
      } else if (_isServiceFault(res['message']?.toString() ?? '')) {
        setState(() {
          _isStaffAuthenticating = false;
          _staffPin = '';
          _staffAuthError = 'Network timeout — please try again or notify Manager';
        });
      } else {
        _security.recordFailedPinAttempt(actorId: matchedUser.id, stationId: currentStation);
        setState(() {
          _isStaffAuthenticating = false;
          _staffPin = '';
          final remaining = KioskSecurityManager.maxFailedAttempts - _security.failedAttempts;
          _staffAuthError = remaining > 0
              ? 'Invalid PIN. $remaining attempt(s) remaining before 15m lockout.'
              : 'Too many failed attempts. Forecourt tablet locked.';
        });
      }
    } catch (e) {
      setState(() {
        _isStaffAuthenticating = false;
        _staffPin = '';
        _staffAuthError = 'Authentication service fault — contact Station Manager';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // DOOR 2: MANAGEMENT PORTAL LOGIN (MANAGERS & DIRECTORS)
  // ---------------------------------------------------------------------------
  Future<void> _submitManagementLogin() async {
    final identifier = _mgmtUsernameCtrl.text.trim().toLowerCase();
    final password = _mgmtPasswordCtrl.text.trim();

    if (identifier.isEmpty) {
      setState(() => _mgmtAuthError = 'Please enter your Manager ID or Email');
      return;
    }
    if (password.isEmpty) {
      setState(() => _mgmtAuthError = 'Please enter your Security Password or PIN');
      return;
    }

    setState(() {
      _isMgmtAuthenticating = true;
      _mgmtAuthError = null;
    });

    final currentStation = StationAppState.instance.currentStationCode.toLowerCase();

    // 1. Check for Managing Director (Engr. Dickson)
    final isDirectorIdentifier = identifier.contains('director') ||
        identifier.contains('dickson') ||
        identifier.contains('admin') ||
        identifier == 'ceo' ||
        identifier == 'hq';

    if (isDirectorIdentifier) {
      if (_security.validateManagerOverridePin(password)) {
        _security.recordSuccessfulPin(actorId: UserProfile.defaultDirector.id, stationId: currentStation);
        setState(() => _isMgmtAuthenticating = false);
        widget.onLoginSuccess(UserProfile.defaultDirector);
        return;
      } else {
        setState(() {
          _isMgmtAuthenticating = false;
          _mgmtAuthError = 'Invalid Director credentials or Master PIN.';
        });
        return;
      }
    }

    // 2. Check for Branch Manager in database
    final liveStaff = StationAppState.instance.staff;
    UserProfile? managerUser;
    for (final u in liveStaff) {
      if (u.role == UserRole.manager &&
          (u.displayName.toLowerCase().contains(identifier) ||
              u.fullName.toLowerCase().contains(identifier) ||
              u.id.equalsIgnoreCase(identifier))) {
        managerUser = u;
        break;
      }
    }

    // Manager must be an on-boarded live staff profile (no fabricated fallback user)
    if (managerUser == null) {
      setState(() {
        _isMgmtAuthenticating = false;
        _mgmtAuthError =
            'No Station Manager profile found for this station. Ask the Director to onboard one in Staff Management.';
      });
      return;
    }

    final effectiveStation = managerUser.stationId ?? StationAppState.instance.currentStationId;

    // Verify Manager credentials (override PIN only — no hardcoded passwords)
    if (_security.validateManagerOverridePin(password)) {
      _security.recordSuccessfulPin(actorId: managerUser.id, stationId: effectiveStation);
      setState(() => _isMgmtAuthenticating = false);
      widget.onLoginSuccess(managerUser);
      return;
    }

    // Try Supabase PIN verification if manager has personal PIN
    try {
      final repo = SupabaseRepository.instance;
      if (repo.isConnected) {
        final res = await repo.verifyAttendantPin(
          stationId: effectiveStation,
          profileId: managerUser.id,
          pin: password,
        );
        if (res['success'] == true) {
          _security.recordSuccessfulPin(actorId: managerUser.id, stationId: effectiveStation);
          setState(() => _isMgmtAuthenticating = false);
          widget.onLoginSuccess(managerUser);
          return;
        }
      }
    } catch (_) {}

    setState(() {
      _isMgmtAuthenticating = false;
      _mgmtAuthError = 'Invalid credentials. Enter manager password or master override PIN.';
    });
  }

  bool _isServiceFault(String message) {
    return message.contains('Exception') ||
        message.contains('Failed host lookup') ||
        message.contains('SocketException') ||
        message.contains('TimeoutException') ||
        message.contains('Connection closed');
  }

  void _showEmergencyUnlockDialog() {
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        String? unlockError;

        return StatefulBuilder(
          builder: (context, setDlgState) {
            void submitPin() {
              final ok = _security.managerOverrideUnlock(
                managerPin: pinCtrl.text.trim(),
                managerId: 'manager-override',
                stationId: StationAppState.instance.currentStationCode,
              );
              if (ok) {
                Navigator.pop(ctx);
                setState(() {
                  _staffAuthError = null;
                  _staffPin = '';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Forecourt tablet unlocked by Station Manager.'),
                    backgroundColor: AppColors.ok,
                  ),
                );
              } else {
                setDlgState(() {
                  unlockError = 'Incorrect Manager PIN. Lockout remains active.';
                });
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.lock_open_outlined, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Text('Station Manager Unlock', style: AppTypography.title()),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter Station Manager override PIN to immediately cancel the 15-minute brute-force lockout.',
                    style: AppTypography.body(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinCtrl,
                    autofocus: true,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Manager Override PIN',
                      counterText: '',
                      errorText: unlockError,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => submitPin(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: submitPin,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: AppColors.ink),
                  child: const Text('Unlock Tablet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = StationAppState.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajadico Petroleum', style: AppTypography.heading(fontSize: 18, color: Colors.white)),
            Text(
              '${state.currentStationName} · Terminal Sign In',
              style: AppTypography.caption(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Theme Toggle
          IconButton(
            icon: Icon(state.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: state.isDarkMode ? 'Daylight Mode' : 'Forecourt Night Shift Mode',
            onPressed: () => state.toggleTheme(),
          ),
          if (_security.isLockedOut)
            IconButton(
              icon: const Icon(Icons.lock_reset, color: AppColors.amber),
              tooltip: 'Emergency Manager Unlock',
              onPressed: _showEmergencyUnlockDialog,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Live Sync & Status Bar
          ForecourtSyncBar(stationName: '${state.currentStationName} · Forecourt Island'),

          // Main Centered Content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      // Official Logo
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 16),
                          child: AjadicoLogo.stacked(size: 60, showSubtitle: true),
                        ),
                      ),

                      // Two-Door Segmented Switcher
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildDoorTab(
                                index: 0,
                                label: 'Forecourt Staff',
                                subtitle: 'Attendants & Cashier',
                                icon: Icons.local_gas_station_rounded,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildDoorTab(
                                index: 1,
                                label: 'Management',
                                subtitle: 'Manager & Director',
                                icon: Icons.admin_panel_settings_rounded,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Door Body Card
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _activeDoor == 0
                            ? _buildStaffDoorCard(isDark)
                            : _buildManagementDoorCard(isDark),
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

  // ===========================================================================
  // DOOR TOGGLE BUTTON
  // ===========================================================================
  Widget _buildDoorTab({
    required int index,
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _activeDoor == index;

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() => _activeDoor = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkBackground : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkMuted : AppColors.muted),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.title(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? AppColors.darkInk : AppColors.ink)
                        : (isDark ? AppColors.darkMuted : AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.caption(
                fontSize: 12,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkMuted : AppColors.muted),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DOOR 1 CARD: FORECOURT SHIFT STAFF (USERNAME + PIN)
  // ===========================================================================
  Widget _buildStaffDoorCard(bool isDark) {
    return Container(
      key: const ValueKey('staff-door'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.ok.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.badge_outlined, color: AppColors.ok, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Forecourt Shift Sign In', style: AppTypography.title(fontSize: 16)),
                    Text(
                      'Pump Attendants & Station Cashier',
                      style: AppTypography.caption(
                        fontSize: 12,
                        color: isDark ? AppColors.darkMuted : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_security.failedAttempts > 0 && !_security.isLockedOut)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.badSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_security.failedAttempts}/${KioskSecurityManager.maxFailedAttempts}',
                    style: AppTypography.caption(fontSize: 12, color: AppColors.bad),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Username / Staff ID Field
          Text(
            'STAFF USERNAME OR ID',
            style: AppTypography.caption(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark ? AppColors.darkMuted : AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _staffUsernameCtrl,
            enabled: !_security.isLockedOut && !_isStaffAuthenticating,
            style: AppTypography.body(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Enter your staff name or Staff ID',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. PIN Entry Mask
          Text(
            'SECURITY PIN (4–6 DIGITS)',
            style: AppTypography.caption(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark ? AppColors.darkMuted : AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _staffAuthError != null
                    ? AppColors.bad
                    : (isDark ? AppColors.darkLine : AppColors.line),
                width: 1.5,
              ),
            ),
            child: Text(
              _staffPin.isEmpty ? '• • • •' : '• ' * _staffPin.length,
              style: AppTypography.monoNumeric(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: isDark ? AppColors.darkInk : AppColors.ink,
              ),
            ),
          ),

          if (_staffAuthError != null) ...[
            const SizedBox(height: 8),
            Text(
              _staffAuthError!,
              style: AppTypography.caption(fontSize: 12, color: AppColors.bad),
            ),
          ],

          // Lockout Banner if tablet locked
          if (_security.isLockedOut) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.badSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.bad.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, size: 24, color: AppColors.bad),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Locked for ${_security.lockoutSecondsRemaining}s. Contact Station Manager to unlock.',
                      style: AppTypography.caption(fontSize: 12, color: AppColors.bad),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 3. Numeric Keypad
          Column(
            children: [
              _buildStaffKeypadRow(['1', '2', '3'], isDark),
              const SizedBox(height: 8),
              _buildStaffKeypadRow(['4', '5', '6'], isDark),
              const SizedBox(height: 8),
              _buildStaffKeypadRow(['7', '8', '9'], isDark),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _security.isLockedOut ? null : _onStaffPinClear,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Clear', style: AppTypography.caption(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _security.isLockedOut ? null : () => _onStaffKeyPress('0'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('0', style: AppTypography.title(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isStaffAuthenticating || _security.isLockedOut)
                          ? null
                          : _submitStaffLogin,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.ok,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isStaffAuthenticating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          Center(
            child: Text(
              '60s auto-logout on forecourt islands · 3 attempts lockout',
              style: AppTypography.caption(
                fontSize: 12,
                color: isDark ? AppColors.darkMuted : AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffKeypadRow(List<String> keys, bool isDark) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              onPressed: _security.isLockedOut ? null : () => _onStaffKeyPress(key),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
              ),
              child: Text(
                key,
                style: AppTypography.title(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkInk : AppColors.ink,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // DOOR 2 CARD: MANAGEMENT & EXECUTIVE PORTAL (CREDENTIALS / MASTER KEY)
  // ===========================================================================
  Widget _buildManagementDoorCard(bool isDark) {
    return Container(
      key: const ValueKey('mgmt-door'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Management & Executive Portal', style: AppTypography.title(fontSize: 16)),
                    Text(
                      'Station Managers, Auditors & HQ Directors',
                      style: AppTypography.caption(
                        fontSize: 12,
                        color: isDark ? AppColors.darkMuted : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Manager ID / Email Field
          Text(
            'MANAGER ID OR CORPORATE EMAIL',
            style: AppTypography.caption(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark ? AppColors.darkMuted : AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _mgmtUsernameCtrl,
            enabled: !_security.isLockedOut && !_isMgmtAuthenticating,
            style: AppTypography.body(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. Station Manager name, ID, or corporate email',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Password / Master Override Key Field
          Text(
            'SECURITY PASSWORD OR OVERRIDE PIN',
            style: AppTypography.caption(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark ? AppColors.darkMuted : AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _mgmtPasswordCtrl,
            obscureText: _obscureMgmtPassword,
            enabled: !_security.isLockedOut && !_isMgmtAuthenticating,
            style: AppTypography.body(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Enter password or manager override PIN',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureMgmtPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureMgmtPassword = !_obscureMgmtPassword),
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
              ),
            ),
            onSubmitted: (_) => _submitManagementLogin(),
          ),

          if (_mgmtAuthError != null) ...[
            const SizedBox(height: 10),
            Text(
              _mgmtAuthError!,
              style: AppTypography.caption(fontSize: 12, color: AppColors.bad),
            ),
          ],

          // Lockout banner (lockout applies to ALL doors on this terminal)
          if (_security.isLockedOut) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.badSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.bad.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, size: 24, color: AppColors.bad),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Terminal locked for ${_security.lockoutSecondsRemaining}s after too many failed attempts. '
                      'Both staff and management sign-in are disabled.',
                      style: AppTypography.caption(fontSize: 12, color: AppColors.bad),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 3. Submit Management Sign In Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: _isMgmtAuthenticating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                _isMgmtAuthenticating ? 'Authenticating...' : 'Sign In to Management Console',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: (_isMgmtAuthenticating || _security.isLockedOut)
                  ? null
                  : _submitManagementLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Guidance — no hardcoded shortcut credentials
          Text(
            'Management sign-in uses the station override PIN or the manager\'s personal PIN registered in Supabase. '
            'Contact HQ if you need credentials provisioned.',
            style: AppTypography.caption(
              fontSize: 12,
              color: isDark ? AppColors.darkMuted : AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

extension StringIgnoreCase on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
