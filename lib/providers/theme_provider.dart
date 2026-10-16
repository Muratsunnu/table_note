import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'dark_theme_enabled';

  bool _isDarkMode;

  ThemeProvider({bool isDarkMode = false}) : _isDarkMode = isDarkMode;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  static Future<ThemeProvider> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return ThemeProvider(isDarkMode: preferences.getBool(_themeKey) ?? false);
    } catch (error) {
      debugPrint('Theme load error: $error');
      return ThemeProvider();
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_isDarkMode == enabled) return;
    _isDarkMode = enabled;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_themeKey, enabled);
    } catch (error) {
      debugPrint('Theme save error: $error');
    }
  }
}
