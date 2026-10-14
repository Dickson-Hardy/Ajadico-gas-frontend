import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/supabase_repository.dart';
import 'sync_queue_item.dart';

class QueueOwner {
  const QueueOwner(
      this.profileId, this.authUserId, this.stationId, this.generation);
  final String? profileId;
  final String? authUserId;
  final String? stationId;
  final int generation;
}

/// Connection and sync status indicator data
class SyncStatusInfo {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncedAt;
  final String? activeItemTitle;

  const SyncStatusInfo({
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
    required this.failedCount,
    this.lastSyncedAt,
    this.activeItemTitle,
  });

  bool get isAllSynced => pendingCount == 0 && failedCount == 0;
}

/// Offline-First Forecourt Sync Engine (BRD §2, §4, §5)
/// Handles intermittent cellular/power connectivity on pump island tablets,
/// guarantees idempotent outbox queuing, and executes FIFO synchronization.
class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService instance = OfflineSyncService._internal();
  OfflineSyncService._internal() : _repository = SupabaseRepository.instance {
    _isOnline = _repository.isConnected;
    _startPeriodicConnectivityCheck();
    _initPrefs();
  }

  @visibleForTesting
  OfflineSyncService.forTesting(
      {required SupabaseRepository repository,
      required Future<bool> Function(SyncQueueItem, SupabaseRepository)
          dispatch})
      : _repository = repository,
        _testDispatch = dispatch {
    if (kReleaseMode) throw StateError('Test sync services are disabled');
  }
  final SupabaseRepository _repository;
  Future<bool> Function(SyncQueueItem, SupabaseRepository)? _testDispatch;

  static const String _prefsKey = 'offline_sync_queue';
  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromDisk();
  }

  void _loadFromDisk() {
    if (_prefs == null) return;
    final jsonString = _prefs!.getString(_prefsKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = json.decode(jsonString);
        final diskItems = decoded
            .map((e) =>
                SyncQueueItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        for (final item in diskItems) {
          if (item.status == SyncItemStatus.syncing)
            item.status = SyncItemStatus.pending;
        }
        // Preserve any in-memory items enqueued before async prefs resolution
        for (final item in _queue) {
          if (!diskItems.any((d) => d.id == item.id)) {
            diskItems.add(item);
          }
        }
        _queue.clear();
        _queue.addAll(diskItems);
        _saveToDisk();
        notifyListeners();
        if (_isOnline && pendingCount > 0) {
          triggerSync();
        }
      } catch (e) {
        debugPrint('Error loading sync queue: $e');
      }
    } else if (_queue.isNotEmpty) {
      _saveToDisk();
    }
  }

  void _saveToDisk() {
    if (_prefs == null) return;
    final jsonString = json.encode(_queue.map((e) => e.toJson()).toList());
    _prefs!.setString(_prefsKey, jsonString);
  }

  final List<SyncQueueItem> _queue = [];
  bool _isOnline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  String? _activeItemTitle;
  Timer? _heartbeatTimer;
  String? _ownerProfileId;
  String? _ownerAuthUserId;
  String? _ownerStationId;
  int _sessionGeneration = 0;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  QueueOwner get captureOwner => QueueOwner(
      _ownerProfileId, _ownerAuthUserId, _ownerStationId, _sessionGeneration);
  bool isCurrentOwner(QueueOwner owner) =>
      owner.generation == _sessionGeneration &&
      owner.profileId == _ownerProfileId &&
      owner.authUserId == _ownerAuthUserId &&
      owner.stationId == _ownerStationId;

  void bindOwner({String? profileId, String? authUserId, String? stationId}) {
    _sessionGeneration++;
    _ownerProfileId = profileId;
    _ownerAuthUserId = authUserId;
    _ownerStationId = stationId;
    if (_isOnline && !_isSyncing) unawaited(triggerSync());
  }

  bool _mayReplay(SyncQueueItem item) =>
      _repository.authUserId == _ownerAuthUserId &&
      item.belongsTo(_ownerProfileId, _ownerAuthUserId, _ownerStationId);

  int get heldCount => _queue.where((item) => !_mayReplay(item)).length;

  List<SyncQueueItem> get queue => List.unmodifiable(_queue);
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount =>
      _queue.where((e) => e.status == SyncItemStatus.pending).length;
  int get failedCount =>
      _queue.where((e) => e.status == SyncItemStatus.failed).length;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  SyncStatusInfo get statusInfo => SyncStatusInfo(
        isOnline: _isOnline,
        isSyncing: _isSyncing,
        pendingCount: pendingCount,
        failedCount: failedCount,
        lastSyncedAt: _lastSyncedAt,
        activeItemTitle: _activeItemTitle,
      );

  /// Test-only control; production connectivity comes from the repository.
  @visibleForTesting
  void setConnectivityForTesting(bool online) {
    if (kReleaseMode)
      throw StateError('Test connectivity controls are disabled');
    _isOnline = online;
    notifyListeners();
    if (_isOnline && pendingCount > 0) {
      triggerSync();
    }
  }

  /// Generate a unique idempotent transaction key
  String generateIdempotencyKey(String prefix) {
    final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$prefix-$ts-$rand';
  }

  /// Enqueue an action to the persistent outbox queue
  Future<SyncQueueItem> enqueue({
    required SyncActionType actionType,
    required Map<String, dynamic> payload,
    String? explicitId,
    QueueOwner? owner,
  }) async {
    if (_disposed) throw StateError('The sync service has been closed');
    final originatingOwner = owner ?? captureOwner;
    final item = SyncQueueItem(
      id: explicitId ??
          generateIdempotencyKey(actionType.name.substring(0, 3).toUpperCase()),
      actionType: actionType,
      payload: payload,
      createdAt: DateTime.now(),
      ownerProfileId: originatingOwner.profileId,
      ownerAuthUserId: originatingOwner.authUserId,
      ownerStationId: originatingOwner.stationId,
      status: SyncItemStatus.pending,
    );

    _queue.add(item);
    _saveToDisk();
    notifyListeners();

    // If online, immediately attempt synchronization
    if (_isOnline && !_isSyncing) {
      unawaited(triggerSync());
    }

    return item;
  }

  /// Trigger synchronization of all pending items in FIFO order
  Future<void> triggerSync() async {
    if (_disposed || _isSyncing || !_isOnline) return;

    final pendingItems = _queue
        .where((e) =>
            e.status == SyncItemStatus.pending ||
            e.status == SyncItemStatus.failed)
        .where(_mayReplay)
        .toList();

    if (pendingItems.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    final generation = _sessionGeneration;
    final repo = _repository.snapshotForAuthenticatedSession();
    if (repo == null) {
      _isSyncing = false;
      notifyListeners();
      return;
    }

    for (final item in pendingItems) {
      if (!_isOnline || generation != _sessionGeneration || !_mayReplay(item))
        break;

      item.status = SyncItemStatus.syncing;
      item.lastAttemptedAt = DateTime.now();
      _activeItemTitle = item.humanTitle;
      notifyListeners();

      try {
        final success = await (_testDispatch?.call(item, repo) ??
            _dispatchItem(item, repo));

        if (success) {
          item.status = SyncItemStatus.completed;
          item.lastError = null;
          _lastSyncedAt = DateTime.now();
          // Remove completed item from active queue
          _queue.remove(item);
        } else {
          item.status = SyncItemStatus.failed;
          item.retryCount += 1;
          item.lastError = 'Remote persistence rejected transaction';
        }
      } catch (e) {
        item.status = SyncItemStatus.failed;
        item.retryCount += 1;
        item.lastError = e.toString();
        // If network error occurred, assume offline
        if (e.toString().toLowerCase().contains('socket') ||
            e.toString().toLowerCase().contains('connection') ||
            e.toString().toLowerCase().contains('network')) {
          _isOnline = false;
        }
      }

      _saveToDisk();
      notifyListeners();
      // Brief debounce between queue items
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await repo.closeSessionSnapshot();
    _isSyncing = false;
    _activeItemTitle = null;
    notifyListeners();
    if (generation != _sessionGeneration && _isOnline) unawaited(triggerSync());
  }

  /// Dispatch an individual item to SupabaseRepository
  Future<bool> _dispatchItem(
      SyncQueueItem item, SupabaseRepository repo) async {
    final p = item.payload;

    switch (item.actionType) {
      case SyncActionType.shiftAdjustment:
        return await repo.syncShiftAdjustmentPayload(p);
      case SyncActionType.closingReadings:
        // Closing meter entries
        return await repo.syncClosingReadingsPayload(p);

      case SyncActionType.remittanceSubmission:
        return await repo.syncRemittancePayload(p);

      case SyncActionType.creditSale:
        return await repo.syncCreditSalePayload(p);

      case SyncActionType.fuelReturn:
        return await repo.syncFuelReturnPayload(p);

      case SyncActionType.dailyCashAudit:
        return await repo.syncDailyCashAuditPayload(p);

      case SyncActionType.branchExpense:
        return await repo.syncBranchExpensePayload(p);

      case SyncActionType.tankDipAudit:
        return await repo.syncTankDipPayload(p);

      case SyncActionType.fuelDelivery:
        return await repo.syncFuelDeliveryPayload(p);

      case SyncActionType.priceChange:
        return await repo.syncPriceChangePayload(p);

      case SyncActionType.salaryAdjustment:
        return await repo.syncSalaryAdjustmentPayload(p);

      case SyncActionType.bankDepositConfirmation:
        return await repo.syncBankDepositPayload(p);

      case SyncActionType.bankDepositRecord:
        return await repo.syncBankDepositRecordPayload(p);

      case SyncActionType.interimCashDrop:
        return await repo.syncInterimCashDropPayload(p);

      case SyncActionType.posTransaction:
        return await repo.syncPosTransactionPayload(p);

      case SyncActionType.evidencePhotoUpload:
        return await repo.syncEvidencePhotoPayload(p);

      case SyncActionType.evidencePhoto:
        return await repo.syncEvidencePhotoPayload(p);

      case SyncActionType.remittanceVerification:
        return await repo.syncRemittanceVerificationPayload(p);

      case SyncActionType.shortageAdjustment:
        return await repo.syncShortageAdjustmentPayload(p);

      case SyncActionType.creditRepayment:
        return await repo.syncCreditRepaymentPayload(p);

      case SyncActionType.tankStock:
        return await repo.syncTankStockPayload(p);

      case SyncActionType.notification:
        return await repo.syncNotificationPayload(p);

      case SyncActionType.shiftSession:
        return await repo.syncShiftSessionPayload(p);

      case SyncActionType.tankCreate:
        return await repo.syncTankCreatePayload(p);

      case SyncActionType.nozzleCreate:
        return await repo.syncNozzleCreatePayload(p);

      case SyncActionType.creditCustomerCreate:
        return await repo.syncCreditCustomerCreatePayload(p);
    }
  }

  /// Retry all failed items manually
  void retryFailedItems() {
    for (final item in _queue) {
      if (item.status == SyncItemStatus.failed) {
        item.status = SyncItemStatus.pending;
      }
    }
    _saveToDisk();
    notifyListeners();
    triggerSync();
  }

  /// Clear completed items
  void clearCompleted() {
    _queue.removeWhere((e) => e.status == SyncItemStatus.completed);
    _saveToDisk();
    notifyListeners();
  }

  void _startPeriodicConnectivityCheck() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
      // Check live connection status if repository is active
      final repo = _repository;
      final connected = repo.isConnected;
      if (connected != _isOnline) {
        _isOnline = connected;
        notifyListeners();
      }
      // Includes unchanged connectivity: a refreshed token must be able to
      // resume work rejected when an earlier frozen JWT expired.
      if (_isOnline && !_isSyncing && (pendingCount > 0 || failedCount > 0)) {
        unawaited(triggerSync());
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _isOnline = false;
    _sessionGeneration++;
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
