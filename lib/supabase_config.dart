/// Supabase connection settings for the `chatbox` project.
///
/// Supply the values at run time instead of committing credentials:
/// flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
class SupabaseConfig {
  static const String projectName = 'chatbox';
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://htbvqsakurkqyimjwruo.supabase.co',
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_SSq-pmDblCb036x1f9Iepw_MQ_KRhxL',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
