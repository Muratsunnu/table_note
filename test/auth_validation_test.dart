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
}
