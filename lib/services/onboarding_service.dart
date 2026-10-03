import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  OnboardingService._();

  static const String _completedKey = 'onboarding_completed_v1';
  static const Set<String> _existingUserKeys = {
    'tables',
    'templates',
    'tally_tables',
    'tally_templates',
    'last_opened_table_index',
    'last_opened_tally_index',
    'last_active_tab',
    'app_locale',
  };

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_completedKey) == true) return false;

    final isExistingUser = prefs.getKeys().any(_existingUserKeys.contains);
    if (isExistingUser) {
      await prefs.setBool(_completedKey, true);
      return false;
    }
    return true;
  }

  static Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}
