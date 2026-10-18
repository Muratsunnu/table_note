import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Kullanıcının aboneliklerini gördüğü ve iptal ettiği mağaza.
String get subscriptionStoreName =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'App Store' : 'Google Play';

/// Kullanım koşulları bağlantısı gösterilsin mi. App Store otomatik yenilenen
/// abonelikte ister; Google Play'de mağazanın kendi koşulları geçerlidir.
bool get showsTermsOfUse => defaultTargetPlatform == TargetPlatform.iOS;

Future<bool> openPrivacyPolicy() => _openLink(AppConfig.privacyPolicyUrl);

Future<bool> openTermsOfUse() => _openLink(AppConfig.appleTermsOfUseUrl);

Future<bool> _openLink(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (error) {
    debugPrint('Bağlantı açılamadı: $error');
    return false;
  }
}

/// Mağazanın abonelik yönetimi sayfasını açar; açılamazsa false döner.
Future<bool> openSubscriptionSettings() async {
  final uri = defaultTargetPlatform == TargetPlatform.iOS
      ? Uri.parse('https://apps.apple.com/account/subscriptions')
      : Uri.parse(
          'https://play.google.com/store/account/subscriptions'
          '?package=com.muratstudio.tablenote',
        );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Abonelik sayfası açılamadı: $error');
    return false;
  }
}
