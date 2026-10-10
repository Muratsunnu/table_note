import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Kullanıcının aboneliklerini gördüğü ve iptal ettiği mağaza.
String get subscriptionStoreName =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'App Store' : 'Google Play';

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
