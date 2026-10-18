import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/widgets/tally_template_form_dialog.dart';

/// Çetele formlarında durum ve kayıt, listenin sonundaki kesik çizgili
/// karttan eklenir; başlıktaki "Ekle" düğmesi yoktur.
void main() {
  final loc = AppLocalizations(const Locale('tr'));

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tr'),
        supportedLocales: [Locale('tr'), Locale('en')],
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: TallyTemplateFormDialog()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('şablon formunda durum ve kayıt alttaki karttan eklenir', (
    tester,
  ) async {
    await open(tester);

    expect(find.widgetWithText(TextButton, loc.add), findsNothing);
    expect(find.text(loc.tallyAddStatus), findsOneWidget);
    expect(find.text(loc.tallyAddItem), findsOneWidget);
    expect(find.widgetWithText(TextField, loc.tallyCode), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-status-card')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, loc.tallyCode), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-item-card')));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, '${loc.tallyItem} 2'),
      findsOneWidget,
    );
  });
}
