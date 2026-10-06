class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://haeakygzrnrjwphmhlkp.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_SmQ1nwW78Hh6Gi3RtK956w_E-QNmFMl',
  );

  // Storage buckets
  static const String evidenceBucket = 'remittance-evidence';
  static const String waybillBucket = 'delivery-waybills';
}
