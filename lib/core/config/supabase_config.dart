import 'dart:convert';

class SupabaseConfig {
  static String get url => const String.fromEnvironment('SUPABASE_URL').trim();
  static String get anonKey =>
      const String.fromEnvironment('SUPABASE_ANON_KEY').trim();

  static String? validate(String endpoint, String key) {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return 'A valid HTTPS SUPABASE_URL is required in this build.';
    }
    final value = key.trim();
    if (value.startsWith('sb_publishable_') && value.length > 20) return null;
    try {
      final parts = value.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        if (payload is Map && payload['role'] == 'anon') return null;
      }
    } catch (_) {}
    return 'A Supabase publishable or anon key is required. Server secret keys must never be bundled.';
  }

  static String? get configurationError => validate(url, anonKey);
  static const String evidenceBucket = 'remittance-evidence';
  static const String waybillBucket = 'delivery-waybills';
}
