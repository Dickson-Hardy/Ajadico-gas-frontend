import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/network/supabase_repository.dart';
import 'core/security/kiosk_security_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'state/station_app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase repository connection (Phase 1)
  try {
    final connected = await SupabaseRepository.instance.initialize();
    if (connected) {
      await StationAppState.instance.syncWithSupabase();
    }
  } catch (e) {
    debugPrint('Supabase initialization handled: $e');
  }

  runApp(const AjadicoGasApp());
}

class AjadicoGasApp extends StatelessWidget {
  const AjadicoGasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StationAppState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          title: 'Ajadico Energy - Forecourt Filling Station Management',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: state.themeMode,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return _KioskActivityListener(
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: mediaQuery.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const AppShell(),
        );
      },
    );
  }
}

/// Feeds every pointer and hardware-key interaction (including dialogs and
/// text entry) into the kiosk inactivity watchdog so long form fills on the
/// shared forecourt tablet do not auto-logout mid-shift.
class _KioskActivityListener extends StatefulWidget {
  const _KioskActivityListener({required this.child});

  final Widget child;

  @override
  State<_KioskActivityListener> createState() => _KioskActivityListenerState();
}

class _KioskActivityListenerState extends State<_KioskActivityListener> {
  final _security = KioskSecurityManager.instance;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    _security.recordUserInteraction();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _security.recordUserInteraction(),
      onPointerMove: (_) => _security.recordUserInteraction(),
      child: widget.child,
    );
  }
}
