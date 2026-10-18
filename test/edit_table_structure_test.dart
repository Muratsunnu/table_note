import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/widgets/quick_table_builder.dart';

/// Paylaşılmış ve sahibi bu cihaz olan tablo; senkron servisi kurulmaz.
class _SharedTables extends TableProvider {
  @override
  bool isSharedTable(String tableId) => true;
  @override
  bool isSharedOwner(String tableId) => true;
}

/// Tablonun yapısı da tablo kurulurken kullanılan ekranla düzenlenir.
void main() {
  final tr = AppLocalizations(const Locale('tr'));
  const field = ValueKey('starting-value');
  const columnName = ValueKey('column-name');
  const columnSave = ValueKey('column-save');
  const save = ValueKey('quick-create');
  late TableProvider tables;

  TableModel harcamalar({double? startingValue}) => TableModel(
    tableName: 'Harcamalar',
    columns: [
      ColumnModel(name: 'açıklama'),
      ColumnModel(
        name: 'harcama',
        isNumeric: true,
        startingValue: startingValue,
      ),
      ColumnModel(
        name: 'kdv',
        columnType: ColumnType.formula,
        formula: '{harcama}*0.2',
      ),
    ],
    rows: [
      ['kira', '25000', '5000'],
    ],
  );

  Future<void> openEditor(
    WidgetTester tester, {
    double? startingValue,
    bool shared = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveTables([harcamalar(startingValue: startingValue)]);
    tables = shared ? _SharedTables() : TableProvider();
    addTearDown(tables.dispose);
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QuickTableBuilder.editTable(),
                  ),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  Future<void> openColumn(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(ValueKey('quick-column-$index')));
    await tester.pumpAndSettle();
  }

  Future<void> saveColumn(WidgetTester tester) async {
    await tester.tap(find.byKey(columnSave));
    await tester.pumpAndSettle();
  }

  Future<void> saveTable(WidgetTester tester) async {
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
  }

  testWidgets('tablonun adı, sütunları ve son kaydı hazır gelir', (
    tester,
  ) async {
    await openEditor(tester);

    expect(find.text(tr.editTableStructure), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Harcamalar'), findsOneWidget);
    expect(find.text('açıklama'), findsOneWidget);
    // Başlıkların altında örnek yerine tablonun son kaydı durur.
    expect(find.text('kira'), findsOneWidget);
    // Tabloyu düzenlerken şablona yönlendirilmez.
    expect(find.byKey(const ValueKey('quick-templates')), findsNothing);
  });

  testWidgets('var olan sütunun türü değişmez, sütun kaldırılamaz', (
    tester,
  ) async {
    await openEditor(tester);
    await openColumn(tester, 0);

    expect(find.byKey(const ValueKey('column-locked-type')), findsOneWidget);
    expect(find.text(tr.cannotChange), findsOneWidget);
    expect(find.byKey(const ValueKey('column-remove')), findsNothing);
    // Toplamı alınmayan sütunda başlangıç değeri yoktur.
    expect(find.byKey(field), findsNothing);
  });

  testWidgets('sütunun adı değişince formül de onu izler, kayıtlar yerinde', (
    tester,
  ) async {
    await openEditor(tester);
    await openColumn(tester, 1);
    await tester.enterText(find.byKey(columnName), 'tutar');
    await saveColumn(tester);
    await saveTable(tester);

    final table = tables.currentTable!;
    expect(table.columns.map((c) => c.name), ['açıklama', 'tutar', 'kdv']);
    expect(table.columns[2].formula, '{tutar}*0.2');
    expect(table.rows.single, ['kira', '25000', '5000']);
    expect(find.text(tr.tableStructureUpdated), findsOneWidget);
  });

  testWidgets('mevcut sütuna sonradan başlangıç değeri verilir', (
    tester,
  ) async {
    await openEditor(tester);
    await openColumn(tester, 1);
    await tester.enterText(find.byKey(field), '100.000');
    await tester.pump();
    await saveColumn(tester);
    await saveTable(tester);

    expect(tables.currentTable!.columns[1].startingValue, 100000);
    expect(tables.columnBalances.single.remaining, 75000);
    expect(tables.currentTable!.rows.single, ['kira', '25000', '5000']);
  });

  testWidgets('değer mevcut hâliyle açılır ve kaldırılabilir', (tester) async {
    await openEditor(tester, startingValue: 100000);
    await openColumn(tester, 1);

    expect(find.text('100.000'), findsOneWidget);
    await tester.enterText(find.byKey(field), '');
    await tester.pump();
    await saveColumn(tester);
    await saveTable(tester);

    expect(tables.currentTable!.columns[1].startingValue, isNull);
    expect(tables.columnBalances, isEmpty);
  });

  testWidgets('yeni sütun sona eklenir, eski kayıtta boş kalır', (
    tester,
  ) async {
    await openEditor(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add-column')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(columnName), 'not');
    await saveColumn(tester);

    // Yeni sütun henüz kaydedilmediği için kaldırılabilir.
    await openColumn(tester, 3);
    expect(find.byKey(const ValueKey('column-remove')), findsOneWidget);
    await tester.tap(find.byKey(columnSave));
    await tester.pumpAndSettle();
    await saveTable(tester);

    final table = tables.currentTable!;
    expect(table.columns.last.name, 'not');
    expect(table.rows.single, ['kira', '25000', '5000', '']);
  });

  testWidgets('vazgeçilirse tablo değişmez', (tester) async {
    await openEditor(tester, startingValue: 100000);
    await openColumn(tester, 1);
    await tester.enterText(find.byKey(field), '5');
    await tester.pump();
    await saveColumn(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(tables.currentTable!.columns[1].startingValue, 100000);
  });

  testWidgets('ortak tabloda sütunların yeri değişmez', (tester) async {
    await openEditor(tester, shared: true);

    expect(find.text(tr.sharedColumnOrderHint), findsOneWidget);
    final listeners = tester.widgetList<ReorderableDelayedDragStartListener>(
      find.byType(ReorderableDelayedDragStartListener),
    );
    expect(listeners, isNotEmpty);
    expect(listeners.every((listener) => !listener.enabled), isTrue);
  });

  group('kayıtlar sütunlarıyla taşınır', () {
    // Sağlayıcı kurulur kurulmaz okumaya başlar; önce kayıt yazılır.
    Future<TableProvider> load(TableProvider Function() create) async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.saveTables([harcamalar()]);
      final provider = create();
      addTearDown(provider.dispose);
      while (provider.currentTable == null) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return provider;
    }

    test('sütunların yeri değişince hücreler de yer değiştirir', () async {
      final provider = await load(TableProvider.new);
      final columns = provider.currentTable!.columns;

      final saved = await provider.restructureTable(
        'Harcamalar',
        [columns[2], ColumnModel(name: 'not'), columns[0], columns[1]],
        [2, null, 0, 1],
      );

      expect(saved, isTrue);
      expect(provider.currentTable!.rows.single, ['5000', '', 'kira', '25000']);
    });

    test('ortak tabloda yer değişikliği reddedilir, tablo bozulmaz', () async {
      final provider = await load(_SharedTables.new);
      final columns = provider.currentTable!.columns;

      final saved = await provider.restructureTable(
        'Harcamalar',
        [columns[1], columns[0], columns[2]],
        [1, 0, 2],
      );

      expect(saved, isFalse);
      expect(provider.currentTable!.rows.single, ['kira', '25000', '5000']);
    });
  });
}
