// Template configuration for Supabase
// Copy this file to supabase_config.dart and provide your project credentials.

class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_PROJECT_URL';
  static const String anonKey = 'YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY';

  // Storage buckets
  static const String evidenceBucket = 'remittance-evidence';
  static const String waybillBucket = 'delivery-waybills';
}
