import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/widgets/row_draft_binding.dart';

void main() {
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
        home: Scaffold(body: TextField(controller: controller)),
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

  testWidgets('yarım kalan kayıt sessizce geri gelir', (tester) async {
    final closeFirst = await openForm(tester);
    await tester.enterText(find.byType(TextField), 'Konya');
    await tester.pump();
    await closeFirst();

    final close = await openForm(tester);
    // Kutu ya da uyarı yok; kişi kaldığı yerden devam eder.
    expect(find.text('Konya'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    await close();
  });
}
