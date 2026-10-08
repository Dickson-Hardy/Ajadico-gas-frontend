class SupabaseConfig {
  static const String _defaultUrl = 'https://haeakygzrnrjwphmhlkp.supabase.co';
  static const String _defaultAnonKey = 'sb_publishable_SmQ1nwW78Hh6Gi3RtK956w_E-QNmFMl';

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Guaranteed production Supabase endpoint
  static String get url => _envUrl.trim().isNotEmpty ? _envUrl.trim() : _defaultUrl;

  /// Guaranteed production Anon/Publishable API Key
  static String get anonKey => _envAnonKey.trim().isNotEmpty ? _envAnonKey.trim() : _defaultAnonKey;

  // Storage buckets
  static const String evidenceBucket = 'remittance-evidence';
  static const String waybillBucket = 'delivery-waybills';
}
