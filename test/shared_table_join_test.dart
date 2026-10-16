import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('girilen ad hatırlanır ve sonraki katılımda hazır gelir', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await StorageService.loadSharedDisplayName(), isNull);

    await StorageService.saveSharedDisplayName('  Ayşe  ');
    expect(await StorageService.loadSharedDisplayName(), 'Ayşe');

    // Boş ad hatırlanmaz; bir sonraki sefer yine boş gelir.
    await StorageService.saveSharedDisplayName('   ');
    expect(await StorageService.loadSharedDisplayName(), isNull);
  });

  test('sunucunun her hata kodunun iki dilde karşılığı var', () {
    const codes = [
      'authentication_required',
      'invalid_table_code',
      'invalid_table_password',
      'owner_premium_required',
      'invalid_display_name',
      'display_name_taken',
      'too_many_attempts',
      'table_not_found',
      'password_too_short',
    ];
    for (final locale in [const Locale('tr'), const Locale('en')]) {
      final loc = AppLocalizations(locale);
      for (final code in codes) {
        final text = loc.sharedTableError(code);
        // A missing key falls back to the key itself, which would ship the
        // raw server code to the user.
        expect(text, isNot(contains('err_')), reason: '$code / $locale');
        expect(text.trim(), isNotEmpty);
        expect(const SharedTableException(''), isA<SharedTableException>());
      }
      expect(loc.sharedTableError('unknown').trim(), isNotEmpty);
    }
  });

  test('bilinen ve bilinmeyen sunucu kodları ayırt edilir', () {
    expect(const SharedTableException('display_name_taken').isKnown, isTrue);
    expect(
      const SharedTableException('owner_premium_required').isKnown,
      isTrue,
    );
    // An unexpected database error must not be shown as a friendly message.
    expect(const SharedTableException('23505').isKnown, isFalse);
  });
}
