import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/providers/locale_provider.dart';
import 'package:table_note/services/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String> open({
    required bool newUser,
    required String device,
    Map<String, Object> saved = const {},
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    final provider = await LocaleProvider.load(
      newUser: newUser,
      deviceLocale: Locale(device),
    );
    addTearDown(provider.dispose);
    return provider.locale.languageCode;
  }

  test('yeni kullanıcı telefonunun diliyle başlar', () async {
    expect(await open(newUser: true, device: 'tr'), 'tr');
    expect(await open(newUser: true, device: 'en'), 'en');
    // Desteklenmeyen dilde İngilizce.
    expect(await open(newUser: true, device: 'de'), 'en');
  });

  test('önceki sürümden gelen kullanıcı Türkçede kalır', () async {
    expect(await open(newUser: false, device: 'en'), 'tr');
  });

  test('seçilmiş dil telefonun dilinden önce gelir', () async {
    expect(
      await open(newUser: true, device: 'en', saved: {'app_locale': 'tr'}),
      'tr',
    );
    expect(
      await open(newUser: false, device: 'tr', saved: {'app_locale': 'en'}),
      'en',
    );
  });

  test('karar bir kez verilir ve kaydedilir', () async {
    expect(await open(newUser: true, device: 'en'), 'en');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), 'en');

    // Telefonun dili sonradan değişse de uygulama ilk kararında kalır.
    final again = await LocaleProvider.load(
      newUser: false,
      deviceLocale: const Locale('tr'),
    );
    addTearDown(again.dispose);
    expect(again.locale.languageCode, 'en');
  });

  test('kaydedilen dil tanıtımın yeniden gösterilmesini engellemez', () async {
    // Tanıtımı bitirmeden kapatan yeni kullanıcı sonraki açılışta yine görür.
    expect(await open(newUser: true, device: 'en'), 'en');
    expect(await OnboardingService.shouldShow(), isTrue);
  });
}
