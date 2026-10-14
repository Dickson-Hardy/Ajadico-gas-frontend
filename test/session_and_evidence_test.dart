import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ajadico_gas/core/network/supabase_repository.dart';
import 'package:ajadico_gas/core/offline/offline_sync_service.dart';
import 'package:ajadico_gas/core/offline/sync_queue_item.dart';
import 'package:ajadico_gas/core/storage/evidence_reference.dart';

void main() {
  test('logout during replay never dispatches the next item as another user',
      () async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(
        'https://test.invalid', 'test-only-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    Future<void> identity(String id) =>
        client.auth.setInitialSession(jsonEncode({
          'access_token': 'test-only-token-$id',
          'refresh_token': 'test-only-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          'user': {
            'id': id,
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': DateTime(2026).toIso8601String()
          }
        }));
    await identity('auth-a');
    final repo = SupabaseRepository.forTesting(client,
        endpoint: 'https://test.invalid',
        publishableKey: 'test-only-public-key');
    final started = Completer<void>();
    final finish = Completer<bool>();
    final actors = <String?>[];
    final sync = OfflineSyncService.forTesting(
        repository: repo,
        dispatch: (item, snapshot) async {
          actors.add(snapshot.authUserId);
          if (!started.isCompleted) {
            started.complete();
            return finish.future;
          }
          return true;
        });
    sync.bindOwner(
        profileId: 'staff-a', authUserId: 'auth-a', stationId: 'branch');
    final capture = sync.captureOwner;
    await sync.enqueue(
        actionType: SyncActionType.branchExpense,
        payload: {},
        explicitId: 'a-1');
    await sync.enqueue(
        actionType: SyncActionType.branchExpense,
        payload: {},
        explicitId: 'a-2');
    sync.setConnectivityForTesting(true);
    await started.future;
    sync.bindOwner();
    await identity('auth-b');
    sync.bindOwner(
        profileId: 'staff-b', authUserId: 'auth-b', stationId: 'branch');
    await sync.enqueue(
        actionType: SyncActionType.branchExpense,
        payload: {},
        explicitId: 'a-late',
        owner: capture);
    await sync.enqueue(
        actionType: SyncActionType.branchExpense,
        payload: {},
        explicitId: 'b-1');
    finish.complete(true);
    for (var attempt = 0; attempt < 100 && actors.length < 2; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(actors, ['auth-a', 'auth-b']);
    expect(sync.queue.map((item) => item.id), ['a-2', 'a-late']);
    expect(sync.heldCount, 2);
    sync.dispose();
    await client.dispose();
  });
  test('outbox ownership survives restart and rejects other users and branches',
      () {
    final item = SyncQueueItem(
        id: 'test',
        actionType: SyncActionType.branchExpense,
        payload: {},
        createdAt: DateTime(2026),
        ownerProfileId: 'staff-a',
        ownerAuthUserId: 'auth-a',
        ownerStationId: 'station-a');
    final restored = SyncQueueItem.fromJson(item.toJson());
    expect(restored.belongsTo('staff-a', 'auth-a', 'station-a'), isTrue);
    expect(restored.belongsTo('staff-b', 'auth-a', 'station-a'), isFalse);
    expect(restored.belongsTo('staff-a', 'auth-b', 'station-a'), isFalse);
    expect(restored.belongsTo('staff-a', 'auth-a', 'station-b'), isFalse);
    expect(restored.belongsTo(null, null, null), isFalse);
    final legacy = SyncQueueItem.fromJson({
      ...item.toJson(),
      'ownerProfileId': null,
      'ownerAuthUserId': null,
      'ownerStationId': null
    });
    expect(legacy.belongsTo('staff-a', 'auth-a', 'station-a'), isFalse);
  });

  test(
      'evidence references are durable and reject traversal or foreign origins',
      () {
    const ref =
        EvidenceReference('expense-receipts', 'station/day/photo name.jpg');
    expect(EvidenceReference.parse(ref.value)?.path, ref.path);
    expect(
        EvidenceReference.parse(
                'queued-offline://expense-receipts/station/day/photo.jpg')
            ?.bucket,
        'expense-receipts');
    expect(
        EvidenceReference.parse(
            'storage://expense-receipts/station/%2e%2e/photo.jpg'),
        isNull);
    expect(
        EvidenceReference.parse(
            'storage://expense-receipts/station/%2F/photo.jpg'),
        isNull);
    expect(
        EvidenceReference.parse('storage://unknown/station/photo.jpg'), isNull);
    expect(EvidenceReference.parse('photo.jpg'), isNull);
    expect(EvidenceReference.parse('https://project.example/storage/v1/object/public/expense-receipts/s/p.jpg',
        endpoint: ''), isNull);
    expect(
        EvidenceReference.parse(
            'https://foreign.example/storage/v1/object/public/expense-receipts/s/p.jpg',
            endpoint: 'https://project.example'),
        isNull);
    expect(
        EvidenceReference.parse(
                'https://project.example/storage/v1/object/public/expense-receipts/s/p.jpg',
                endpoint: 'https://project.example')
            ?.value,
        'storage://expense-receipts/s/p.jpg');
  });
}
