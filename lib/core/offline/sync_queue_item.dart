import 'dart:convert';

/// Status of an item in the offline synchronization queue
enum SyncItemStatus {
  pending,
  syncing,
  failed,
  completed,
}

/// Type of operational forecourt transaction
enum SyncActionType {
  closingReadings,
  remittanceSubmission,
  creditSale,
  fuelReturn,
  dailyCashAudit,
  branchExpense,
  tankDipAudit,
  fuelDelivery,
  priceChange,
  salaryAdjustment,
  bankDepositConfirmation,
  evidencePhotoUpload,
}

/// Represents an idempotent forecourt transaction queued for database synchronization
class SyncQueueItem {
  final String id; // UUID / Idempotency Key
  final SyncActionType actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  SyncItemStatus status;
  int retryCount;
  String? lastError;
  DateTime? lastAttemptedAt;

  SyncQueueItem({
    required this.id,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    this.status = SyncItemStatus.pending,
    this.retryCount = 0,
    this.lastError,
    this.lastAttemptedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actionType': actionType.name,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'retryCount': retryCount,
      'lastError': lastError,
      'lastAttemptedAt': lastAttemptedAt?.toIso8601String(),
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      actionType: SyncActionType.values.firstWhere(
        (e) => e.name == json['actionType'],
        orElse: () => SyncActionType.remittanceSubmission,
      ),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: SyncItemStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SyncItemStatus.pending,
      ),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      lastAttemptedAt: json['lastAttemptedAt'] != null
          ? DateTime.parse(json['lastAttemptedAt'] as String)
          : null,
    );
  }

  String get humanTitle {
    switch (actionType) {
      case SyncActionType.closingReadings:
        return 'Meter Closing Readings';
      case SyncActionType.remittanceSubmission:
        return 'Attendant Shift Remittance';
      case SyncActionType.creditSale:
        return 'Credit Account Dispense';
      case SyncActionType.fuelReturn:
        return 'Underground Tank Fuel Return';
      case SyncActionType.dailyCashAudit:
        return 'Cashier Daily Safe Audit';
      case SyncActionType.branchExpense:
        return 'Station Petty Cash Expense';
      case SyncActionType.tankDipAudit:
        return 'Underground Tank Dip Calibration';
      case SyncActionType.fuelDelivery:
        return 'Tanker Fuel Discharge Audit';
      case SyncActionType.priceChange:
        return 'Forecourt Retail Price Change';
      case SyncActionType.salaryAdjustment:
        return 'Attendant Shortage Deduction';
      case SyncActionType.bankDepositConfirmation:
        return 'Commercial Bank Deposit Verification';
      case SyncActionType.evidencePhotoUpload:
        return 'Forecourt Receipt / Waybill Photo';
    }
  }
}
