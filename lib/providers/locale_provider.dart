import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  Locale _locale = const Locale('tr', 'TR');

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
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
