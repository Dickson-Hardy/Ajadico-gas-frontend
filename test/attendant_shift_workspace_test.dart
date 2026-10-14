import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajadico_gas/core/offline/offline_sync_service.dart';
import 'package:ajadico_gas/core/theme/app_theme.dart';
import 'package:ajadico_gas/features/attendant/attendant_home_screen.dart';
import 'package:ajadico_gas/models/nozzle.dart';
import 'package:ajadico_gas/models/station.dart';
import 'package:ajadico_gas/models/user_profile.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  testWidgets('one shift ledger preserves all submissions and final handover',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      final root = Platform.environment['FLUTTER_ROOT'];
      final cache = root == null
          ? File(Platform.resolvedExecutable).parent.parent.parent.parent
          : Directory('$root/bin/cache');
      final loader = FontLoader('Roboto');
      for (final weight in ['regular', 'medium', 'bold']) {
        final font =
            File('${cache.path}/artifacts/material_fonts/roboto-$weight.ttf');
        if (await font.exists())
          loader.addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())));
      }
      await loader.load();
      final icons = File(
          '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (await icons.exists()) {
        final iconLoader = FontLoader('MaterialIcons');
        iconLoader.addFont(
            Future.value(ByteData.sublistView(await icons.readAsBytes())));
        await iconLoader.load();
      }
    });
    final state = StationAppState.instance;
    final sync = OfflineSyncService.instance;
    sync.setConnectivityForTesting(false);
    state.switchStation(const Station(
        id: 'fixture-station', code: 'TEST', name: 'Test station'));
    const user = UserProfile(
        id: 'fixture-attendant',
        displayName: 'Test attendant',
        fullName: 'Test attendant',
        role: UserRole.attendant,
        stationName: 'Test station');
    state.setCurrentUser(user);
    state.tanks.add(LiveTankStock(
        code: 'T1',
        product: 'PMS',
        capacity: 45000,
        bookStock: 24000,
        physicalDip: 24000,
        lastDipTime: DateTime(2026, 10, 14),
        isInterlocked: false));
    state.nozzles.add(NozzleItem(
        nozzleNumber: 1,
        productName: 'PMS',
        tankCode: 'T1',
        openingReading: 45001250.11,
        closingReading: 45002250.11,
        pricePerLitre: 1200,
        isOpeningConfirmed: true));
    // Older-shift submissions must not appear in the current ledger or totals.
    final older = await state.recordInterimCashDrop(amount: 999);
    expect(older, isNotNull);
    state.setCurrentUser(const UserProfile(
        id: 'fixture-other',
        displayName: 'Other attendant',
        fullName: 'Other attendant',
        role: UserRole.attendant,
        stationName: 'Test station'));
    state.setCurrentUser(user);
    for (final amount in [100000.0, 500000.0, 300000.0, 200000.0, 90000.0]) {
      final drop = await state.recordInterimCashDrop(amount: amount);
      expect(drop, isNotNull);
      drop!.status = 'acknowledged';
    }
    expect(state.totalAttendantAcknowledgedDrops(), 1190000);
    final key = GlobalKey();
    var readingsOpened = false;
    var handoverOpened = false;
    Future<void> mount(Size size, {bool dark = false, double scale = 1}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(
              key: key,
              child: AttendantHomeScreen(
                  user: user,
                  onLogout: () {},
                  onOpenCreditSale: () {},
                  onOpenFuelReturn: () {},
                  onOpenClosingReadings: () => readingsOpened = true,
                  onOpenRemittance: () => handoverOpened = true))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      const output = String.fromEnvironment('SHIFT_CAPTURE_DIR');
      if (output.isEmpty) return;
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final size in [
      const Size(1024, 900),
      const Size(390, 844),
      const Size(320, 568)
    ]) {
      await mount(size, scale: size.width == 320 ? 1.3 : 1);
      expect(find.text('My Shift'), findsOneWidget);
      expect(find.text('45001250.11 L'), findsOneWidget);
      expect(find.textContaining('Submission 5'), findsOneWidget);
      expect(find.textContaining('₦999'), findsNothing);
      await tester.ensureVisible(find.text('Record closing readings'));
      await tester.tap(find.text('Record closing readings'));
      expect(readingsOpened, isTrue);
      if (size.width == 320) {
        await tester.ensureVisible(find.text('Add cash submission'));
        await tester.tap(find.text('Add cash submission'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, '0');
        await tester.tap(find.text('Submit Drop to Cashier'));
        await tester.pump();
        expect(find.text('Please enter a valid drop amount.'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add POS / transfer'));
        await tester.tap(find.text('Add POS / transfer'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Shift reconciliation'));
      await tester.pumpAndSettle();
      expect(find.text('₦10,000.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    state.markClosingReadingsSubmitted();
    await mount(const Size(390, 844));
    await capture('01-my-shift-readings');
    await tester.ensureVisible(find.text('Total cash submitted'));
    await tester.pumpAndSettle();
    await capture('02-my-shift-submissions');
    await tester.ensureVisible(find.text('Review & submit final handover'));
    await tester.tap(find.text('Review & submit final handover'));
    expect(handoverOpened, isTrue);
    state.submitRemittance(
        cash: 1200000,
        posCard: 0,
        posTransfer: 0,
        bankTransfer: 0,
        credit: 0,
        finalCashHandover: 10000,
        evidencePhotos: []);
    await tester.pump();
    expect(find.text('₦10,000'), findsOneWidget);
    expect(find.text('₦0.00'), findsOneWidget);
    expect(state.submissions.first.cashDrops.length, 5);
    await tester.ensureVisible(find.text('Shift reconciliation'));
    await tester.pumpAndSettle();
    await capture('03-my-shift-balanced');
    await mount(const Size(390, 844), dark: true);
    await tester.ensureVisible(find.text('Shift reconciliation'));
    await tester.pumpAndSettle();
    await capture('04-my-shift-dark');
    expect(tester.takeException(), isNull);
    // Explicit zero final cash must not fall back to all cash submissions.
    state.submitRemittance(
        cash: 1190000,
        posCard: 0,
        posTransfer: 0,
        bankTransfer: 0,
        credit: 0,
        finalCashHandover: 0,
        evidencePhotos: []);
    expect(state.submissions.first.finalCashHandover, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    sync.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
