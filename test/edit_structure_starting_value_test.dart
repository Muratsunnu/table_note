import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/widgets/edit_table_structure_dialog.dart';

/// Başlangıç değeri tablo oluşturulduktan sonra da verilir, artırılır ve
/// kaldırılır: yapı düzenleme ekranında mevcut sütunlarda da alan vardır.
void main() {
  final tr = AppLocalizations(const Locale('tr'));
  late TableProvider tables;

  Future<void> openEditor(WidgetTester tester, {double? startingValue}) async {
    // Test yazı tipi gerçeğinden geniş; ekran ona göre geniş tutulur.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveTables([
      TableModel(
        tableName: 'Harcamalar',
        columns: [
          ColumnModel(name: 'açıklama'),
          ColumnModel(
            name: 'harcama',
            isNumeric: true,
            startingValue: startingValue,
          ),
        ],
        rows: [
          ['kira', '25000'],
        ],
      ),
    ]);
    tables = TableProvider();
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
                    builder: (_) => const EditTableStructureDialog(),
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

  const field = ValueKey('starting-value');

  testWidgets('alan yalnızca toplamı alınan sütunda çıkar', (tester) async {
    await openEditor(tester);

    // İki sütundan yalnızca sayısal olanda.
    expect(find.byKey(field), findsOneWidget);
  });

  testWidgets('mevcut sütuna sonradan başlangıç değeri verilir', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.enterText(find.byKey(field), '100.000');
    await tester.pump();
    await tester.tap(find.text(tr.save));
    await tester.pumpAndSettle();

    expect(tables.currentTable!.columns[1].startingValue, 100000);
    expect(tables.columnBalances.single.remaining, 75000);
    // Satırlar yerinde.
    expect(tables.currentTable!.rows.single, ['kira', '25000']);
  });

  testWidgets('değer mevcut hâliyle açılır ve artırılabilir', (tester) async {
    await openEditor(tester, startingValue: 100000);

    expect(find.text('100.000'), findsOneWidget);
    await tester.enterText(find.byKey(field), '250000');
    await tester.pump();
    await tester.tap(find.text(tr.save));
    await tester.pumpAndSettle();

    expect(tables.currentTable!.columns[1].startingValue, 250000);
  });

  testWidgets('alan boşaltılınca değer kaldırılır', (tester) async {
    await openEditor(tester, startingValue: 100000);

    await tester.enterText(find.byKey(field), '');
    await tester.pump();
    await tester.tap(find.text(tr.save));
    await tester.pumpAndSettle();

    expect(tables.currentTable!.columns[1].startingValue, isNull);
    expect(tables.columnBalances, isEmpty);
  });

  testWidgets('vazgeçilirse tablo değişmez', (tester) async {
    await openEditor(tester, startingValue: 100000);

    await tester.enterText(find.byKey(field), '5');
    await tester.pump();
    await tester.tap(find.text(tr.cancel));
    await tester.pumpAndSettle();

    expect(tables.currentTable!.columns[1].startingValue, 100000);
  });
}
