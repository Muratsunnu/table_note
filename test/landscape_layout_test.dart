import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/main.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/providers/theme_provider.dart';
import 'package:table_note/services/storage_service.dart';

/// Yan çevrilmiş telefon: yükseklik az, iki yanda çentik payı var.
/// Taşma olursa test çerçevesi kendiliğinden hata verir.
Future<void> pumpApp(
  WidgetTester tester, {
  required int tab,
  Size size = const Size(844, 390),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(left: 59, right: 59, bottom: 21);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'onboarding_completed_v1': true,
    'last_active_tab': tab,
  });
  await StorageService.saveTables([
    TableModel(
      tableName: 'Sevkiyat',
      columns: [
        ColumnModel(name: 'yükleme'),
        ColumnModel(name: 'kilo', isNumeric: true),
      ],
      rows: [
        for (var i = 0; i < 12; i++) ['Konya', '${(i + 1) * 100}'],
      ],
    ),
  ]);
  await StorageService.saveTallyTables([
    TallyTableModel(
      tableName: 'Yoklama',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
      statuses: [
        TallyStatus(code: 'GEL', label: 'Geldi', colorValue: 0xFF4CAF50),
        TallyStatus(code: 'YOK', label: 'Yok', colorValue: 0xFFEF5350),
      ],
      items: [
        for (var i = 0; i < 8; i++) TallyItemModel(name: 'Kişi ${i + 1}'),
      ],
    ),
  ]);

  await tester.pumpWidget(
    TableNoteRoot(themeProvider: ThemeProvider(), showOnboarding: false),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (tab, name) in [(0, 'tablo'), (1, 'çetele')]) {
    testWidgets('yan çevrilmiş telefonda $name sekmesi taşmaz', (tester) async {
      await pumpApp(tester, tab: tab);

      // Sekmeler ve kayıt ekleme düğmesi yandaki çubuktadır.
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byTooltip('Kayıt Ekle'),
        ),
        findsOneWidget,
      );
      expect(find.text(tab == 0 ? 'Sevkiyat' : 'Yoklama'), findsOneWidget);
    });

    testWidgets('yan çevrilmiş telefonda $name araması klavyeyle taşmaz', (
      tester,
    ) async {
      await pumpApp(tester, tab: tab);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 210);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });
  }

  testWidgets('çok alçak ekranda da taşmaz', (tester) async {
    await pumpApp(tester, tab: 1, size: const Size(568, 320));

    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('dik tutulan telefonda sekmeler altta kalır', (tester) async {
    await pumpApp(tester, tab: 1, size: const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('ekran çevrilince açık arama kapanmaz', (tester) async {
    await pumpApp(tester, tab: 1, size: const Size(390, 844));
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kişi 3');
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Kişi 3'), findsOneWidget);
  });
}
