import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajadico_gas/core/offline/offline_sync_service.dart';
import 'package:ajadico_gas/core/services/camera_compression_service.dart';
import 'package:ajadico_gas/core/theme/app_theme.dart';
import 'package:ajadico_gas/core/widgets/evidence_photo_picker.dart';
import 'package:ajadico_gas/core/widgets/shift_adjustment_ledger.dart';
import 'package:ajadico_gas/features/attendant/attendant_home_screen.dart';
import 'package:ajadico_gas/features/attendant/pump_expense_screen.dart';
import 'package:ajadico_gas/models/nozzle.dart';
import 'package:ajadico_gas/models/operations_policy.dart';
import 'package:ajadico_gas/models/shift_adjustment.dart';
import 'package:ajadico_gas/models/station.dart';
import 'package:ajadico_gas/models/user_profile.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  test('approved expenses and non-sale fuel are accounted for once', () {
    ShiftAdjustment entry(
            ShiftAdjustmentKind kind, double amount, String status) =>
        ShiftAdjustment(
            id: 'test',
            shiftId: 'shift',
            stationCode: 'TEST',
            attendantId: 'att',
            attendantName: 'Test attendant',
            kind: kind,
            reason: 'Test reason',
            amount: amount,
            status: status,
            createdAt: DateTime(2026, 10, 14));
    final entries = [
      entry(ShiftAdjustmentKind.expense, 5000, 'approved'),
      entry(ShiftAdjustmentKind.calibrationReturn, 24000, 'approved'),
      entry(ShiftAdjustmentKind.generatorFuel, 15000, 'approved'),
      entry(ShiftAdjustmentKind.companyVehicle, 6000, 'approved'),
      entry(ShiftAdjustmentKind.expense, 99999, 'pending'),
      entry(ShiftAdjustmentKind.expense, 99999, 'rejected')
    ];
    final totals = ShiftAdjustmentTotals(entries);
    expect(totals.approvedExpenses, 5000);
    expect(totals.approvedFuelValue, 45000);
    expect(totals.hasPending, isTrue);
    expect(totals.variance(grossSales: 1200000, money: 1150000, credit: 0), 0);
    final roundTrip = ShiftAdjustment.fromJson(entries.first.toJson());
    expect(roundTrip.isApproved, isTrue);
    final report = ShiftSubmission(
        id: 'sub',
        attendantName: 'Test',
        attendantId: 'att',
        shiftType: 'Morning',
        submittedAt: DateTime(2026, 10, 14),
        nozzles: [],
        expectedSalesValue: 1155000,
        approvedPumpExpenses: 5000,
        approvedNonSaleFuel: 45000,
        cashDeclared: 1150000,
        posCardDeclared: 0,
        posTransferDeclared: 0,
        bankTransferDeclared: 0,
        creditSalesDeclared: 0,
        evidencePhotos: []);
    expect(report.variance, 0);
  });

  testWidgets(
      'pump expense entry, pending ledger, role review and stock safety',
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
        if (await file.exists())
          loader.addFont(
              Future.value(ByteData.sublistView(await file.readAsBytes())));
      }
      await loader.load();
      final icon = File('$fonts/MaterialIcons-Regular.otf');
      if (await icon.exists()) {
        final loader = FontLoader('MaterialIcons');
        loader.addFont(
            Future.value(ByteData.sublistView(await icon.readAsBytes())));
        await loader.load();
      }
    });
    final state = StationAppState.instance;
    final sync = OfflineSyncService.instance;
    sync.setConnectivityForTesting(false);
    state.switchStation(const Station(
        id: 'fixture-station', code: 'TEST', name: 'Test station'));
    state.applyOperationsPolicy(OperationsPolicy(
        revision: 1,
        cashierApprovalLimit: 10000,
        managerApprovalLimit: 50000,
        expenseCategories: ['Maintenance']));
    const user = UserProfile(
        id: 'fixture-attendant',
        displayName: 'Test attendant',
        fullName: 'Test attendant',
        role: UserRole.attendant,
        stationName: 'Test station');
    state.setCurrentUser(user);
    final shift = state.currentShiftId;
    state.nozzles.addAll([
      NozzleItem(
          nozzleNumber: 1,
          productName: 'PMS',
          tankCode: 'T1',
          openingReading: 10000,
          closingReading: 11000,
          pricePerLitre: 1200,
          isOpeningConfirmed: true),
      NozzleItem(
          nozzleNumber: 2,
          productName: 'AGO',
          tankCode: 'T2',
          openingReading: 20000,
          closingReading: 20100,
          pricePerLitre: 1500,
          isOpeningConfirmed: true)
    ]);
    state.tanks.addAll([
      LiveTankStock(
          code: 'T1',
          product: 'PMS',
          capacity: 45000,
          bookStock: 24000,
          physicalDip: 23850,
          lastDipTime: DateTime(2026, 10, 14),
          isInterlocked: false),
      LiveTankStock(
          code: 'T2',
          product: 'AGO',
          capacity: 30000,
          bookStock: 12000,
          physicalDip: 11900,
          lastDipTime: DateTime(2026, 10, 14),
          isInterlocked: false)
    ]);
    final captureKey = GlobalKey();
    Future<void> mount(Widget page, Size size,
        {bool dark = false, double scale = 1}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(key: captureKey, child: page)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      const dir = String.fromEnvironment('ADJUSTMENT_CAPTURE_DIR');
      if (dir.isEmpty) return;
      await tester.runAsync(() async {
        final image = await (captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(dir).create(recursive: true);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    var saved = false;
    for (final size in [
      const Size(1024, 900),
      const Size(390, 844),
      const Size(320, 568)
    ]) {
      await mount(
          PumpExpenseScreen(onBack: () {}, onSuccess: () => saved = true), size,
          scale: size.width == 320 ? 1.3 : 1);
      await tester.ensureVisible(find.text('Submit expense for approval'));
      await tester.tap(find.text('Submit expense for approval'));
      await tester.pump();
      expect(find.textContaining('Choose a category'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await mount(PumpExpenseScreen(onBack: () {}, onSuccess: () => saved = true),
        const Size(390, 844));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maintenance').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '5,000');
    await tester.enterText(
        find.byType(TextField).at(1), 'Pump hose repair paid from shift cash');
    tester
        .widget<EvidencePhotoPicker>(find.byType(EvidencePhotoPicker))
        .onPhotosChanged([
      CompressedImageResult(
          localId: 'fixture-photo',
          fileName: 'fixture.jpg',
          originalSizeBytes: 1,
          compressedSizeBytes: 1,
          compressionRatioPercent: 0,
          base64Preview: '',
          imageBytes: Uint8List(0),
          remoteStorageUrl: 'storage://expense-receipts/fixture/receipt.jpg',
          capturedAt: DateTime(2026, 10, 14))
    ]);
    await tester.pump();
    await tester.ensureVisible(find.text('Submit expense for approval'));
    await tester.tap(find.text('Submit expense for approval'));
    await tester.pump();
    expect(saved, isTrue);
    expect(state.currentShiftAdjustments.approvedExpenses, 0);
    expect(state.shiftAdjustments.first.shiftId, shift);
    expect(state.shiftAdjustments.first.isPending, isTrue);
    const evidence = ['storage://calibration-evidence/fixture/photo.jpg'];
    for (final kind in [
      ShiftAdjustmentKind.calibrationReturn,
      ShiftAdjustmentKind.generatorFuel,
      ShiftAdjustmentKind.companyVehicle
    ]) {
      state.recordShiftAdjustment(
          kind: kind,
          reason: 'Test operational fuel use',
          evidence: evidence,
          litres: kind == ShiftAdjustmentKind.calibrationReturn ? 20 : 5,
          nozzleNumber: kind == ShiftAdjustmentKind.generatorFuel ? 2 : 1);
    }
    expect(state.tanks[0].bookStock, 24000);
    expect(state.tanks[0].physicalDip, 23850);
    expect(state.tanks[1].bookStock, 12000);
    expect(
        () => state.recordShiftAdjustment(
            kind: ShiftAdjustmentKind.generatorFuel,
            reason: 'Invalid PMS generator',
            evidence: evidence,
            litres: 5,
            nozzleNumber: 1),
        throwsArgumentError);
    expect(
        () => state.submitRemittance(
            cash: 0,
            posCard: 0,
            posTransfer: 0,
            bankTransfer: 0,
            credit: 0,
            evidencePhotos: []),
        throwsStateError);
    state.markClosingReadingsSubmitted();
    Widget home() => AttendantHomeScreen(
        user: user,
        onLogout: () {},
        onOpenClosingReadings: () {},
        onOpenRemittance: () {},
        onOpenPumpExpense: () {},
        onOpenFuelReturn: () {});
    for (final size in [
      const Size(1024, 900),
      const Size(390, 844),
      const Size(320, 568)
    ]) {
      await mount(home(), size, scale: size.width == 320 ? 1.3 : 1);
      await tester.ensureVisible(find.text('4. Expenses & non-sale fuel'));
      await tester.pumpAndSettle();
      expect(find.text('Awaiting approval'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Review & submit final handover'));
      expect(button.onPressed, isNull);
      if (size.width == 390) await capture('01-shift-expense-ledger');
    }
    await mount(home(), const Size(390, 844), dark: true);
    await tester.ensureVisible(find.text('4. Expenses & non-sale fuel'));
    await tester.pumpAndSettle();
    await capture('02-shift-expense-ledger-dark');
    state.setCurrentUser(const UserProfile(
        id: 'fixture-cashier',
        displayName: 'Test cashier',
        fullName: 'Test cashier',
        role: UserRole.cashier,
        stationName: 'Test station'));
    await mount(
        Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ShiftAdjustmentLedger(
                    entries: state.shiftAdjustments, review: true))),
        const Size(390, 844));
    expect(find.text('Approve'),
        findsNWidgets(3)); // calibration value exceeds cashier authority.
    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Receipt reviewed');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Review was not saved.'), findsOneWidget);
    expect(state.shiftAdjustments.every((e) => e.isPending), isTrue);
    expect(state.tanks[0].bookStock, 24000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    sync.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
