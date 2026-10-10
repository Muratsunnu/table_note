import '../models/plan_offer.dart';

class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String authRedirectUrl =
      'com.muratstudio.tablenote://login-callback';

  /// Mağazalarda tanımlı Premium ürünleri. Fiyat burada yazmaz; mağazadan
  /// okunur.
  static const Map<PlanPeriod, String> premiumProductIds = {
    PlanPeriod.yearly: 'table_note_premium_yearly',
    PlanPeriod.monthly: 'table_note_premium_monthly',
  };

  /// App Store'daki tanıtım teklifinin (ücretsiz deneme) gün sayısı.
  ///
  /// Yalnızca iOS'ta kullanılır: StoreKit 2 eklentisi teklifin süresini
  /// vermiyor, yalnızca kullanıcının hakkı olup olmadığını söylüyor.
  /// Android'de süre doğrudan mağazadan okunur. App Store Connect'teki
  /// teklif değişirse burası da değişmeli; teklifi olmayan paket burada
  /// yer almaz.
  static const Map<PlanPeriod, int> appStoreTrialDays = {PlanPeriod.yearly: 7};

  static bool get hasSupabaseConfig =>
      supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.trim().isNotEmpty;
}
