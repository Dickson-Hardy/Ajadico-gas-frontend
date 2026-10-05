import 'package:flutter/material.dart';
import 'core/network/supabase_repository.dart';
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
    return MaterialApp(
      title: 'Ajadico Energy - Forecourt Filling Station Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppShell(),
    );
  }
}
