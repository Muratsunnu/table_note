import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/widgets/table_list_widget.dart';

/// Tablo satırları ekrana geldikçe çizilir. Hepsi baştan çizilirse bin
/// satırlık tablo her değişiklikte saniyelerce takılır.
void main() {
  const rowCount = 3000;

  Future<TableProvider> pumpTable(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveTables([
      TableModel(
        tableName: 'Seferler',
        columns: [
          ColumnModel(name: 'nereden'),
          ColumnModel(name: 'kilo', isNumeric: true),
        ],
        rows: [
          for (var i = 0; i < rowCount; i++) ['Durak $i', '${1000 + i}'],
        ],
      ),
    ]);
    final provider = TableProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<TableProvider>.value(
        value: provider,
        child: const MaterialApp(
          locale: Locale('tr'),
          supportedLocales: [Locale('tr'), Locale('en')],
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
    expect(provider.currentTable!.rows, hasLength(rowCount));
    return provider;
  }

  testWidgets('büyük tabloda yalnızca görünen satırlar çizilir', (
    tester,
  ) async {
    await pumpTable(tester);

    expect(find.text('Durak 0'), findsOneWidget);
    expect(find.text('Durak ${rowCount - 1}'), findsNothing);
    // 844 piksellik ekrana sığan satırlar ve biraz fazlası; binlercesi değil.
    final built = find.textContaining('Durak ').evaluate().length;
    expect(built, greaterThan(10));
    expect(built, lessThan(40));
  });

  testWidgets('sona kaydırınca son satır gelir, başlık yerinde kalır', (
    tester,
  ) async {
    await pumpTable(tester);

    final list = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    list.position.jumpTo(list.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(find.text('Durak ${rowCount - 1}'), findsOneWidget);
    expect(find.text('Durak 0'), findsNothing);
    // Başlık satırı listeyle birlikte kaymaz.
    expect(find.text('nereden'), findsOneWidget);
    expect(find.text('kilo'), findsOneWidget);
  });

  testWidgets('arama büyük tabloda da doğru satırları bulur', (tester) async {
    final provider = await pumpTable(tester);

    provider.setSearchQuery('Durak 2999');
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Durak 2999', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Durak 0'), findsNothing);
  });
}
