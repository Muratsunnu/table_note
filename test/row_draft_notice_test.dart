import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/l10n/ux_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/widgets/row_draft_binding.dart';

void main() {
  final tr = AppLocalizations(const Locale('tr'));
  final columns = [ColumnModel(name: 'nereden')];

  // Formu açar; dönen fonksiyon formu kapatır (taslak cihaza yazılır).
  Future<Future<void> Function()> openForm(WidgetTester tester) async {
    final controller = TextEditingController();
    final draft = RowDraftBinding(
      key: 'add_row_test',
      columns: columns,
      controllers: [controller],
      onRestore: () {},
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Column(
            children: [
              RowDraftNotice(draft: draft),
              TextField(controller: controller),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    return () async {
      await tester.pumpWidget(const SizedBox.shrink());
      draft.dispose();
      controller.dispose();
      // Kapanırken bekleyen taslak yazılsın.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    };
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('yazarken taslak bildirimi çıkmaz', (tester) async {
    final close = await openForm(tester);

    await tester.enterText(find.byType(TextField), 'Konya');
    await tester.pump();

    expect(find.text(tr.draftRestored), findsNothing);
    expect(find.text(tr.discardDraft), findsNothing);
    await close();
  });

  testWidgets('yarım kalan taslak geri gelince haber verilir ve silinebilir', (
    tester,
  ) async {
    final closeFirst = await openForm(tester);
    await tester.enterText(find.byType(TextField), 'Konya');
    await tester.pump();
    await closeFirst();

    final close = await openForm(tester);
    expect(find.text('Konya'), findsOneWidget);
    expect(find.text(tr.draftRestored), findsOneWidget);

    // Kaldığı yerden yazmaya devam etse de taslağı silebilir.
    await tester.enterText(find.byType(TextField), 'Konya merkez');
    await tester.pump();
    expect(find.text(tr.discardDraft), findsOneWidget);

    await tester.tap(find.text(tr.discardDraft));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Konya merkez'), findsNothing);
    expect(find.text(tr.draftRestored), findsNothing);
    await close();
  });
}
