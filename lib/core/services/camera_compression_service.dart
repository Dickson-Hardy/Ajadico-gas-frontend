import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../network/supabase_repository.dart';
import '../offline/offline_sync_service.dart';
import '../offline/sync_queue_item.dart';

/// Metadata for compressed photographic evidence
class CompressedImageResult {
  final String localId;
  final String fileName;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final double compressionRatioPercent;
  final Uint8List? imageBytes;
  final String base64Preview;
  final String? remoteStorageUrl;
  final String? watermarkStamp;
  final DateTime capturedAt;
  final bool isUploaded;

  CompressedImageResult({
    required this.localId,
    required this.fileName,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.compressionRatioPercent,
    this.imageBytes,
    required this.base64Preview,
    this.remoteStorageUrl,
    this.watermarkStamp,
    required this.capturedAt,
    this.isUploaded = false,
  });

  String get originalSizeFormatted => _formatBytes(originalSizeBytes);
  String get compressedSizeFormatted => _formatBytes(compressedSizeBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'fileName': fileName,
      'originalSizeBytes': originalSizeBytes,
      'compressedSizeBytes': compressedSizeBytes,
      'compressionRatioPercent': compressionRatioPercent,
      'base64Preview': base64Preview,
      'remoteStorageUrl': remoteStorageUrl,
      'watermarkStamp': watermarkStamp,
      'capturedAt': capturedAt.toIso8601String(),
      'isUploaded': isUploaded,
    };
  }
}

/// Pipeline for capturing, compressing, watermarking, and uploading forecourt photos
/// BRD §4.3 (POS card slips & receipts) & §3.7 (Tanker waybills & dip stick audit)
class CameraCompressionService {
  static final CameraCompressionService instance = CameraCompressionService._internal();
  CameraCompressionService._internal();

  /// Real capture pipeline: processes actual camera bytes (already platform-compressed
  /// by the picker at capture time) and records their true sizes. No fabricated data.
  Future<CompressedImageResult> processAndCompressPhoto({
    required String photoType, // 'pos_slip', 'bank_transfer', 'waybill', 'tank_dip'
    required String stationName,
    required String staffName,
    required Uint8List rawBytes,
    String? explicitFileName,
  }) async {
    if (rawBytes.isEmpty) {
      throw ArgumentError('Evidence photo requires real image bytes.');
    }

    final now = DateTime.now();
    final localId = 'IMG-${now.millisecondsSinceEpoch}-${Random().nextInt(9999).toString().padLeft(4, '0')}';
    final fileName = explicitFileName ?? '${photoType}_$localId.jpg';

    // True sizes of the actual image being stored (platform compresses at capture).
    final originalBytes = rawBytes.length;
    final compressedBytes = rawBytes.length;

    // Audit stamp overlay metadata (Watermark for anti-fraud)
    final watermarkStamp = 'AJADICO $stationName | $staffName | ${now.toIso8601String().substring(0, 19).replaceAll('T', ' ')} | $photoType';

    final result = CompressedImageResult(
      localId: localId,
      fileName: fileName,
      originalSizeBytes: originalBytes,
      compressedSizeBytes: compressedBytes,
      compressionRatioPercent: 0,
      imageBytes: rawBytes,
      base64Preview: '',
      watermarkStamp: watermarkStamp,
      capturedAt: now,
      isUploaded: false,
    );

    return result;
  }

  /// Upload compressed evidence directly to Supabase Storage or queue offline
  Future<CompressedImageResult> uploadEvidence({
    required CompressedImageResult image,
    required String bucketName, // 'remittance-evidence' or 'delivery-waybills'
    required String stationId,
  }) async {
    final syncService = OfflineSyncService.instance;
    final repo = SupabaseRepository.instance;

    final storagePath = '$stationId/${image.capturedAt.toIso8601String().substring(0, 10)}/${image.fileName}';

    if (syncService.isOnline && repo.isConnected) {
      try {
        final publicUrl = await repo.uploadStorageFile(
          bucket: bucketName,
          path: storagePath,
          fileBytes: image.imageBytes!,
        );

        if (publicUrl != null) {
          return CompressedImageResult(
            localId: image.localId,
            fileName: image.fileName,
            originalSizeBytes: image.originalSizeBytes,
            compressedSizeBytes: image.compressedSizeBytes,
            compressionRatioPercent: image.compressionRatioPercent,
            imageBytes: image.imageBytes,
            base64Preview: image.base64Preview,
            remoteStorageUrl: publicUrl,
            watermarkStamp: image.watermarkStamp,
            capturedAt: image.capturedAt,
            isUploaded: true,
          );
        }
        // Upload failed → fall through to offline outbox with real bytes
      } catch (e) {
        // Fall back to offline queue
      }
    }

    // Offline outbox queue fallback — carries the real image bytes so the
    // later sync can perform the actual Storage upload (no metadata-only records)
    await syncService.enqueue(
      actionType: SyncActionType.evidencePhotoUpload,
      payload: {
        'bucket': bucketName,
        'path': storagePath,
        'localId': image.localId,
        'watermark': image.watermarkStamp,
        'compressedSize': image.compressedSizeBytes,
        'fileName': image.fileName,
        'imageBase64': base64Encode(image.imageBytes!),
      },
    );

    return CompressedImageResult(
      localId: image.localId,
      fileName: image.fileName,
      originalSizeBytes: image.originalSizeBytes,
      compressedSizeBytes: image.compressedSizeBytes,
      compressionRatioPercent: image.compressionRatioPercent,
      imageBytes: image.imageBytes,
      base64Preview: image.base64Preview,
      remoteStorageUrl: 'queued-offline://$bucketName/$storagePath',
      watermarkStamp: image.watermarkStamp,
      capturedAt: image.capturedAt,
      isUploaded: false,
    );
  }
}
