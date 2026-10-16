import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/utils/quick_options.dart';
import 'package:table_note/widgets/quick_option_chips.dart';

/// Hızlı seçim kendiliğinden oluşur: bir sütuna üçten fazla kez girilen değer
/// öneri olur, × ile kaldırılır, yeniden üçten fazla girilirse geri gelir.
TableModel _table({required List<String> cities, List<ColumnModel>? columns}) =>
    TableModel(
      id: 'seferler',
      tableName: 'Seferler',
      columns:
          columns ??
          [
            ColumnModel(name: 'yükleme'),
            ColumnModel(name: 'kilo', isNumeric: true),
          ],
      rows: [
        for (final city in cities) [city, '100'],
      ],
    );

void main() {
  group('seçenekler', () {
    test('üç kez girilen değer öneri olmaz, dördüncüde olur', () {
      expect(
        quickOptionsFor(_table(cities: List.filled(3, 'Konya')), 0),
        isEmpty,
      );
      expect(quickOptionsFor(_table(cities: List.filled(4, 'Konya')), 0), [
        'Konya',
      ]);
    });

    test('en sık girilen önce gelir; boşluklar ve boş hücreler sayılmaz', () {
      final table = _table(
        cities: [
          ...List.filled(4, 'Konya'),
          ...List.filled(6, ' Adana '),
          ...List.filled(9, ''),
          'Mersin',
        ],
      );

      expect(quickOptionsFor(table, 0), ['Adana', 'Konya']);
    });

    test('büyük küçük harf ayrımı yapılmaz; en çok kullanılan yazılış '
        'görünür', () {
      final table = _table(cities: ['konya', 'Konya', 'KONYA', 'Konya']);

      // Dört giriş tek değer sayılır.
      expect(quickOptionsFor(table, 0), ['Konya']);
    });

    test('Türkçe I ve İ de aynı sayılır', () {
      expect(
        quickOptionsFor(
          _table(cities: ['ISPARTA', 'Isparta', 'ısparta', 'Isparta']),
          0,
        ),
        ['Isparta'],
      );
      expect(
        quickOptionsFor(
          _table(cities: ['İZMİR', 'izmir', 'İzmir', 'İzmir']),
          0,
        ),
        ['İzmir'],
      );
    });

    test('sayısal sütunda tekrar eden rakam öneri olmaz', () {
      // Her satırda kilo 100; yine de öneri değildir.
      expect(
        quickOptionsFor(_table(cities: List.filled(8, 'Konya')), 1),
        isEmpty,
      );
    });

    test('tarih, saat, formül gibi kendiliğinden dolan sütunlarda öneri '
        'yoktur', () {
      final table = _table(
        cities: List.filled(6, '01.10.2026'),
        columns: [
          ColumnModel(name: 'tarih', columnType: ColumnType.date),
          ColumnModel(name: 'kilo', isNumeric: true),
        ],
      );

      expect(quickOptionsFor(table, 0), isEmpty);
    });

    test('eski sürümde elle tanımlanmış liste kaybolmaz, önce gelir', () {
      final table = _table(
        cities: List.filled(5, 'Konya'),
        columns: [
          ColumnModel(name: 'yükleme', autoFillOptions: ['Mersin', 'Konya']),
          ColumnModel(name: 'kilo', isNumeric: true),
        ],
      );

      // Konya hem listede hem sık girilmiş; iki kez görünmez.
      expect(quickOptionsFor(table, 0), ['Mersin', 'Konya']);
    });

    test('öğrenilen seçenekler en sık girilenlerle sınırlıdır', () {
      final table = _table(
        cities: [
          for (var i = 0; i < maxLearnedQuickOptions + 5; i++)
            ...List.filled(4 + i, 'Şehir $i'),
        ],
      );

      final options = quickOptionsFor(table, 0);
      expect(options.length, maxLearnedQuickOptions);
      // En çok girilen en başta.
      expect(options.first, 'Şehir ${maxLearnedQuickOptions + 4}');
    });

    test('kaldırılan öneri, yeniden üçten fazla girilince geri gelir', () {
      // Kaldırılanlar harf ayrımı yapmayan anahtarla tutulur.
      final dismissed = {quickOptionKey('Konya'): 4};

      expect(
        quickOptionsFor(
          _table(cities: List.filled(4, 'Konya')),
          0,
          dismissed: dismissed,
        ),
        isEmpty,
      );
      expect(
        quickOptionsFor(
          _table(cities: List.filled(7, 'Konya')),
          0,
          dismissed: dismissed,
        ),
        isEmpty,
      );
      expect(
        quickOptionsFor(
          _table(cities: List.filled(8, 'Konya')),
          0,
          dismissed: dismissed,
        ),
        ['Konya'],
      );
    });
  });

  group('tabloda', () {
    late TableProvider tables;

    Future<void> load(List<String> cities) async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.saveTables([_table(cities: cities)]);
      tables = TableProvider();
      while (tables.isLoading || tables.currentTable == null) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      addTearDown(tables.dispose);
    }

    test('kayıt eklendikçe öneri kendiliğinden oluşur', () async {
      await load(List.filled(3, 'Konya'));
      expect(tables.quickOptions(0), isEmpty);

      await tables.addRow(['Konya', '250']);

      expect(tables.quickOptions(0), ['Konya']);
    });

    test('kaldırılan öneri uygulama yeniden açılınca da kaldırılmış kalır, '
        'sonra geri gelebilir', () async {
      await load(List.filled(4, 'Konya'));
      await tables.dismissQuickOption(0, 'Konya');
      expect(tables.quickOptions(0), isEmpty);

      final reopened = TableProvider();
      addTearDown(reopened.dispose);
      while (reopened.isLoading || reopened.currentTable == null) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(reopened.quickOptions(0), isEmpty);

      // Farklı harflerle yazılsa da aynı değerin girişi sayılır.
      for (final spelling in ['konya', 'KONYA', 'Konya']) {
        await reopened.addRow([spelling, '100']);
      }
      expect(reopened.quickOptions(0), isEmpty);
      await reopened.addRow(['Konya', '100']);
      expect(reopened.quickOptions(0), ['Konya']);
    });

    testWidgets('çipe dokununca alan dolar, × öneriyi kaldırır', (
      tester,
    ) async {
      await tester.runAsync(() => load(List.filled(4, 'Konya')));
      String? picked;
      await tester.pumpWidget(
        ChangeNotifierProvider<TableProvider>.value(
          value: tables,
          child: MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: const [Locale('tr'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: QuickOptionChips(
                columnIndex: 0,
                selected: '',
                onSelected: (value) => picked = value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konya'));
      expect(picked, 'Konya');

      final loc = AppLocalizations(const Locale('tr'));
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip(loc.quickOptionRemove));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('Konya'), findsNothing);
    });
  });
}
