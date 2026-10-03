import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/utils/number_display.dart';
import 'package:table_note/widgets/table_list_widget.dart';

/// "kod" is a text column holding something that merely looks like a number:
/// a postcode must survive untouched while "kilosu" gets separators.
const _rows = [
  ['1', 'konya', '34000', '35000'],
  ['2', 'izmir', '06100', '1234.5'],
];

Future<TableProvider> _seededProvider(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  late TableProvider provider;
  await tester.runAsync(() async {
    provider = TableProvider();
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
        ColumnModel(name: 'nereden'),
        ColumnModel(name: 'kod'),
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

Future<void> _pump(
  WidgetTester tester,
  TableProvider provider, {
  Locale locale = const Locale('tr', 'TR'),
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<TableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: TableListWidget()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  _highlightTests();
  testWidgets('listede sayı sütunu binlik ayraçla gösterilir', (tester) async {
    final provider = await _seededProvider(tester);
    await _pump(tester, provider);

    expect(find.text('35.000'), findsOneWidget);
    expect(find.text('1.234,5'), findsOneWidget);
    expect(find.text('35000'), findsNothing);
  });

  testWidgets('sıra ve metin sütunları olduğu gibi kalır', (tester) async {
    final provider = await _seededProvider(tester);
    await _pump(tester, provider);

    // A postcode in a text column must not become 34.000.
    expect(find.text('34000'), findsOneWidget);
    expect(find.text('06100'), findsOneWidget);
    expect(find.text('34.000'), findsNothing);
    // Row numbers stay plain; they are counters, not quantities.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('İngilizce arayüzde ayraç virgül olur', (tester) async {
    final provider = await _seededProvider(tester);
    await _pump(tester, provider, locale: const Locale('en', 'US'));

    expect(find.text('35,000'), findsOneWidget);
    expect(find.text('1,234.5'), findsOneWidget);
  });

  testWidgets('biçimlendirme yalnızca görünümdedir, kayıt değişmez', (
    tester,
  ) async {
    final provider = await _seededProvider(tester);
    await _pump(tester, provider);

    expect(provider.currentTable!.rows, _rows);
  });

  testWidgets('ekranda görünen ayraçlı hâliyle de aranabilir', (tester) async {
    final provider = await _seededProvider(tester);

    // What the user reads on screen.
    provider.setSearchQuery('35.000');
    expect(provider.visibleRowIndices, [0]);
    // What they typed into the cell.
    provider.setSearchQuery('35000');
    expect(provider.visibleRowIndices, [0]);
    provider.setSearchQuery('1.234,5');
    expect(provider.visibleRowIndices, [1]);
  });

  testWidgets('ayraçlı arama metin sütununa uygulanmaz', (tester) async {
    final provider = await _seededProvider(tester);

    // "06100" is shown as typed, so "06.100" matches nothing.
    provider.setSearchQuery('06.100');
    expect(provider.visibleRowIndices, isEmpty);
    provider.setSearchQuery('06100');
    expect(provider.visibleRowIndices, [1]);
  });
}

void _highlightTests() {
  (int, int)? span(String raw, String query, {String language = 'tr'}) =>
      highlightSpanIn(
        raw: raw,
        shown: formatNumericCell(raw, language: language) ?? raw,
        query: query,
        language: language,
      );

  String marked(String raw, String query, {String language = 'tr'}) {
    final shown = formatNumericCell(raw, language: language) ?? raw;
    final hit = span(raw, query, language: language);
    if (hit == null) return shown;
    final (start, end) = hit;
    return '${shown.substring(0, start)}[${shown.substring(start, end)}]'
        '${shown.substring(end)}';
  }

  test('ayraçsız aranan sayı, ekrandaki ayraçlı hâlinde vurgulanır', () {
    // What people actually type.
    expect(marked('35000', '35000'), '[35.000]');
    // A match that straddles the separator takes it with them.
    expect(marked('35000', '5000'), '3[5.000]');
    // The separator is taken along only when it falls inside the match, not
    // when it sits just before its first digit.
    expect(marked('1234567', '4567'), '1.23[4.567]');
  });

  test('ekranda göründüğü gibi aramak da çalışır', () {
    expect(marked('35000', '35.'), '[35.]000');
    expect(marked('35000', '35.000'), '[35.000]');
    expect(marked('35000', '35,000', language: 'en'), '[35,000]');
  });

  test('ondalıkta ayraçsız yazım da bulunur', () {
    // Shown as 1.234,5; typed without the thousands separator.
    expect(marked('1234.5', '1234,5'), '[1.234,5]');
    expect(marked('1234.5', '234.5'), '1.[234,5]');
  });

  test('eşleşme yoksa vurgu da yok', () {
    expect(span('35000', '99'), isNull);
    expect(span('35000', ''), isNull);
    // A text cell has no grouped form; the plain search still applies.
    expect(
      highlightSpanIn(
        raw: 'konya',
        shown: 'konya',
        query: 'ony',
        language: 'tr',
      ),
      (1, 4),
    );
  });

  test('aranabilir yazılışlar her iki ondalık işaretini de kapsar', () {
    expect(groupedSearchForms('35000').toList(), ['35.000', '35,000']);
    expect(
      groupedSearchForms('1234.5').toList(),
      containsAll(['1.234,5', '1,234.5', '1234,5']),
    );
    expect(groupedSearchForms('konya').toList(), isEmpty);
  });
}
