/// A durable object identifier, not an expiring URL or a public access grant.
class EvidenceReference {
  const EvidenceReference(this.bucket, this.path);
  final String bucket;
  final String path;
  static const buckets = {
    'remittance-evidence',
    'delivery-waybills',
    'expense-receipts',
    'bank-teller-slips',
    'calibration-evidence',
    'credit-requisitions',
  };

  String get value =>
      Uri(scheme: 'storage', host: bucket, path: '/$path').toString();

  static EvidenceReference? parse(String? value, {String? endpoint}) {
    final raw = value?.trim() ?? '';
    // Reject traversal before Uri normalizes dot segments away.
    try {
      final decoded = Uri.decodeComponent(raw.split('?').first);
      if (decoded.split('/').any((part) => part == '.' || part == '..') ||
          RegExp(r'%2f|%5c|%00', caseSensitive: false).hasMatch(raw) ||
          decoded.contains('\\') ||
          decoded.contains('\u0000')) return null;
    } on FormatException {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.hasQuery && uri.scheme != 'https' || uri.hasFragment)
      return null;
    String bucket;
    List<String> segments;
    if (uri.scheme == 'storage' || uri.scheme == 'queued-offline') {
      if (uri.userInfo.isNotEmpty || uri.hasPort) return null;
      bucket = uri.host;
      segments = uri.pathSegments;
    } else if (uri.scheme == 'https') {
      final origin = Uri.tryParse(endpoint ?? '');
      if (origin == null ||
          origin.scheme != 'https' ||
          origin.host.isEmpty ||
          origin.origin != uri.origin ||
          uri.userInfo.isNotEmpty) return null;
      final parts = uri.pathSegments;
      if (parts.length < 6 ||
          parts[0] != 'storage' ||
          parts[1] != 'v1' ||
          parts[2] != 'object' ||
          !{'public', 'sign', 'authenticated'}.contains(parts[3])) return null;
      bucket = parts[4];
      segments = parts.sublist(5);
    } else {
      return null;
    }
    if (!buckets.contains(bucket) ||
        segments.isEmpty ||
        segments.any((part) =>
            part.isEmpty ||
            part == '.' ||
            part == '..' ||
            part.contains('/') ||
            part.contains('\\') ||
            part.contains('\u0000'))) return null;
    return EvidenceReference(bucket, segments.join('/'));
  }
}
