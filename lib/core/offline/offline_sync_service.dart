import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../network/supabase_repository.dart';
import 'sync_queue_item.dart';

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
  OfflineSyncService._internal() {
    _startPeriodicConnectivityCheck();
  }

  final List<SyncQueueItem> _queue = [];
  bool _isOnline = true;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  String? _activeItemTitle;
  Timer? _heartbeatTimer;

  List<SyncQueueItem> get queue => List.unmodifiable(_queue);
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _queue.where((e) => e.status == SyncItemStatus.pending).length;
  int get failedCount => _queue.where((e) => e.status == SyncItemStatus.failed).length;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  SyncStatusInfo get statusInfo => SyncStatusInfo(
        isOnline: _isOnline,
        isSyncing: _isSyncing,
        pendingCount: pendingCount,
        failedCount: failedCount,
        lastSyncedAt: _lastSyncedAt,
        activeItemTitle: _activeItemTitle,
      );

  /// Toggle simulated connectivity for testing and demo purposes
  void setSimulatedConnectivity(bool online) {
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
  }) async {
    final item = SyncQueueItem(
      id: explicitId ?? generateIdempotencyKey(actionType.name.substring(0, 3).toUpperCase()),
      actionType: actionType,
      payload: payload,
      createdAt: DateTime.now(),
      status: SyncItemStatus.pending,
    );

    _queue.add(item);
    notifyListeners();

    // If online, immediately attempt synchronization
    if (_isOnline && !_isSyncing) {
      unawaited(triggerSync());
    }

    return item;
  }

  /// Trigger synchronization of all pending items in FIFO order
  Future<void> triggerSync() async {
    if (_isSyncing || !_isOnline) return;

    final pendingItems = _queue
        .where((e) => e.status == SyncItemStatus.pending || e.status == SyncItemStatus.failed)
        .toList();

    if (pendingItems.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    final repo = SupabaseRepository.instance;

    for (final item in pendingItems) {
      if (!_isOnline) break;

      item.status = SyncItemStatus.syncing;
      item.lastAttemptedAt = DateTime.now();
      _activeItemTitle = item.humanTitle;
      notifyListeners();

      try {
        final success = await _dispatchItem(item, repo);

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

      notifyListeners();
      // Brief debounce between queue items
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isSyncing = false;
    _activeItemTitle = null;
    notifyListeners();
  }

  /// Dispatch an individual item to SupabaseRepository
  Future<bool> _dispatchItem(SyncQueueItem item, SupabaseRepository repo) async {
    final p = item.payload;

    switch (item.actionType) {
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

      case SyncActionType.evidencePhotoUpload:
        return await repo.syncEvidencePhotoPayload(p);

      case SyncActionType.evidencePhoto:
        return await repo.syncEvidencePhotoPayload(p);
    }
  }

  /// Retry all failed items manually
  void retryFailedItems() {
    for (final item in _queue) {
      if (item.status == SyncItemStatus.failed) {
        item.status = SyncItemStatus.pending;
      }
    }
    notifyListeners();
    triggerSync();
  }

  /// Clear completed items
  void clearCompleted() {
    _queue.removeWhere((e) => e.status == SyncItemStatus.completed);
    notifyListeners();
  }

  void _startPeriodicConnectivityCheck() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      // Check live connection status if repository is active
      final repo = SupabaseRepository.instance;
      final connected = repo.isConnected;
      if (connected != _isOnline) {
        _isOnline = connected;
        notifyListeners();
        if (_isOnline && pendingCount > 0) {
          triggerSync();
        }
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
