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

  /// Geri alinamayan bir islem icin yazilan onay sozcugu tutuyor mu?
  ///
  /// Buyuk/kucuk harf ve Turkce I ailesi ayirt edilmez. "SİL" sozcugunu
  /// Ingilizce klavyeyle yazan "SIL", otomatik buyutmesi kapali olan "sil"
  /// yazar; dart'in toLowerCase'i ise "SİL"i birlesen noktali bir "i"ye
  /// cevirir. Hepsi ayni niyet oldugu icin hepsi kabul edilir.
  static bool matchesConfirmWord(String input, String word) =>
      _foldI(input) == _foldI(word);

  static String _foldI(String value) =>
      value.trim().toLowerCase().replaceAll('\u0307', '').replaceAll('ı', 'i');
}
