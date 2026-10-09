import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  Locale _locale;

  Locale get locale => _locale;

  /// [initial] verilirse o dille başlar; verilmezse kayıtlı dil arka planda
  /// okunur ve o gelene kadar Türkçe gösterilir.
  LocaleProvider({Locale? initial})
    : _locale = initial ?? const Locale('tr', 'TR') {
    if (initial == null) _loadLocale();
  }

  /// Dili uygulama açılmadan belirler; ilk kare doğru dille çizilir.
  ///
  /// Kayıtlı bir seçim yoksa: yeni kullanıcı telefonunun diliyle başlar
  /// (Türkçe değilse İngilizce), önceki sürümden gelen kullanıcı alıştığı
  /// Türkçede kalır. Karar bir kez verilir ve kaydedilir.
  static Future<LocaleProvider> load({
    required bool newUser,
    Locale? deviceLocale,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var code = prefs.getString(_localeKey);
      if (code == null) {
        final device =
            deviceLocale ?? WidgetsBinding.instance.platformDispatcher.locale;
        code = newUser && device.languageCode != 'tr' ? 'en' : 'tr';
        await prefs.setString(_localeKey, code);
      }
      return LocaleProvider(initial: Locale(code));
    } catch (e) {
      debugPrint('Locale load error: $e');
      return LocaleProvider(initial: const Locale('tr', 'TR'));
    }
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString(_localeKey);
      if (langCode != null) {
        _locale = Locale(langCode);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Locale load error: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (e) {
      debugPrint('Locale save error: $e');
    }
  }

  bool get isTurkish => _locale.languageCode == 'tr';
  bool get isEnglish => _locale.languageCode == 'en';
}
