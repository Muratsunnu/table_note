class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String authRedirectUrl =
      'com.muratstudio.tablenote://login-callback';
  static const String premiumYearlyProductId = 'table_note_premium_yearly';

  static bool get hasSupabaseConfig =>
      supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.trim().isNotEmpty;
}
