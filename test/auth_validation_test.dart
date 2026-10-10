import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/l10n/auth_localizations.dart';
import 'package:table_note/utils/auth_validation.dart';

void main() {
  test('email allows surrounding whitespace, rejects malformed input', () {
    expect(AuthValidation.email('  user@example.com  '), isNull);
    for (final value in ['', 'user', 'user@', 'user @example.com']) {
      expect(AuthValidation.email(value), 'invalidEmail');
    }
  });

  test('new passwords enforce the chosen six-character minimum', () {
    expect(AuthValidation.password('12345', isNew: true), 'weakPassword');
    expect(AuthValidation.password('123456', isNew: true), isNull);
    expect(AuthValidation.password('şifre6', isNew: true), isNull);
    expect(AuthValidation.password('123', isNew: false), isNull);
  });

  test('password confirmation compares exact strings without trimming', () {
    expect(AuthValidation.confirmation(' secret ', ' secret '), isNull);
    expect(
      AuthValidation.confirmation('secret', ' secret '),
      'passwordMismatch',
    );
    expect(AuthValidation.confirmation('', ''), 'passwordMismatch');
  });

  test('auth errors follow locale and never expose unknown server text', () {
    final tr = AppLocalizations(const Locale('tr'));
    final en = AppLocalizations(const Locale('en'));
    expect(
      tr.authError('invalid_credentials'),
      isNot(en.authError('invalid_credentials')),
    );
    expect(en.authError('otp_expired'), en.authText('invalidLink'));
    expect(
      en.authError('reauthentication_needed'),
      en.authText('reauthenticate'),
    );
    expect(en.authError('sensitive raw server detail'), en.authText('failed'));
  });

  test('confirm word ignores case and the Turkish dotted/dotless i', () {
    // Aynı niyetin klavyeye göre değişen yazılışları.
    for (final typed in ['SİL', 'sil', 'SIL', 'sıl', '  Sil  ']) {
      expect(AuthValidation.matchesConfirmWord(typed, 'SİL'), isTrue);
    }
    expect(AuthValidation.matchesConfirmWord('delete', 'DELETE'), isTrue);
    for (final typed in ['', 'Sİ', 'SİLL', 'evet', 'delete']) {
      expect(AuthValidation.matchesConfirmWord(typed, 'SİL'), isFalse);
    }
  });

  test('both languages define the same auth strings and placeholders', () {
    // Eksik anahtar çökmez, sessizce "İşlem tamamlanamadı" yazar; yalnızca
    // bu test yakalar.
    final tr = authStrings['tr']!;
    final en = authStrings['en']!;
    expect(tr.keys.toSet().difference(en.keys.toSet()), isEmpty);
    expect(en.keys.toSet().difference(tr.keys.toSet()), isEmpty);
    Set<String> slots(String text) =>
        RegExp(r'\{\w+\}').allMatches(text).map((m) => m[0]!).toSet();
    for (final key in tr.keys) {
      expect(slots(en[key]!), slots(tr[key]!), reason: key);
    }
  });

  test('every code the app raises itself has its own message', () {
    final en = AppLocalizations(const Locale('en'));
    for (final code in ['delete_failed', 'apple_failed', 'network']) {
      expect(en.authError(code), isNot(en.authText('failed')), reason: code);
    }
    for (final notice in ['account_deleted', 'password_updated']) {
      expect(en.authText(notice), isNot(en.authText('failed')), reason: notice);
    }
  });
}
