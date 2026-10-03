/// Returns locale-independent keys. Passwords must never be trimmed.
class AuthValidation {
  static String? email(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'invalidEmail';

  static String? password(String? value, {bool isNew = false}) {
    if (value == null || value.isEmpty) return 'requiredPassword';
    if (isNew && value.runes.length < 6) return 'weakPassword';
    return null;
  }

  static String? confirmation(String? value, String password) =>
      value == password && password.isNotEmpty ? null : 'passwordMismatch';
}
