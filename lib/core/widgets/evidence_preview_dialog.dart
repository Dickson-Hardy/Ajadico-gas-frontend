import 'package:flutter/material.dart';
import '../network/supabase_repository.dart';
import '../storage/evidence_reference.dart';
import '../config/supabase_config.dart';
import '../../state/station_app_state.dart';

/// Resolves durable references at viewing time; signed links never enter records.
class EvidencePreviewDialog extends StatefulWidget {
  const EvidencePreviewDialog({super.key, required this.title, this.reference});
  final String title;
  final String? reference;

  static Future<void> show(BuildContext context,
          {required String title, String? reference}) =>
      showDialog<void>(
          context: context,
          builder: (_) =>
              EvidencePreviewDialog(title: title, reference: reference));

  @override
  State<EvidencePreviewDialog> createState() => _EvidencePreviewDialogState();
}

class _EvidencePreviewDialogState extends State<EvidencePreviewDialog> {
  late Future<String?> _url;
  String? _actor;
  String? _profile;
  String? _station;
  @override
  void initState() {
    super.initState();
    _load();
    StationAppState.instance.addListener(_sessionChanged);
  }

  @override
  void didUpdateWidget(covariant EvidencePreviewDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference) _load();
  }

  void _load() {
    final app = StationAppState.instance;
    _actor = SupabaseRepository.instance.authUserId;
    _profile = app.currentUser.id;
    _station = app.currentStationId;
    _url = app.currentUser.isActive
        ? SupabaseRepository.instance.resolveEvidenceUrl(widget.reference)
        : Future.value(null);
  }

  void _sessionChanged() {
    final app = StationAppState.instance;
    if (mounted &&
        (_actor != SupabaseRepository.instance.authUserId ||
            _profile != app.currentUser.id ||
            _station != app.currentStationId)) setState(_load);
  }

  @override
  void dispose() {
    StationAppState.instance.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.reference?.trim() ?? '';
    final queued = Uri.tryParse(value)?.scheme == 'queued-offline';
    final valid =
        EvidenceReference.parse(value, endpoint: SupabaseConfig.url) != null;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
          width: 600,
          height: (MediaQuery.sizeOf(context).height * 0.5).clamp(180.0, 440.0),
          child: FutureBuilder<String?>(
              future: _url,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final app = StationAppState.instance;
                final url = app.currentUser.isActive &&
                        _profile == app.currentUser.id &&
                        _station == app.currentStationId &&
                        _actor == SupabaseRepository.instance.authUserId
                    ? snapshot.data
                    : null;
                if (url != null) {
                  return InteractiveViewer(
                      child: Image.network(url,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator()),
                          errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                  'Evidence could not be loaded. Retry to renew access.'))));
                }
                return Center(
                    child: Text(queued
                        ? 'This evidence is queued for upload or unavailable to this account. Complete synchronization before remote review.'
                        : value.isEmpty
                            ? 'No evidence attached.'
                            : valid
                                ? 'Evidence is unavailable. Check your connection and account permissions.'
                                : 'This record has no retrievable evidence link. Ask the recorder to reattach the photo.'));
              })),
      actions: [
        if (valid || queued)
          TextButton(
              onPressed: () => setState(_load), child: const Text('Retry')),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}
