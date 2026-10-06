import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/supabase_repository.dart';
import '../../core/security/kiosk_security_manager.dart';
import '../../core/widgets/forecourt_sync_bar.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

class LoginScreen extends StatefulWidget {
  final Function(UserProfile user) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserProfile? _selectedUser;
  String _pin = '';
  bool _isAuthenticating = false;
  String? _authError;

  final _security = KioskSecurityManager.instance;

  @override
  void initState() {
    super.initState();
    _security.addListener(_onSecurityChanged);
    StationAppState.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
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

  void _onKeyPress(String key) {
    if (_pin.length < 6 && !_isAuthenticating) {
      setState(() {
        _pin += key;
        _authError = null;
      });
    }
  }

  void _onClear() {
    setState(() {
      _pin = '';
      _authError = null;
    });
  }

  Future<void> _onSubmit() async {
    if (_selectedUser == null) {
      setState(() => _authError = 'Please select your name first');
      return;
    }
    if (_pin.length < 4) {
      setState(() => _authError = 'Please enter at least 4 digits for your PIN');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });

    try {
      final repo = SupabaseRepository.instance;
      if (!repo.isConnected) {
        setState(() {
          _isAuthenticating = false;
          _pin = '';
          _authError =
              'Authentication service unavailable — check connection or ask the station manager to unlock';
        });
        return;
      }

      final res = await repo.verifyAttendantPin(
        stationId: 'lekki-01',
        profileId: _selectedUser!.id,
        pin: _pin,
      );

      final success = res['success'] == true;

      if (success) {
        _security.recordSuccessfulPin(
          actorId: _selectedUser!.id,
          stationId: 'lekki-01',
        );
        setState(() => _isAuthenticating = false);
        widget.onLoginSuccess(_selectedUser!);
      } else if (_isServiceFault(res['message']?.toString() ?? '')) {
        setState(() {
          _isAuthenticating = false;
          _pin = '';
          _authError =
              'Authentication service unavailable — check connection or ask the station manager to unlock';
        });
      } else {
        _security.recordFailedPinAttempt(
          actorId: _selectedUser!.id,
          stationId: 'lekki-01',
        );

        setState(() {
          _isAuthenticating = false;
          _pin = '';
          final remaining = KioskSecurityManager.maxFailedAttempts - _security.failedAttempts;
          _authError = remaining > 0
              ? 'Invalid PIN. $remaining attempt(s) remaining before 15-min lockout.'
              : 'Too many failed attempts. Tablet locked.';
        });
      }
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
        _pin = '';
        _authError =
            'Authentication service unavailable — check connection or ask the station manager to unlock';
      });
    }
  }

  /// Distinguishes a transport/backend failure from a genuine wrong-PIN answer,
  /// so a network fault never burns an attendant's lockout attempt.
  bool _isServiceFault(String message) {
    return message.contains('Exception') ||
        message.contains('Failed host lookup') ||
        message.contains('SocketException') ||
        message.contains('TimeoutException') ||
        message.contains('Connection closed');
  }

  void _showDirectorLoginDialog() {
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        String? overrideError;

        return StatefulBuilder(
          builder: (context, setDlgState) {
            void submitPin() {
              if (KioskSecurityManager.instance.validateManagerOverridePin(pinCtrl.text.trim())) {
                Navigator.pop(ctx);
                widget.onLoginSuccess(UserProfile.defaultDirector);
                return;
              }
              setDlgState(() {
                overrideError = 'Invalid manager override PIN. Ask the station manager for the correct PIN.';
              });
            }

            return AlertDialog(
              title: const Text(
                'Station Manager Override',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Managing Director sign-in is protected. Enter the Station Manager override PIN to continue.',
                    style: TextStyle(fontSize: 14, color: AppColors.slate),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pinCtrl,
                    autofocus: true,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Manager Override PIN *',
                      counterText: '',
                      errorText: overrideError,
                      errorMaxLines: 2,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => setDlgState(submitPin),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => setDlgState(submitPin),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => pinCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final liveStaff = StationAppState.instance.staff;
    final staffList = liveStaff
        .where((u) => u.isActive && u.role != UserRole.director)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forecourt Tablet Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'Lekki Road Station · Shared Island Terminal',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Live Sync & Forecourt Status Bar
          const ForecourtSyncBar(stationName: 'Lekki Road Island #1'),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Active Staff Member',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Shared island tablet: select your name, then enter your assigned PIN.',
                        style: TextStyle(fontSize: 13, color: AppColors.slate),
                      ),
                      const SizedBox(height: 16),

                      // Staff selection buttons grid or empty state
                      if (staffList.isEmpty)
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(Icons.people_outline, size: 48, color: AppColors.muted),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Forecourt Attendants Registered',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Onboard pump attendants using the Manager Dashboard or Director Portal.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.shield_outlined),
                                  label: const Text('Login as Managing Director (Engr. Dickson)'),
                                  onPressed: _showDirectorLoginDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.ink,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.2,
                              children: staffList.map((user) {
                                final isSelected = _selectedUser?.id == user.id;
                                return OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedUser = user;
                                      _pin = '';
                                      _authError = null;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    side: BorderSide(
                                      color: isSelected ? AppColors.primary : AppColors.border,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    user.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? AppColors.primary : AppColors.ink,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // PIN Pad Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'PIN for ${_selectedUser?.displayName ?? "—"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (_security.failedAttempts > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.badSurface,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Attempt ${_security.failedAttempts}/3',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.bad,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // PIN dots / mask display
                              Container(
                                width: double.infinity,
                                height: 50,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.lightBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _authError != null ? AppColors.bad : AppColors.border,
                                  ),
                                ),
                                child: Semantics(
                                  label: 'PIN length ${_pin.length}',
                                  child: Text(
                                    _pin.isEmpty
                                        ? '• • • •'
                                        : '• ' * _pin.length,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 8,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ),

                              if (_authError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _authError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.bad,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Numeric Keypad
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 320),
                                child: Column(
                                  children: [
                                    _buildKeypadRow(['1', '2', '3']),
                                    const SizedBox(height: 8),
                                    _buildKeypadRow(['4', '5', '6']),
                                    const SizedBox(height: 8),
                                    _buildKeypadRow(['7', '8', '9']),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _onClear,
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 54),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _onKeyPress('0'),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 54),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: const Text(
                                              '0',
                                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _isAuthenticating ? null : _onSubmit,
                                            style: ElevatedButton.styleFrom(
                                              minimumSize: const Size(0, 54),
                                              backgroundColor: AppColors.primary,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: _isAuthenticating
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                  )
                                                : const Text(
                                                    'Log In',
                                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_outlined, size: 14, color: AppColors.slate),
                                  SizedBox(width: 4),
                                  Text(
                                    'BRD §2.4: Locked for 15m after 3 failed attempts',
                                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              onPressed: () => _onKeyPress(key),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
