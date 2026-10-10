import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/template_provider.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/widgets/template_management_dialog.dart';

/// Şablon listesindeki sütun sayısı uygulamanın diliyle yazılır.
void main() {
  Future<void> pumpList(WidgetTester tester, Locale locale) async {
    late TemplateProvider templates;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.saveTemplates([
        TemplateModel(
          templateName: 'Sevkiyat',
          columns: [
            ColumnModel(name: 'plaka'),
            ColumnModel(name: 'yükleme'),
            ColumnModel(name: 'kilo', isNumeric: true),
          ],
        ),
      ]);
      templates = TemplateProvider();
      while (templates.isLoading || !templates.hasTemplates) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    addTearDown(templates.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<TemplateProvider>.value(
        value: templates,
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const TemplateManagementDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('İngilizcede sütun sayısı İngilizce yazılır', (tester) async {
    await pumpList(tester, const Locale('en'));

    expect(find.text('Sevkiyat'), findsOneWidget);
    expect(find.text('3 columns'), findsOneWidget);
    expect(find.textContaining('sütun'), findsNothing);
  });

  testWidgets('Türkçede sütun sayısı Türkçe yazılır', (tester) async {
    await pumpList(tester, const Locale('tr'));

    expect(find.text('3 sütun'), findsOneWidget);
  });
}
