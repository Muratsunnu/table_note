import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/export_service.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/utils/column_balance.dart';
import 'package:table_note/widgets/column_sums_widget.dart';
import 'package:table_note/widgets/starting_value_field.dart';

/// Başlangıç değeri ve kalan: sermaye, bütçe, stok ya da hedef. Birimsizdir.
TableModel _expenses({double? startingValue = 100000}) => TableModel(
  tableName: 'Harcamalar',
  columns: [
    ColumnModel(name: 'açıklama'),
    ColumnModel(name: 'harcama', isNumeric: true, startingValue: startingValue),
  ],
  rows: [
    ['kira', '25000'],
    ['malzeme', '12500'],
  ],
);

void main() {
  final tr = AppLocalizations(const Locale('tr'));
  final en = AppLocalizations(const Locale('en'));

  group('hesap', () {
    test('kalan, başlangıç değerinden sütun toplamı düşülerek bulunur', () {
      final balance = computeColumnBalances(_expenses()).single;

      expect(balance.name, 'harcama');
      expect(balance.total, 37500);
      expect(balance.remaining, 62500);
      expect(balance.isExceeded, isFalse);
    });

    test('toplam başlangıç değerini geçerse aşılmış sayılır', () {
      final balance = computeColumnBalances(
        _expenses(startingValue: 30000),
      ).single;

      expect(balance.remaining, -7500);
      expect(balance.isExceeded, isTrue);
    });

    test('başlangıç değeri verilmemiş sütunun kalanı yoktur', () {
      expect(computeColumnBalances(_expenses(startingValue: null)), isEmpty);
    });

    test('toplanmayan sütunda başlangıç değeri yok sayılır', () {
      final table = TableModel(
        tableName: 'T',
        columns: [
          // Sayısal olmaktan çıkarılmış bir sütunda eski değer kalmış olabilir.
          ColumnModel(name: 'not', startingValue: 10),
          ColumnModel(
            name: 'sabit',
            columnType: ColumnType.constant,
            constantValue: 5,
            startingValue: 10,
          ),
        ],
        rows: [
          ['a', '5'],
        ],
      );

      expect(computeColumnBalances(table), isEmpty);
    });

    test('formül sütunu da başlangıç değeri alabilir', () {
      final table = TableModel(
        tableName: 'Stok',
        columns: [
          ColumnModel(name: 'adet', isNumeric: true),
          ColumnModel(
            name: 'tutar',
            columnType: ColumnType.formula,
            formula: '{adet}*10',
            startingValue: 500,
          ),
        ],
        rows: [
          ['3', '30'],
          ['7', '70'],
        ],
      );

      expect(computeColumnBalances(table).single.remaining, 400);
    });
  });

  group('yazılan sayı uygulamanın diline göre okunur', () {
    test('Türkçe: nokta binlik, virgül ondalık', () {
      expect(parseTypedNumber('100.000', languageCode: 'tr'), 100000);
      expect(parseTypedNumber('100000', languageCode: 'tr'), 100000);
      expect(parseTypedNumber('1.250,5', languageCode: 'tr'), 1250.5);
      expect(parseTypedNumber('-500', languageCode: 'tr'), -500);
    });

    test('İngilizce: virgül binlik, nokta ondalık', () {
      expect(parseTypedNumber('100,000', languageCode: 'en'), 100000);
      expect(parseTypedNumber('1,250.5', languageCode: 'en'), 1250.5);
    });

    test('sayı olmayan girdi kabul edilmez', () {
      expect(parseTypedNumber('', languageCode: 'tr'), isNull);
      expect(parseTypedNumber('12 kg', languageCode: 'tr'), isNull);
      expect(parseTypedNumber('abc', languageCode: 'en'), isNull);
    });
  });

  group('saklama', () {
    test('başlangıç değeri sütunla birlikte kaydedilir ve geri okunur', () {
      final restored = ColumnModel.fromJson(
        ColumnModel(
          name: 'harcama',
          isNumeric: true,
          startingValue: 100000,
        ).toJson(),
      );
      expect(restored.startingValue, 100000);
    });

    test('eski kayıtlarda alan yoktur; sütun olduğu gibi açılır', () {
      final old = ColumnModel.fromJson({'name': 'kilo', 'isNumeric': true});
      expect(old.startingValue, isNull);
      // Değer verilmemiş sütunun kaydına yeni alan da yazılmaz.
      expect(old.toJson().containsKey('startingValue'), isFalse);
    });

    test('kopyalarken değer korunur, istenirse kaldırılır', () {
      final column = ColumnModel(name: 'h', isNumeric: true, startingValue: 5);
      expect(column.copyWith(name: 'x').startingValue, 5);
      expect(column.copyWith(startingValue: 9).startingValue, 9);
      expect(column.copyWith(clearStartingValue: true).startingValue, isNull);
    });
  });

  group('sonradan değiştirme', () {
    late TableProvider tables;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.saveTables([_expenses()]);
      tables = TableProvider();
      addTearDown(tables.dispose);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });

    test('değer artırılır, satırlara dokunulmaz ve kalıcıdır', () async {
      expect(await tables.setColumnStartingValue(1, 150000), isTrue);

      expect(tables.columnBalances.single.remaining, 112500);
      expect(tables.currentTable!.rows, [
        ['kira', '25000'],
        ['malzeme', '12500'],
      ]);
      final saved = await StorageService.loadTables();
      expect(saved.single.columns[1].startingValue, 150000);
    });

    test('değer kaldırılınca kalan da kalkar', () async {
      expect(await tables.setColumnStartingValue(1, null), isTrue);
      expect(tables.columnBalances, isEmpty);
    });

    test('toplanmayan sütuna başlangıç değeri verilemez', () async {
      expect(await tables.setColumnStartingValue(0, 10), isFalse);
      expect(await tables.setColumnStartingValue(7, 10), isFalse);
    });

    test('arama kalanı değiştirmez', () {
      tables.setSearchQuery('kira');
      expect(tables.filteredRowCount, 1);
      expect(tables.columnBalances.single.remaining, 62500);
    });
  });

  group('CSV', () {
    test('satırların altına toplam, başlangıç değeri ve kalan eklenir', () {
      expect(
        ExportService.balanceCsvLines(_expenses(), loc: tr),
        '\nToplam (harcama),37500\n'
        'Başlangıç değeri (harcama),100000\n'
        'Kalan (harcama),62500\n',
      );
      expect(
        ExportService.balanceCsvLines(_expenses(), loc: en),
        contains('Remaining (harcama),62500'),
      );
    });

    test('başlangıç değeri yoksa dosya eskisi gibi kalır', () {
      expect(
        ExportService.balanceCsvLines(_expenses(startingValue: null), loc: tr),
        isEmpty,
      );
    });
  });

  group('toplamlar kutusu', () {
    late TableProvider tables;

    Future<void> pumpSums(WidgetTester tester, TableModel table) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await StorageService.saveTables([table]);
      tables = TableProvider();
      addTearDown(tables.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<TableProvider>.value(
          value: tables,
          child: const MaterialApp(
            locale: Locale('tr'),
            supportedLocales: [Locale('tr'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: ColumnSumsWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('toplamın yanında kalanı gösterir', (tester) async {
      await pumpSums(tester, _expenses());

      expect(find.text('37.500'), findsOneWidget);
      expect(find.text(tr.remainingOf('harcama')), findsOneWidget);
      expect(find.text('62.500'), findsOneWidget);
    });

    testWidgets('aşıldığında kalan eksiye geçer', (tester) async {
      await pumpSums(tester, _expenses(startingValue: 30000));

      expect(find.text(tr.remainingOf('harcama')), findsOneWidget);
      expect(find.text('-7.500'), findsOneWidget);
    });

    testWidgets('başlangıç değeri yoksa kutu eskisi gibidir', (tester) async {
      await pumpSums(tester, _expenses(startingValue: null));

      expect(find.text('37.500'), findsOneWidget);
      expect(find.byKey(const ValueKey('remaining-1')), findsNothing);
    });

    testWidgets('kalana dokunup başlangıç değeri artırılır', (tester) async {
      await pumpSums(tester, _expenses());

      await tester.tap(find.byKey(const ValueKey('remaining-1')));
      await tester.pumpAndSettle();
      // Alan mevcut değerle açılır; yeni değerin sonucu kaydetmeden görünür.
      expect(find.text('100.000'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('starting-value')),
        '150.000',
      );
      await tester.pump();
      expect(find.text('= 150.000'), findsOneWidget);
      expect(find.textContaining('Kalan: 112.500'), findsOneWidget);

      await tester.tap(find.text(tr.save));
      await tester.pumpAndSettle();

      expect(find.text('112.500'), findsOneWidget);
      expect(tables.currentTable!.columns[1].startingValue, 150000);
    });

    testWidgets('"Kaldır" kalanı kaldırır', (tester) async {
      await pumpSums(tester, _expenses());

      await tester.tap(find.byKey(const ValueKey('remaining-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.startingValueRemove));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('remaining-1')), findsNothing);
      expect(find.text('37.500'), findsOneWidget);
    });

    testWidgets('arama yaparken kalan tablonun tamamına göre kalır', (
      tester,
    ) async {
      await pumpSums(tester, _expenses());

      tables.setSearchQuery('kira');
      await tester.pumpAndSettle();

      // Toplam filtreye uyar, kalan uymaz ve bunu söyler.
      expect(find.text('25.000'), findsOneWidget);
      expect(find.text('62.500'), findsOneWidget);
      expect(find.textContaining(tr.wholeTableNote), findsOneWidget);
    });
  });

  group('alan', () {
    Future<List<double?>> pumpField(
      WidgetTester tester, {
      double? value,
      Locale locale = const Locale('tr'),
    }) async {
      final reported = <double?>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: StartingValueField(value: value, onChanged: reported.add),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return reported;
    }

    testWidgets('yazılan sayının nasıl okunduğunu gösterir', (tester) async {
      final reported = await pumpField(tester);

      await tester.enterText(find.byType(TextField), '100.000');
      await tester.pump();

      expect(reported.last, 100000);
      expect(find.text('= 100.000'), findsOneWidget);
    });

    testWidgets('İngilizce arayüzde İngilizce yazım okunur', (tester) async {
      final reported = await pumpField(tester, locale: const Locale('en'));

      await tester.enterText(find.byType(TextField), '100,000');
      await tester.pump();

      expect(reported.last, 100000);
      expect(find.text('= 100,000'), findsOneWidget);
      expect(find.text(en.startingValue), findsOneWidget);
    });

    testWidgets('okunamayan girdi hata verir ve değer bildirmez', (
      tester,
    ) async {
      final reported = await pumpField(tester, value: 50);

      await tester.enterText(find.byType(TextField), '1..2,,3');
      await tester.pump();

      expect(reported.last, isNull);
      expect(find.text(tr.startingValueInvalid), findsOneWidget);
    });

    testWidgets('boşaltınca değer kalkar, hata çıkmaz', (tester) async {
      final reported = await pumpField(tester, value: 50);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(reported.last, isNull);
      expect(find.text(tr.startingValueInvalid), findsNothing);
    });
  });
}
