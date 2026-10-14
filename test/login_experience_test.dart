import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajadico_gas/core/offline/offline_sync_service.dart';
import 'package:ajadico_gas/core/security/kiosk_security_manager.dart';
import 'package:ajadico_gas/core/theme/app_theme.dart';
import 'package:ajadico_gas/features/auth/device_mode_preferences.dart';
import 'package:ajadico_gas/features/auth/login_screen.dart';

void main() {
  testWidgets('remembered device modes, forms, keypad, recovery and layouts',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      final root = Platform.environment['FLUTTER_ROOT'];
      final cache = root == null
          ? File(Platform.resolvedExecutable).parent.parent.parent.parent
          : Directory('$root/bin/cache');
      final fonts = '${cache.path}/artifacts/material_fonts';
      final loader = FontLoader('Roboto');
      for (final weight in ['regular', 'medium', 'bold']) {
        final file = File('$fonts/roboto-$weight.ttf');
        if (await file.exists()) {
          loader.addFont(
              Future.value(ByteData.sublistView(await file.readAsBytes())));
        }
      }
      await loader.load();
      final icons = File('$fonts/MaterialIcons-Regular.otf');
      if (await icons.exists()) {
        await (FontLoader('MaterialIcons')
              ..addFont(Future.value(
                  ByteData.sublistView(await icons.readAsBytes()))))
            .load();
      }
    });
    final captureKey = GlobalKey();
    Future<void> mount(Size size, {bool dark = false, double scale = 1}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: RepaintBoundary(
            key: captureKey,
            child: LoginScreen(onLoginSuccess: (_) {
              fail('Offline login must not authenticate.');
            })),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Login at $size, scale $scale');
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      const output = String.fromEnvironment('UX_CAPTURE_DIR');
      if (output.isEmpty) return;
      await tester.runAsync(() async {
        final boundary = captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await mount(const Size(390, 844));
    expect(find.text('How will you use this device?'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull);
    await capture('01-device-setup');
    await tap(find.text('Personal device'));
    await tap(find.widgetWithText(FilledButton, 'Continue'));
    expect(find.text('Your management workspace, on your device.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('pin-key-1')), findsNothing);
    expect(
        find.text('Shared device · Sign out after your shift.'), findsNothing);
    await capture('02-management-phone');
    expect(find.byKey(const ValueKey('login-pin')), findsNothing);
    await tap(find.widgetWithText(FilledButton, 'Send sign-in code'));
    expect(find.text('Enter your invited email.'), findsOneWidget);
    expect(find.text('Work email'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('login-identity')), 'manager@company.test');
    await tap(find.widgetWithText(FilledButton, 'Send sign-in code'));
    expect(find.text('Connect to the configured service to sign in.'),
        findsOneWidget);
    await tap(find.text('Need access help?'));
    expect(find.textContaining('There is no default password or master PIN.'),
        findsOneWidget);
    await tap(find.text('Close'));
    await tap(find.text('Change device mode'));
    expect(find.text('Change device mode?'), findsOneWidget);
    await tap(find.text('Change mode'));
    await tap(find.text('Keep current mode'));
    expect(find.byKey(const ValueKey('login-pin')), findsNothing);

    await mount(const Size(390, 844));
    expect(find.text('Your management workspace, on your device.'),
        findsOneWidget);
    final saved = DeviceModePreferences();
    await saved.load();
    expect(saved.mode, DeviceMode.personal);
    expect(saved.stationId, isNull);
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(1024, 900),
      const Size(1440, 1000)
    ]) {
      await mount(size, scale: size.width == 320 ? 1.3 : 1);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await mount(const Size(390, 844), dark: true);
    await capture('03-management-dark');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Send sign-in code'));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();

    await tap(find.text('Change device mode'));
    await tap(find.text('Change mode'));
    await tap(find.text('Station tablet'));
    await tap(find.widgetWithText(FilledButton, 'Continue'));
    expect(find.text('No station configured'), findsOneWidget);
    expect(find.text('Staff sign-in'), findsOneWidget);
    for (final digit in ['1', '2', '3', '4', '5', '6', '7']) {
      await tap(find.byKey(ValueKey('pin-key-$digit')));
    }
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('login-pin')))
            .controller!
            .text,
        '123456');
    await tap(find.byKey(const ValueKey('pin-key-Backspace')));
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('login-pin')))
            .controller!
            .text,
        '12345');
    await tap(find.byKey(const ValueKey('pin-key-Clear')));
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('login-pin')))
            .controller!
            .text,
        isEmpty);
    await saved.load();
    expect(saved.mode, DeviceMode.station);
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(1024, 900)
    ]) {
      await mount(size, scale: size.width == 320 ? 1.3 : 1);
      if (size.width == 390) await capture('04-staff-phone');
      if (size.width == 1024) await capture('05-staff-tablet');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await saved.save(DeviceMode.station, stationId: 'test-only-branch');
    final reloaded = DeviceModePreferences();
    await reloaded.load();
    expect(reloaded.stationId, 'test-only-branch');
    await saved.save(DeviceMode.personal);
    await reloaded.load();
    expect(reloaded.stationId, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    final security = KioskSecurityManager.instance;
    var loggedOut = false;
    security.initialize(onAutoLogout: () => loggedOut = true);
    security.setSessionContext(stationId: '', actorId: '');
    await tester.pump(const Duration(seconds: 61));
    expect(loggedOut, isFalse, reason: 'Signed-out screens must not time out.');
    security.useManagementIdlePolicy(true);
    security.setSessionContext(
        stationId: 'fixture', actorId: 'fixture-manager');
    await tester.pump(const Duration(seconds: 61));
    expect(loggedOut, isFalse,
        reason: 'Management must not use the 60-second kiosk policy.');
    expect(security.sessionTimeoutSeconds, 900);
    security.useManagementIdlePolicy(false);
    await tester.pump(const Duration(seconds: 60));
    expect(loggedOut, isTrue,
        reason: 'Station staff retains the kiosk timeout.');
    security.setSessionContext(stationId: '', actorId: '');
    security.dispose();
    OfflineSyncService.instance.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
