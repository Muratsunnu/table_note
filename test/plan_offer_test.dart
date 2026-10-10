import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/config/plan_limits.dart';
import 'package:table_note/models/plan_offer.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mağaza teklifinin okunması', () {
    test('denemeli teklifte fiyat son aşamanınkidir, ilkinin değil', () {
      // Android ilk aşamayı "fiyat" diye verir; denemede o "Ücretsiz"dir.
      final read = readPlanPhases(const [
        PlanPhase(
          formattedPrice: 'Ücretsiz',
          priceMicros: 0,
          billingPeriod: 'P1W',
        ),
        PlanPhase(
          formattedPrice: '₺199,99',
          priceMicros: 199990000,
          billingPeriod: 'P1Y',
        ),
      ])!;
      expect(read.price, '₺199,99');
      expect(read.rawPrice, closeTo(199.99, 0.001));
      expect(read.trialDays, 7);
    });

    test('denemesiz teklif deneme vaat etmez', () {
      final read = readPlanPhases(const [
        PlanPhase(
          formattedPrice: '₺29,99',
          priceMicros: 29990000,
          billingPeriod: 'P1M',
        ),
      ])!;
      expect(read.price, '₺29,99');
      expect(read.trialDays, isNull);
    });

    test('indirimli ilk dönem deneme sayılmaz', () {
      final read = readPlanPhases(const [
        PlanPhase(
          formattedPrice: '₺99,99',
          priceMicros: 99990000,
          billingPeriod: 'P1Y',
        ),
        PlanPhase(
          formattedPrice: '₺199,99',
          priceMicros: 199990000,
          billingPeriod: 'P1Y',
        ),
      ])!;
      expect(read.trialDays, isNull);
      expect(read.price, '₺199,99');
    });

    test('aşaması olmayan teklif okunmaz', () {
      expect(readPlanPhases(const []), isNull);
    });

    test('süreler güne çevrilir', () {
      expect(isoPeriodDays('P1W'), 7);
      expect(isoPeriodDays('P7D'), 7);
      expect(isoPeriodDays('P3D'), 3);
      expect(isoPeriodDays('P2W'), 14);
      expect(isoPeriodDays('P1M'), 30);
      expect(isoPeriodDays('P1Y'), 365);
      expect(isoPeriodDays('saçma'), isNull);
      expect(isoPeriodDays('P'), isNull);
    });

    test('indirim iki mağaza fiyatından hesaplanır, uydurulmaz', () {
      expect(yearlySavingPercent(yearly: 199.99, monthly: 29.99), 44);
      // Yıllık daha ucuz değilse indirim yazılmaz.
      expect(yearlySavingPercent(yearly: 360, monthly: 29.99), isNull);
      expect(yearlySavingPercent(yearly: 199.99, monthly: 0), isNull);
    });
  });

  group('ücretsiz sınır', () {
    Future<TableProvider> emptyProvider() async {
      SharedPreferences.setMockInitialValues({});
      final provider = TableProvider();
      while (provider.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return provider;
    }

    Future<bool> create(
      TableProvider provider,
      String name, {
      bool free = true,
    }) =>
        provider.createTable(name, [ColumnModel(name: 'a')], isPremium: !free);

    test('sınıra kadar oluşturulur, sonrası Premium ister', () async {
      final provider = await emptyProvider();
      for (var i = 0; i < PlanLimits.freeTables; i++) {
        expect(await create(provider, 'tablo $i'), isTrue, reason: '$i');
      }
      expect(provider.canCreateFreeTable, isFalse);
      expect(await create(provider, 'fazla'), isFalse);
      // Premium ya da eski kullanıcı için sınır yok.
      expect(await create(provider, 'fazla', free: false), isTrue);
    });

    test('kodla katılınan tablo sınıra sayılmaz', () async {
      // Davet edilen kişi sınıra takılıp giremezse bedelini davet eden öder.
      final provider = await emptyProvider();
      for (var i = 0; i < PlanLimits.freeTables; i++) {
        await create(provider, 'tablo $i');
      }
      final joined = provider.tables.first.id;
      await provider.setSharedRole(joined, 'viewer');
      expect(provider.ownedTableCount, PlanLimits.freeTables - 1);
      expect(await create(provider, 'kendi tablom'), isTrue);

      // Kendi paylaştığı tablo ise kendisinindir.
      await provider.setSharedRole(joined, 'owner');
      expect(provider.ownedTableCount, PlanLimits.freeTables + 1);
    });

    test('sınırın üstündeki mevcut tablolar düzenlenmeye devam eder', () async {
      final provider = await emptyProvider();
      for (var i = 0; i < PlanLimits.freeTables + 2; i++) {
        await create(provider, 'tablo $i', free: false);
      }
      // Premium bitti: yenisi açılamaz ama eldekiler kilitlenmez.
      expect(await create(provider, 'yeni'), isFalse);
      expect(await provider.addRow(['kayıt']), isTrue);
    });
  });

  group('sınırlardan önceki sürümden gelen kullanıcı', () {
    test('cihazda hiç veri yoksa yeni kullanıcıdır', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await StorageService.resolveLegacyUnlimited(), isFalse);
    });

    test('önceden kalma tablosu olan sınırsız kalır', () async {
      SharedPreferences.setMockInitialValues({
        'tables': '[{"tableName":"eski"}]',
      });
      expect(await StorageService.resolveLegacyUnlimited(), isTrue);
    });

    test('önceden kalma çetelesi ya da şablonu da yeter', () async {
      SharedPreferences.setMockInitialValues({'tally_tables': '[{"x":1}]'});
      expect(await StorageService.resolveLegacyUnlimited(), isTrue);
      SharedPreferences.setMockInitialValues({'templates': '[{"x":1}]'});
      expect(await StorageService.resolveLegacyUnlimited(), isTrue);
      // Boş liste veri değildir.
      SharedPreferences.setMockInitialValues({'tables': '[]'});
      expect(await StorageService.resolveLegacyUnlimited(), isFalse);
    });

    test(
      'karar bir kez verilir; sonradan oluşan veri onu değiştirmez',
      () async {
        SharedPreferences.setMockInitialValues({});
        expect(await StorageService.resolveLegacyUnlimited(), isFalse);
        // Yeni kullanıcı ilk tablosunu oluşturdu, uygulamayı yeniden açtı.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tables', '[{"tableName":"yeni"}]');
        expect(await StorageService.resolveLegacyUnlimited(), isFalse);
      },
    );
  });
}
