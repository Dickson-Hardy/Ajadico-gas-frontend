import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajadico_gas/core/config/supabase_config.dart';
import 'package:ajadico_gas/core/navigation/shell_back_guard.dart';
import 'package:ajadico_gas/core/offline/offline_sync_service.dart';
import 'package:ajadico_gas/core/theme/app_theme.dart';
import 'package:ajadico_gas/core/widgets/evidence_preview_dialog.dart';
import 'package:ajadico_gas/features/manager/fuel_delivery_screen.dart';
import 'package:ajadico_gas/features/cashier/bank_deposit_dialog.dart';
import 'package:ajadico_gas/models/operations_policy.dart';
import 'package:ajadico_gas/models/user_profile.dart';
import 'package:ajadico_gas/models/station.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  test('build configuration has no fallback and rejects server credentials',
      () {
    expect(SupabaseConfig.url, isEmpty);
    expect(SupabaseConfig.anonKey, isEmpty);
    expect(SupabaseConfig.validate('', ''), isNotNull);
    expect(
        SupabaseConfig.validate(
            'http://example.com', 'sb_publishable_test_only_key'),
        isNotNull);
    expect(
        SupabaseConfig.validate(
            'https://example.com', 'sb_secret_test_only_key'),
        isNotNull);
    expect(
        SupabaseConfig.validate(
            'https://example.com', 'sb_publishable_test_only_key'),
        isNull);
  });

  test('operating policy validates limits and categories', () {
    expect(
        () => OperationsPolicy(
            revision: 0,
            cashierApprovalLimit: 1,
            managerApprovalLimit: 2,
            expenseCategories: ['Maintenance']),
        throwsFormatException);
    expect(
        () => OperationsPolicy(
            revision: 1,
            cashierApprovalLimit: 3,
            managerApprovalLimit: 2,
            expenseCategories: ['Maintenance']),
        throwsFormatException);
    expect(
        () => OperationsPolicy(
            revision: 1,
            cashierApprovalLimit: 1,
            managerApprovalLimit: 2,
            expenseCategories: [' ']),
        throwsFormatException);
    expect(
        () => OperationsPolicy(
            revision: 1,
            cashierApprovalLimit: 1,
            managerApprovalLimit: 2,
            expenseCategories: ['A', 'A']),
        throwsFormatException);
    final policy = OperationsPolicy.fromJson({
      'revision': 2,
      'cashier_approval_limit': 25,
      'manager_approval_limit': 100,
      'expense_categories': ['Maintenance']
    });
    expect(policy.managerApprovalLimit, 100);
    expect(() => policy.expenseCategories.add('Other'), throwsUnsupportedError);
  });

  testWidgets('policy boundaries, failed approval and delivery draft guard',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = StationAppState.instance;
    final sync = OfflineSyncService.instance;
    sync.setConnectivityForTesting(false);
    state.switchStation(
        const Station(id: 'test-station', code: 'TEST', name: 'Test station'));
    const manager = UserProfile(
        id: 'test-manager',
        displayName: 'Test manager',
        fullName: 'Test manager',
        role: UserRole.manager,
        stationName: 'Test station');
    state.setCurrentUser(manager);
    expect(
        () => state.recordExpense(
            category: 'Maintenance',
            amount: 10,
            paymentSource: 'Cash Drawer',
            description: 'Test'),
        throwsStateError);
    state.applyOperationsPolicy(OperationsPolicy(
        revision: 1,
        cashierApprovalLimit: 25,
        managerApprovalLimit: 100,
        expenseCategories: ['Maintenance']));
    state.recordExpense(
        category: 'Maintenance',
        amount: 100,
        paymentSource: 'Cash Drawer',
        description: 'At configured limit');
    expect(state.expenses.first.status, 'Approved');
    state.recordExpense(
        category: 'Maintenance',
        amount: 101,
        paymentSource: 'Cash Drawer',
        description: 'Above configured limit');
    expect(state.expenses.first.status, 'Pending Approval');
    expect(state.approveExpense(expenseId: state.expenses.first.id), isFalse);
    expect(
        () => state.recordExpense(
            category: 'Not configured',
            amount: 10,
            paymentSource: 'Cash Drawer',
            description: 'Test'),
        throwsArgumentError);

    state.setCurrentUser(const UserProfile(
        id: 'test-director',
        displayName: 'Test director',
        fullName: 'Test director',
        role: UserRole.director,
        stationName: 'Test station'));
    final deposit = await state.recordBankDeposit(
        amount: 100,
        bankName: 'Test destination',
        bearerName: 'Test bearer',
        tellerNumber: 'TEST');
    expect(await state.confirmBankDeposit(deposit!.id), isFalse);
    expect(deposit.isConfirmed, isFalse);
    expect(deposit.status, 'awaiting_bank');
    expect(await state.flagBankDepositDiscrepancy(deposit.id, 'Test review'),
        isFalse);
    expect(deposit.status, 'awaiting_bank');

    var backed = false;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home:
            FuelDeliveryScreen(onBack: () => backed = true, onSuccess: () {})));
    await tester.pump();
    await tester.enterText(
        find.byType(TextFormField).first, 'Test supplier draft');
    expect(ShellBackGuard.hasUnsavedWork, isTrue);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(find.text('Discard fuel delivery?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(backed, isFalse);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => BankDepositDialog(
                            availableCash: 100, onDepositRecorded: () {})),
                    child: const Text('Open deposit'))))));
    await tester.tap(find.text('Open deposit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '50');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Discard deposit entry?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(BankDepositDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard deposit entry?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(BankDepositDialog), findsNothing);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const EvidencePreviewDialog(
            title: 'Receipt', reference: 'unretrievable.jpg')));
    await tester.pump();
    expect(find.textContaining('no retrievable evidence link'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const EvidencePreviewDialog(
            title: 'Receipt', reference: 'queued-offline://bucket/file.jpg')));
    await tester.pump();
    expect(find.textContaining('queued for upload'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(ShellBackGuard.hasUnsavedWork, isFalse);
    sync.dispose();
  });
}
