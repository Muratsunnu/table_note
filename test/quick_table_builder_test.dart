import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/l10n/ux_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/template_provider.dart';
import 'package:table_note/widgets/create_table_dialog.dart';
import 'package:table_note/widgets/quick_table_builder.dart';
import 'package:table_note/widgets/template_management_dialog.dart';

class _Subscription extends ChangeNotifier implements SubscriptionProvider {
  @override
  bool get isPremium => true;
  @override
  bool get hasUnlimitedPlan => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Tablo, tablonun üstünde kurulur: + her basışta klasik sütun formunu açar
/// ve bir sütun ekler.
void main() {
  final tr = AppLocalizations(const Locale('tr'));
  const name = ValueKey('quick-table-name');
  const add = ValueKey('quick-add-column');
  const create = ValueKey('quick-create');
  const save = ValueKey('column-save');
  const columnName = ValueKey('column-name');
  late TableProvider tables;

  Future<void> open(WidgetTester tester) async {
    // Test yazı tipi gerçeğinden geniş; ekran ona göre geniş tutulur.
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    tables = TableProvider();
    final templates = TemplateProvider();
    final subscription = _Subscription();
    addTearDown(tables.dispose);
    addTearDown(templates.dispose);
    addTearDown(subscription.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TableProvider>.value(value: tables),
          ChangeNotifierProvider<TemplateProvider>.value(value: templates),
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: subscription,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Kurulum bitince kapanabilsin diye bir alt sayfa gerekir.
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuickTableBuilder(),
                  ),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    // Çeviriler yüklenince ilk sayfa çizilir.
    await tester.pumpAndSettle();
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  /// + ile sütun formunu açar, adı yazar ve ekler.
  Future<void> addColumn(
    WidgetTester tester,
    String text, {
    bool numeric = false,
  }) async {
    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    expect(find.byType(CreateTableDialog), findsOneWidget);
    await tester.enterText(find.byKey(columnName), text);
    if (numeric) {
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(create));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('+ her basışta sütun formunu açar ve tabloya bir sütun ekler', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byKey(name), 'Sevkiyat');
    await addColumn(tester, 'müşteri');
    await addColumn(tester, 'kilo', numeric: true);

    // Form kapanır; başlıklar tabloda, ne tuttuklarıyla birlikte görünür.
    expect(find.byType(CreateTableDialog), findsNothing);
    expect(find.text('müşteri'), findsOneWidget);
    expect(find.text('kilo'), findsOneWidget);
    expect(find.text(tr.kindTextNote), findsOneWidget);
    expect(find.text(tr.kindNumberNote), findsOneWidget);

    await finish(tester);

    expect(find.byType(QuickTableBuilder), findsNothing);
    final table = tables.currentTable!;
    expect(table.tableName, 'Sevkiyat');
    expect(table.columns.map((c) => c.name), ['müşteri', 'kilo']);
    expect(table.columns[0].isNumeric, isFalse);
    expect(table.columns[1].isNumeric, isTrue);
  });

  testWidgets('sütun formu yalnızca sütunu sorar', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();

    // Form bir sayfa değil, tablonun üstünde açılan bir kâğıttır.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(QuickTableBuilder), findsOneWidget);
    // Tablo adı, şablon sekmesi ve "sütun ekle" kartı bu formda yoktur.
    final form = find.byType(CreateTableDialog);
    expect(find.byType(TabBar), findsNothing);
    expect(
      find.descendant(of: form, matching: find.byType(TextField)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: form, matching: find.text(tr.tableName)),
      findsNothing,
    );
    // Tip ve ayarlar doğrudan görünür; açmak için ayrı bir düğme yoktur.
    expect(find.text(tr.advancedSettings), findsNothing);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    // Yeni sütunda kaldırılacak bir şey yoktur.
    expect(find.byKey(const ValueKey('column-remove')), findsNothing);
  });

  testWidgets('başlığa dokununca o sütunun formu açılır ve değişiklik '
      'tabloya yansır', (tester) async {
    await open(tester);
    await addColumn(tester, 'kilo');

    await tester.tap(find.byKey(const ValueKey('quick-column-0')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'kilo'), findsOneWidget);
    await tester.enterText(find.byKey(columnName), 'ağırlık');
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();

    expect(find.text('ağırlık'), findsOneWidget);
    expect(find.text('kilo'), findsNothing);
  });

  testWidgets('sütun kendi formundan kaldırılır', (tester) async {
    await open(tester);
    await addColumn(tester, 'fazla');
    await addColumn(tester, 'kalan');

    await tester.tap(find.byKey(const ValueKey('quick-column-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('column-remove')));
    await tester.pumpAndSettle();

    expect(find.text('fazla'), findsNothing);
    expect(find.text('kalan'), findsOneWidget);
  });

  testWidgets('başlığa basılı tutup sürükleyince sütunun yeri değişir', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byKey(name), 'Sevkiyat');
    await addColumn(tester, 'müşteri');
    await addColumn(tester, 'kilo');
    await addColumn(tester, 'tarih');

    // + hep sona ekler; "tarih" en başa çekilir.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('tarih')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    final target = tester.getTopLeft(find.text('müşteri'));
    final start = tester.getCenter(find.text('tarih'));
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(
        Offset(start.dx + (target.dx - 40 - start.dx) * step / 10, start.dy),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('tarih')).dx,
      lessThan(tester.getTopLeft(find.text('müşteri')).dx),
    );
    await finish(tester);
    expect(tables.currentTable!.columns.map((c) => c.name), [
      'tarih',
      'müşteri',
      'kilo',
    ]);
  });

  testWidgets('sıra değiştikten sonra başlığa dokunmak doğru sütunu açar', (
    tester,
  ) async {
    await open(tester);
    await addColumn(tester, 'müşteri');
    await addColumn(tester, 'kilo');

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('kilo')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    final start = tester.getCenter(find.text('kilo'));
    final target = tester.getTopLeft(find.text('müşteri'));
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(
        Offset(start.dx + (target.dx - 40 - start.dx) * step / 10, start.dy),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('kilo'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'kilo'), findsOneWidget);
  });

  testWidgets('adsız ya da aynı adlı sütun eklenmez', (tester) async {
    await open(tester);
    await addColumn(tester, 'kilo');

    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
    expect(find.text(tr.columnNameEmpty(2)), findsOneWidget);

    // Formüller sütunu adıyla bulur.
    await tester.enterText(find.byKey(columnName), 'Kilo');
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
    expect(find.text(tr.quickDuplicateColumn), findsOneWidget);
    expect(find.byType(CreateTableDialog), findsOneWidget);
  });

  testWidgets('"Numara" tipi seçilen sütun toplanmayan numara sütunu olur', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byKey(name), 'Fişler');
    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(columnName), 'fiş no');
    await tester.tap(find.text(tr.codeColumn));
    await tester.pumpAndSettle();

    // Numara seçilince ne olduğu yazar; "sayısal sütun" kutusu sorulmaz.
    expect(find.text(tr.codeColumnDesc), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
    expect(find.text(tr.kindCodeNote), findsOneWidget);

    await finish(tester);
    final column = tables.currentTable!.columns.single;
    expect(column.columnType, ColumnType.code);
    expect(column.isSummed, isFalse);
  });

  testWidgets('formül sütunu, tablodaki diğer sütunları kullanabilir', (
    tester,
  ) async {
    await open(tester);
    await addColumn(tester, 'adet', numeric: true);
    await addColumn(tester, 'fiyat', numeric: true);

    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(columnName), 'tutar');
    await tester.tap(find.text(tr.formula).last);
    await tester.pumpAndSettle();

    // Formül kurarken öbür sütunların adları hazır durur.
    expect(find.text('adet'), findsWidgets);
    expect(find.text('fiyat'), findsWidgets);
  });

  testWidgets('ad ya da sütun eksikse tablo oluşmaz ve neyin eksik olduğu '
      'yazar', (tester) async {
    await open(tester);
    await addColumn(tester, 'kilo');
    await finish(tester);
    expect(find.text(tr.tableNameEmpty), findsOneWidget);
    expect(tables.tables, isEmpty);

    await tester.tap(find.byKey(const ValueKey('quick-column-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('column-remove')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(name), 'Boş');
    await finish(tester);
    expect(find.text(tr.quickNeedColumn), findsOneWidget);
    expect(tables.tables, isEmpty);
  });

  testWidgets('hazır örneklere buradan geçilir', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('quick-templates')));
    await tester.pumpAndSettle();

    expect(find.byType(TemplateManagementDialog), findsOneWidget);
    expect(find.text(tr.exampleTemplates), findsOneWidget);
  });

  test('tek sütun formu sonucu ya sütundur ya da kaldırma', () {
    final saved = ColumnFormResult.saved(ColumnModel(name: 'kilo'));
    expect(saved.removed, isFalse);
    expect(saved.column!.name, 'kilo');
    const removed = ColumnFormResult.removed();
    expect(removed.removed, isTrue);
    expect(removed.column, isNull);
  });
}
