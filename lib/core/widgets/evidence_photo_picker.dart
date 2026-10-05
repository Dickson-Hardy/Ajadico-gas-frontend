import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/camera_compression_service.dart';

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
      final service = CameraCompressionService.instance;
      // Process and compress photo
      final compressed = await service.processAndCompressPhoto(
        photoType: widget.photoType,
        stationName: widget.stationName,
        staffName: widget.staffName,
      );

      // Upload to Supabase Storage or queue offline
      final uploaded = await service.uploadEvidence(
        image: compressed,
        bucketName: widget.bucketName,
        stationId: 'lekki-01',
      );

      setState(() {
        _photos.add(uploaded);
        _isProcessing = false;
      });

      widget.onPhotosChanged(_photos);
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
    widget.onPhotosChanged(_photos);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
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
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.4),
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
                                  style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
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
                                style: TextStyle(fontSize: 10, color: AppColors.slate),
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
                        width: 140,
                        height: 120,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: photo.isUploaded
                                        ? AppColors.emerald.withOpacity(0.2)
                                        : AppColors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        photo.isUploaded ? Icons.cloud_done : Icons.cloud_queue,
                                        size: 11,
                                        color: photo.isUploaded ? AppColors.emerald : AppColors.amber,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        photo.isUploaded ? 'UPLOADED' : 'OFFLINE Q',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: photo.isUploaded ? AppColors.emerald : AppColors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
                                const SizedBox(height: 2),
                                Text(
                                  'Was ${photo.originalSizeFormatted} (-${photo.compressionRatioPercent.toStringAsFixed(0)}%)',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.emerald,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  photo.watermarkStamp ?? 'Watermarked',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: AppColors.mutedSlate,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _removePhoto(index),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.redAccent,
                            child: Icon(Icons.close, color: Colors.white, size: 13),
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
