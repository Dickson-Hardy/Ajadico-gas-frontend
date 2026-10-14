import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ajadico_gas/core/offline/offline_sync_service.dart';
import 'package:ajadico_gas/core/notifications/notification_service.dart';
import 'package:ajadico_gas/core/security/kiosk_security_manager.dart';
import 'package:ajadico_gas/core/theme/app_theme.dart';
import 'package:ajadico_gas/core/widgets/operations_workspace.dart';
import 'package:ajadico_gas/features/admin/attendant_salary_ledger_screen.dart';
import 'package:ajadico_gas/features/admin/bank_deposit_verification_screen.dart';
import 'package:ajadico_gas/features/admin/company_reports_screen.dart';
import 'package:ajadico_gas/features/admin/price_change_screen.dart';
import 'package:ajadico_gas/features/admin/staff_management_screen.dart';
import 'package:ajadico_gas/features/admin/station_setup_screen.dart';
import 'package:ajadico_gas/features/attendant/attendant_home_screen.dart';
import 'package:ajadico_gas/features/attendant/closing_readings_screen.dart';
import 'package:ajadico_gas/features/attendant/credit_sale_screen.dart';
import 'package:ajadico_gas/features/attendant/fuel_return_screen.dart';
import 'package:ajadico_gas/features/attendant/pump_expense_screen.dart';
import 'package:ajadico_gas/features/attendant/remittance_screen.dart';
import 'package:ajadico_gas/features/auth/login_screen.dart';
import 'package:ajadico_gas/features/onboarding/company_setup_screen.dart';
import 'package:ajadico_gas/features/cashier/daily_cash_count_screen.dart';
import 'package:ajadico_gas/features/cashier/verify_submission_screen.dart';
import 'package:ajadico_gas/features/credit/credit_customers_screen.dart';
import 'package:ajadico_gas/features/manager/expense_entry_screen.dart';
import 'package:ajadico_gas/features/manager/fuel_delivery_screen.dart';
import 'package:ajadico_gas/features/manager/manager_dashboard_screen.dart';
import 'package:ajadico_gas/features/manager/tank_dip_screen.dart';
import 'package:ajadico_gas/features/shell/app_shell.dart';
import 'package:ajadico_gas/models/nozzle.dart';
import 'package:ajadico_gas/models/credit_customer.dart';
import 'package:ajadico_gas/models/operations_policy.dart';
import 'package:ajadico_gas/models/station.dart';
import 'package:ajadico_gas/models/user_profile.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  testWidgets('workspace navigation, responsive screens and operational forms',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Use Flutter's bundled fonts so layout checks use real glyph widths on
    // every native test host. No font is downloaded or bundled into the app.
    await tester.runAsync(() async {
      final root = Platform.environment['FLUTTER_ROOT'];
      final cache = root == null
          ? File(Platform.resolvedExecutable).parent.parent.parent.parent
          : Directory('$root/bin/cache');
      final fontDirectory = '${cache.path}/artifacts/material_fonts';
      final loader = FontLoader('Roboto');
      for (final weight in ['regular', 'medium', 'bold']) {
        final textFont = File('$fontDirectory/roboto-$weight.ttf');
        if (await textFont.exists()) {
          final bytes = await textFont.readAsBytes();
          loader.addFont(Future.value(ByteData.sublistView(bytes)));
        }
      }
      await loader.load();
      final iconFont = File('$fontDirectory/MaterialIcons-Regular.otf');
      if (await iconFont.exists()) {
        final loader = FontLoader('MaterialIcons');
        final bytes = await iconFont.readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      }
    });
    final state = StationAppState.instance;
    state.applyOperationsPolicy(OperationsPolicy(
        revision: 1,
        cashierApprovalLimit: 10000,
        managerApprovalLimit: 50000,
        expenseCategories: ['Maintenance']));
    final sync = OfflineSyncService.instance;
    sync.setConnectivityForTesting(false);
    state.switchStation(const Station(
        id: 'fixture-station', code: 'TEST', name: 'Test station'));
    // Fixtures stay in this test process; no Supabase connection is initialized.
    state.nozzles.add(NozzleItem(
        nozzleNumber: 1,
        productName: 'PMS',
        tankCode: 'T1',
        openingReading: 12000,
        closingReading: 12600,
        pricePerLitre: 1050,
        isOpeningConfirmed: true));
    state.tanks.add(LiveTankStock(
        code: 'T1',
        product: 'PMS',
        capacity: 45000,
        bookStock: 24000,
        physicalDip: 23850,
        lastDipTime: DateTime(2026, 10, 13),
        isInterlocked: false));
    state.creditCustomers.add(const CreditCustomer(
        id: 'fixture-customer',
        name: 'Test fleet account',
        outstanding: 150000,
        lastRepayment: '12 Oct 2026',
        dueDate: '30 days',
        status: CustomerCreditStatus.current));
    state.setCurrentUser(const UserProfile(
        id: 'fixture-attendant',
        displayName: 'Test attendant',
        fullName: 'Test attendant',
        role: UserRole.attendant,
        stationName: 'Test station'));
    state.submitRemittance(
        cash: 550000,
        posCard: 50000,
        posTransfer: 30000,
        bankTransfer: 0,
        credit: 0,
        evidencePhotos: []);
    state.verifyShiftSubmission(
        submissionId: state.submissions.first.id,
        cashierComment: 'Test fixture');
    state.setCurrentUser(const UserProfile(
        id: 'fixture-cashier',
        displayName: 'Test cashier',
        fullName: 'Test cashier',
        role: UserRole.cashier,
        stationName: 'Test station'));
    state.recordExpense(
        category: 'Maintenance',
        amount: 24000,
        paymentSource: 'Cash Drawer',
        description: 'Pump inspection',
        requiresApproval: true);
    state.setCurrentUser(const UserProfile(
        id: 'fixture-director',
        displayName: 'Test director',
        fullName: 'Test director',
        role: UserRole.director,
        stationName: 'Test station'));

    void noop() {}
    final destinations = [
      const WorkspaceDestination(
          id: 'overview',
          label: 'Financial overview',
          icon: Icons.dashboard_outlined,
          group: 'Overview'),
      const WorkspaceDestination(
          id: 'people',
          label: 'People & access',
          icon: Icons.people_outline,
          group: 'Administration'),
      const WorkspaceDestination(
          id: 'deposits',
          label: 'Deposit approvals',
          icon: Icons.account_balance_outlined,
          group: 'Accounts'),
    ];
    final captureKey = GlobalKey();
    String selected = 'overview';
    var signedOut = false;
    Widget pageFor(String id) => switch (id) {
          'people' => StaffManagementScreen(onBack: noop),
          'deposits' => BankDepositVerificationScreen(onBack: noop),
          _ => CompanyReportsScreen(onBack: noop, onOpenExpenseEntry: noop),
        };
    Widget workspace() => StatefulBuilder(
        builder: (context, setState) => OperationsWorkspace(
              destinations: destinations,
              selectedId: selected,
              onSelect: (id) => setState(() => selected = id),
              userName: 'Operations director',
              roleLabel: 'Director',
              stationName: state.currentStationName,
              onSignOut: () => signedOut = true,
              status: const Text('No queued records',
                  style: TextStyle(fontSize: 11)),
              child: pageFor(selected),
            ));

    Future<void> mount(Widget page, Size size,
        {bool dark = false, double scale = 1}) async {
      // Start each viewport/theme case from a fresh root, rather than capturing
      // an in-progress MaterialApp theme interpolation from the previous case.
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
        home: RepaintBoundary(key: captureKey, child: page),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final layoutError = tester.takeException();
      if (layoutError is FlutterError) debugPrint(layoutError.toStringDeep());
      expect(layoutError, isNull,
          reason: '${page.runtimeType} at $size, scale $scale');
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

    await mount(workspace(), const Size(1440, 1000));
    expect(
        find.text(
            'Profit is unavailable until delivery costs and remaining stock are reconciled. Date filters apply to loaded records; these totals are not a complete company accounting statement.'),
        findsOneWidget);
    await capture('01-admin-overview');
    await tester.tap(find.text('People & access').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(selected, 'people');
    expect(find.text('Staff directory'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Nobody');
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsNothing);
    await capture('02-staff-directory');
    await tester.tap(find.text('Deposit approvals').first);
    await tester.pump();
    expect(selected, 'deposits');
    await tester.tap(find.text('Confirmed').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await capture('03-deposit-register');
    await tester.tap(find.byTooltip('Sign out'));
    expect(signedOut, isTrue);

    selected = 'overview';
    await mount(workspace(), const Size(390, 844));
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('People & access').first);
    await tester.pumpAndSettle();
    expect(selected, 'people');
    expect(find.text('Staff directory'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('04-mobile-directory');

    final screens = <String, Widget Function()>{
      'login': () => LoginScreen(onLoginSuccess: (_) {}),
      'overview': () =>
          CompanyReportsScreen(onBack: noop, onOpenExpenseEntry: noop),
      'staff': () => StaffManagementScreen(onBack: noop),
      'deposits': () => BankDepositVerificationScreen(onBack: noop),
      'payroll': () => AttendantSalaryLedgerScreen(onBack: noop),
      'prices': () => PriceChangeScreen(onBack: noop, onSuccess: noop),
      'configuration': () => StationSetupScreen(onBack: noop),
      'manager': () => ManagerDashboardScreen(
          onOpenVerificationQueue: noop,
          onOpenCashCount: noop,
          onOpenCreditCustomers: noop,
          onLogout: noop),
      'attendant': () => AttendantHomeScreen(
          user: state.currentUser,
          onLogout: noop,
          onOpenClosingReadings: noop,
          onOpenRemittance: noop,
          onOpenCreditSale: noop,
          onOpenFuelReturn: noop),
      'readings': () =>
          ClosingReadingsScreen(onBack: noop, onSubmitSuccess: noop),
      'remittance': () => RemittanceScreen(onBack: noop, onSubmitSuccess: noop),
      'credit-sale': () => CreditSaleScreen(onBack: noop, onSuccess: noop),
      'fuel-return': () => FuelReturnScreen(onBack: noop, onSuccess: noop),
      'pump-expense': () => PumpExpenseScreen(onBack: noop, onSuccess: noop),
      'verification': () =>
          VerifySubmissionScreen(onBack: noop, onVerified: noop),
      'cash': () => DailyCashCountScreen(onBack: noop),
      'customers': () => CreditCustomersScreen(onBack: noop),
      'expense': () => ExpenseEntryScreen(onBack: noop, onSuccess: noop),
      'delivery': () => FuelDeliveryScreen(onBack: noop, onSuccess: noop),
      'dip': () => TankDipScreen(onBack: noop, onSuccess: noop),
    };
    for (final size in [
      const Size(1024, 900),
      const Size(390, 844),
      const Size(320, 568)
    ]) {
      for (final entry in screens.entries) {
        await mount(entry.value(), size, scale: size.width == 320 ? 1.3 : 1);
        // Inspect layout after scrolling to each form's bottom, where actions live.
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await tester.drag(scrollables.first, const Offset(0, -1400));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull,
              reason: '${entry.key} bottom at $size');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    }
    for (final name in [
      'cash',
      'remittance',
      'delivery',
      'dip',
      'configuration',
      'attendant',
      'readings',
      'credit-sale',
      'fuel-return',
      'pump-expense',
      'customers'
    ]) {
      await mount(screens[name]!(), const Size(390, 844), dark: true);
      await capture('$name-dark');
    }
    await mount(CreditCustomersScreen(onBack: noop), const Size(390, 844));
    expect(find.byType(DataTable), findsNothing);
    await tester.ensureVisible(find.text('Repayment'));
    await tester.pump();
    await capture('08-mobile-credit-account');
    await tester.tap(find.text('Repayment'));
    await tester.pumpAndSettle();
    expect(find.text('Record Repayment'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, '0');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Record Repayment'));
    await tester.pump();
    expect(find.text('Enter an amount greater than ₦0.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'No matching customer');
    await tester.pump();
    expect(find.text('Test fleet account'), findsNothing);
    await mount(CompanyReportsScreen(onBack: noop), const Size(390, 844));
    await tester.tap(find.text('Fuel stock'));
    await tester.pumpAndSettle();
    expect(find.text('Tank T1'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture('09-mobile-tank-reconciliation');
    await mount(CompanyReportsScreen(onBack: noop), const Size(390, 844),
        scale: 1.3);
    await mount(workspace(), const Size(1440, 1000), dark: true);
    await capture('05-dark-workspace');
    await mount(LoginScreen(onLoginSuccess: (_) {}), const Size(1440, 1000));
    await capture('06-sign-in');
    // Exercise the real role-based shell after a simulated successful login.
    NotificationService.instance.dismissHeadsUp();
    await mount(const AppShell(), const Size(1440, 1000));
    tester.widget<LoginScreen>(find.byType(LoginScreen)).onLoginSuccess(
        const UserProfile(
            id: 'fixture-director',
            displayName: 'Test director',
            fullName: 'Test director',
            role: UserRole.director,
            stationName: 'Test station'));
    await tester.pumpAndSettle();
    expect(find.byType(CompanySetupScreen), findsOneWidget);
    // This shell-layout fixture has no Auth backend. Explicitly defer setup via
    // the callback; this is not proof of a successful activation/onboarding.
    tester
        .widget<CompanySetupScreen>(find.byType(CompanySetupScreen))
        .onContinue();
    await tester.pumpAndSettle();
    await capture('07-director-workspace');
    final priceNavigation = find.text('Fuel prices');
    await tester.ensureVisible(priceNavigation);
    await tester.tap(priceNavigation);
    await tester.pumpAndSettle();
    expect(find.byType(PriceChangeScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'Review instruction');
    final overviewNavigation = find.text('Financial overview');
    await tester.scrollUntilVisible(overviewNavigation, -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(overviewNavigation);
    await tester.pumpAndSettle();
    expect(find.text('Leave this page?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(PriceChangeScreen), findsOneWidget);
    await tester.tap(overviewNavigation);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard and continue'));
    await tester.pumpAndSettle();
    expect(find.byType(CompanyReportsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mount(const AppShell(), const Size(390, 844));
    tester.widget<LoginScreen>(find.byType(LoginScreen)).onLoginSuccess(
        const UserProfile(
            id: 'fixture-attendant',
            displayName: 'Test attendant',
            fullName: 'Test attendant',
            role: UserRole.attendant,
            stationName: 'Test station'));
    await tester.pumpAndSettle();
    expect(find.byType(AttendantHomeScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Record closing readings'));
    await tester.tap(find.text('Record closing readings'));
    await tester.pumpAndSettle();
    expect(find.byType(ClosingReadingsScreen), findsOneWidget);
    expect(
        find.byType(AttendantHomeScreen, skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('Save dials & proceed to remittance'));
    await tester.pumpAndSettle();
    expect(find.byType(ClosingReadingsScreen), findsNothing);
    expect(find.byType(AttendantHomeScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Review & submit final handover'));
    await tester.tap(find.text('Review & submit final handover'));
    await tester.pumpAndSettle();
    expect(find.text('Final Shift Handover'), findsOneWidget);
    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    expect(find.byType(RemittanceScreen), findsNothing);
    expect(find.byType(AttendantHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    KioskSecurityManager.instance.dispose();
    sync.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
