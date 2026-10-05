import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AjadicoGasApp());
}

class AjadicoGasApp extends StatelessWidget {
  const AjadicoGasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ajadico Fuel - Filling Station System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppShell(),
    );
  }
}
