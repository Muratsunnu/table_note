import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/widgets/edit_row_dialog.dart';
import 'package:table_note/widgets/table_list_widget.dart';

/// Rows are added in this order; sorting must never change it in storage.
const _rows = [
  ['1', '14.09.2026', 'konya', '35000'],
  ['2', '02.01.2027', 'ankara', '9'],
  ['3', '15.09.2026', 'izmir', '120'],
];

Future<TableProvider> _seededProvider(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  late TableProvider provider;
  await tester.runAsync(() async {
    provider = TableProvider();
    // The constructor starts loading; wait so it cannot overwrite our table.
    while (provider.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      await provider.createTable('seferler', [
        ColumnModel(
          name: 'sıra',
          isNumeric: true,
          columnType: ColumnType.autoNumber,
        ),
        ColumnModel(name: 'tarih', columnType: ColumnType.date),
        ColumnModel(name: 'nereden'),
        ColumnModel(name: 'kilosu', isNumeric: true),
      ]),
      isTrue,
    );
    for (final row in _rows) {
      expect(await provider.addRow(row), isTrue);
    }
  });
  return provider;
}

Future<void> _pump(WidgetTester tester, TableProvider provider) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<TableProvider>.value(
      value: provider,
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR'), Locale('en', 'US')],
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: TableListWidget()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Cities from top to bottom as the table currently draws them.
List<String> _visibleOrder(WidgetTester tester) {
  final cities = ['konya', 'ankara', 'izmir'];
  cities.sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return cities;
}

Future<void> _tapHeader(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('başlığa dokunmak artan → azalan → kapalı döngüsü yapar', (
    tester,
  ) async {
    final provider = await _seededProvider(tester);
    await _pump(tester, provider);

    expect(_visibleOrder(tester), ['konya', 'ankara', 'izmir']);

    await _tapHeader(tester, 'kilosu');
    expect(_visibleOrder(tester), ['ankara', 'izmir', 'konya']);

    await _tapHeader(tester, 'kilosu');
    expect(_visibleOrder(tester), ['konya', 'izmir', 'ankara']);

    await _tapHeader(tester, 'kilosu');
    expect(provider.isSorted, isFalse);
    expect(_visibleOrder(tester), ['konya', 'ankara', 'izmir']);
  });

  testWidgets('tarih sütunu yıla göre sıralanır', (tester) async {
    final provider = await _seededProvider(tester);
    await _pump(tester, provider);

    await _tapHeader(tester, 'tarih');
    expect(_visibleOrder(tester), ['konya', 'izmir', 'ankara']);
  });

  testWidgets('sıralama kayıtlı satır sırasını değiştirmez', (tester) async {
    final provider = await _seededProvider(tester);
    await _pump(tester, provider);

    await _tapHeader(tester, 'nereden');
    expect(_visibleOrder(tester), ['ankara', 'izmir', 'konya']);
    // Storage keeps insertion order for the widget, export and row numbers.
    expect(provider.currentTable!.rows.map((row) => row[2]), [
      'konya',
      'ankara',
      'izmir',
    ]);
  });

  testWidgets('genel bakış sırası aramadan bağımsızdır', (tester) async {
    final provider = await _seededProvider(tester);
    provider.toggleSort(3); // kilosu, artan: ankara, izmir, konya
    provider.setSearchQuery('konya');
    expect(provider.visibleRowIndices, [0]);
    // The whole-table view always shows every row, in the on-screen order.
    expect(provider.sortedRowIndices, [1, 2, 0]);
  });

  testWidgets('sıralama uygulama yeniden açılınca geri gelir', (tester) async {
    final provider = await _seededProvider(tester);
    final tableId = provider.currentTable!.id;

    late TableProvider reopened;
    await tester.runAsync(() async {
      provider.toggleSort(3); // kilosu, artan
      provider.toggleSort(3); // kilosu, azalan
      // The save is not awaited by the UI; wait until it reaches storage.
      for (var i = 0; i < 200; i++) {
        final saved = await StorageService.loadTableSorts();
        if (saved[tableId]?.ascending == false) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      // A fresh provider reads storage exactly like a cold app start.
      reopened = TableProvider();
      while (reopened.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });

    expect(reopened.currentTable!.id, tableId);
    expect(reopened.sortColumnIndex, 3);
    expect(reopened.sortAscending, isFalse);

    await _pump(tester, reopened);
    expect(_visibleOrder(tester), ['konya', 'izmir', 'ankara']);
  });

  testWidgets('sıralamayı kapatmak da kalıcıdır', (tester) async {
    final provider = await _seededProvider(tester);
    final tableId = provider.currentTable!.id;

    late TableProvider reopened;
    await tester.runAsync(() async {
      provider.toggleSort(2);
      provider.toggleSort(2);
      provider.toggleSort(2); // üçüncü dokunuş: kapalı
      for (var i = 0; i < 200; i++) {
        final saved = await StorageService.loadTableSorts();
        if (!saved.containsKey(tableId)) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      reopened = TableProvider();
      while (reopened.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });

    expect(reopened.isSorted, isFalse);
  });

  testWidgets('sıralı görünümde dokunulan satır doğru kaydı açar', (
    tester,
  ) async {
    final provider = await _seededProvider(tester);
    await _pump(tester, provider);

    await _tapHeader(tester, 'kilosu');
    // "ankara" is drawn first now, but it was the second row entered.
    await tester.tap(find.text('ankara'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<EditRowDialog>(find.byType(EditRowDialog));
    expect(dialog.rowIndex, 1);
    expect(dialog.currentData[2], 'ankara');
  });
}
