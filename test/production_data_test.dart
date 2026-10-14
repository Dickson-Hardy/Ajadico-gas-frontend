import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajadico_gas/core/network/supabase_repository.dart';
import 'package:ajadico_gas/core/offline/offline_sync_service.dart';
import 'package:ajadico_gas/core/offline/sync_queue_item.dart';
import 'package:ajadico_gas/models/bank_deposit.dart';
import 'package:ajadico_gas/models/station.dart';
import 'package:ajadico_gas/models/user_profile.dart';
import 'package:ajadico_gas/state/station_app_state.dart';

void main() {
  testWidgets(
      'unconfigured app has no invented records or successful offline writes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = StationAppState.instance;
    final repo = SupabaseRepository.instance;
    final sync = OfflineSyncService.instance;
    expect(state.currentUser, UserProfile.signedOut);
    expect(state.currentUser.isActive, isFalse);
    expect(state.currentStationId, isEmpty);
    expect(state.currentStationCode, isEmpty);
    expect(state.stations, isEmpty);
    expect(state.staff, isEmpty);
    expect(state.nozzles, isEmpty);
    expect(state.tanks, isEmpty);
    expect(state.pmsPrice, 0);
    expect(state.agoPrice, 0);
    expect(() => state.recordClosingReadings({}), throwsStateError);
    expect(await repo.fetchLivePrices('UNCONFIGURED'), isEmpty);
    expect(await repo.fetchStationInfo('UNCONFIGURED'), isNull);
    expect(
        await repo.verifyAttendantPin(
            stationId: '', profileId: 'director', pin: '998811'),
        containsPair('success', false));
    expect(await repo.updateStaffSalary(profileId: 'missing', baseSalary: 1),
        isFalse);
    expect(
        await repo.confirmBankDeposit(
            depositId: 'missing', directorId: 'missing'),
        isFalse);
    expect(await repo.syncClosingReadingsPayload({}), isFalse);
    expect(await repo.syncRemittancePayload({}), isFalse);
    expect(await repo.syncPriceChangePayload({}), isFalse);
    expect(
        await repo.recordBankDeposit(
            stationCode: '',
            stationName: '',
            amount: 100,
            bankName: 'Actual bank',
            bearerName: 'Actual bearer'),
        isNull);

    final localDeposit = await repo.recordBankDeposit(
        stationCode: 'REAL-BRANCH',
        stationName: 'Registered branch',
        amount: 100,
        bankName: 'Actual bank',
        bearerName: 'Actual bearer');
    expect(localDeposit?.stationId, 'REAL-BRANCH');
    expect(localDeposit?.stationName, 'Registered branch');
    expect(
        BankDepositRecord.fromJson({
          'id': 'legacy',
          'amount': 100,
        }).bankName,
        'Bank not recorded');

    sync.setConnectivityForTesting(false);
    await sync.enqueue(actionType: SyncActionType.priceChange, payload: {});
    sync.setConnectivityForTesting(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sync.queue, hasLength(1));
    expect(sync.queue.single.status, SyncItemStatus.pending);
    expect(sync.heldCount, 1);
    expect(sync.queue.single.status, isNot(SyncItemStatus.completed));

    state.switchStation(const Station(
        id: 'configured-id', code: 'REAL-BRANCH', name: 'Registered branch'));
    expect(state.currentStationId, 'configured-id');
    state.setCurrentUser(const UserProfile(
        id: 'registered-director',
        displayName: 'Registered director',
        fullName: 'Registered director',
        role: UserRole.director,
        stationName: 'Registered branch'));
    state.clearSession();
    expect(state.currentUser, UserProfile.signedOut);
    expect(state.closingReadingsSubmitted, isFalse);
    expect(state.remittanceSubmitted, isFalse);
    sync.dispose();
  });
}
