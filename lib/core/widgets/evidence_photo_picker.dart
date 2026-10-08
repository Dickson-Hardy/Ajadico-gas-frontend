import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/camera_compression_service.dart';
import '../../state/station_app_state.dart';

/// Interactive Forecourt Photo Evidence Picker with real-time compression audit
/// (BRD §4.3 & §3.7)
class EvidencePhotoPicker extends StatefulWidget {
  final String title;
  final String photoType; // 'pos_slip', 'bank_transfer', 'waybill', 'tank_dip'
  final String stationName;
  final String staffName;
  final String bucketName;
  final List<CompressedImageResult> initialPhotos;
  final ValueChanged<List<CompressedImageResult>> onPhotosChanged;
  final int maxPhotos;

  const EvidencePhotoPicker({
    super.key,
    required this.title,
    required this.photoType,
    required this.stationName,
    required this.staffName,
    required this.bucketName,
    required this.onPhotosChanged,
    this.initialPhotos = const [],
    this.maxPhotos = 4,
  });

  @override
  State<EvidencePhotoPicker> createState() => _EvidencePhotoPickerState();
}

class _EvidencePhotoPickerState extends State<EvidencePhotoPicker> {
  final List<CompressedImageResult> _photos = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _photos.addAll(widget.initialPhotos);
  }

  Future<void> _captureAndCompress() async {
    if (_photos.length >= widget.maxPhotos) return;

    setState(() => _isProcessing = true);

    try {
      // Real camera capture — user cancels return null (no fabricated photos)
      final XFile? shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (shot == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      final rawBytes = await shot.readAsBytes();

      final service = CameraCompressionService.instance;
      final compressed = await service.processAndCompressPhoto(
        photoType: widget.photoType,
        stationName: widget.stationName,
        staffName: widget.staffName,
        rawBytes: rawBytes,
      );

      // Upload to Supabase Storage or queue offline
      final uploaded = await service.uploadEvidence(
        image: compressed,
        bucketName: widget.bucketName,
        stationId: StationAppState.instance.currentStationCode,
      );

      setState(() {
        _photos.add(uploaded);
        _isProcessing = false;
      });

      widget.onPhotosChanged(_photos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bad,
          behavior: SnackBarBehavior.floating,
          content: Text('Could not capture evidence photo: $e'),
        ),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
    widget.onPhotosChanged(_photos);
  }

  Widget _buildPhotoThumbnail(CompressedImageResult photo) {
    const double thumbHeight = 56;
    final bytes = photo.imageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          bytes,
          width: double.infinity,
          height: thumbHeight,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _thumbnailPlaceholder(),
        ),
      );
    }

    final remoteUrl = photo.remoteStorageUrl;
    if (remoteUrl != null && remoteUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          remoteUrl,
          width: double.infinity,
          height: thumbHeight,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: double.infinity,
              height: thumbHeight,
              color: AppColors.lightBackground,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _thumbnailPlaceholder(),
        ),
      );
    }

    return _thumbnailPlaceholder();
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.photo_library_outlined, size: 22, color: AppColors.slate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_photos.length}/${widget.maxPhotos}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Photos gallery & capture button
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Add photo button
              if (_photos.length < widget.maxPhotos)
                InkWell(
                  onTap: _isProcessing ? null : _captureAndCompress,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 130,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                    ),
                    child: _isProcessing
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Compressing...',
                                  style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.lightEmerald,
                                child: Icon(Icons.add_a_photo, color: AppColors.primary, size: 18),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Take Photo',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '< 150KB Target',
                                style: TextStyle(fontSize: 12, color: AppColors.slate),
                              ),
                            ],
                          ),
                  ),
                ),

              const SizedBox(width: 10),

              // Existing photos
              ...List.generate(_photos.length, (index) {
                final photo = _photos[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      Container(
                        width: 150,
                        height: 160,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: photo.isUploaded
                                    ? AppColors.emerald.withValues(alpha: 0.2)
                                    : AppColors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    photo.isUploaded ? Icons.cloud_done : Icons.cloud_queue,
                                    size: 14,
                                    color: photo.isUploaded ? AppColors.emerald : AppColors.amber,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    photo.isUploaded ? 'UPLOADED' : 'OFFLINE Q',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: photo.isUploaded ? AppColors.emerald : AppColors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildPhotoThumbnail(photo),
                            // File size compression metrics
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  photo.compressedSizeFormatted,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                if (photo.compressionRatioPercent > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Was ${photo.originalSizeFormatted} (-${photo.compressionRatioPercent.toStringAsFixed(0)}%)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.emerald,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  photo.watermarkStamp ?? 'Watermarked',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.slate,
                                    ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Tooltip(
                            message: 'Remove photo',
                            child: InkWell(
                              onTap: () => _removePhoto(index),
                              borderRadius: BorderRadius.circular(24),
                              child: Center(
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: AppColors.bad,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
