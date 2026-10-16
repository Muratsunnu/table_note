import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/data/example_templates.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/template_provider.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/widgets/template_management_dialog.dart';

/// Ücretsiz kullanıcı; sınır notları görünür.
class _FreeUser extends ChangeNotifier implements SubscriptionProvider {
  @override
  bool get hasUnlimitedPlan => false;
  @override
  bool get isPremium => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Uygulamayla gelen hazır örnekler: şablonlar gibi kullanılır ama cihaza
/// yazılmaz.
void main() {
  test('her örnek iki dilde de aynı yapıdadır ve formülleri tutarlıdır', () {
    final tr = exampleTemplates('tr');
    final en = exampleTemplates('en');
    expect(tr.length, en.length);
    expect(tr.map((t) => t.id).toSet().length, tr.length);

    for (var i = 0; i < tr.length; i++) {
      expect(tr[i].id, en[i].id);
      expect(tr[i].columns.length, en[i].columns.length);
      for (final template in [tr[i], en[i]]) {
        final names = template.columns.map((c) => c.name).toList();
        expect(names.toSet().length, names.length, reason: template.id);
        for (final column in template.columns) {
          expect(column.name.trim(), isNotEmpty);
          if (!column.isFormula) continue;
          // Formül, aynı tablodaki sütunları adıyla bulur.
          final used = RegExp(
            r'\{([^}]+)\}',
          ).allMatches(column.formula!).map((match) => match.group(1)!);
          expect(used, isNotEmpty);
          for (final name in used) {
            expect(names, contains(name), reason: template.id);
          }
        }
      }
    }
  });

  group('şablon ekranında', () {
    Future<void> pumpList(
      WidgetTester tester,
      Locale locale, {
      List<TemplateModel> own = const [],
    }) async {
      late TemplateProvider templates;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await StorageService.saveTemplates(own);
        templates = TemplateProvider();
        while (templates.isLoading ||
            templates.templates.length != own.length) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      addTearDown(templates.dispose);
      final tables = TableProvider();
      final subscription = _FreeUser();
      addTearDown(tables.dispose);
      addTearDown(subscription.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TemplateProvider>.value(value: templates),
            ChangeNotifierProvider<TableProvider>.value(value: tables),
            ChangeNotifierProvider<SubscriptionProvider>.value(
              value: subscription,
            ),
          ],
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

    testWidgets('hiç şablonu olmayan da örnekleri görür', (tester) async {
      await pumpList(tester, const Locale('tr'));

      final loc = AppLocalizations(const Locale('tr'));
      expect(find.text(loc.exampleTemplates), findsOneWidget);
      expect(find.text('Gelir gider'), findsOneWidget);
      expect(find.text('Borç alacak'), findsOneWidget);
    });

    testWidgets('örnekler uygulamanın diliyle gelir', (tester) async {
      await pumpList(tester, const Locale('en'));

      expect(find.text('Income and expenses'), findsOneWidget);
      expect(find.text('Gelir gider'), findsNothing);
    });

    testWidgets('kendi şablonları örneklerden önce durur ve cihaza örnek '
        'yazılmaz', (tester) async {
      await pumpList(
        tester,
        const Locale('tr'),
        own: [
          TemplateModel(
            templateName: 'Benim şablonum',
            columns: [ColumnModel(name: 'ad')],
          ),
        ],
      );

      final mine = tester.getTopLeft(find.text('Benim şablonum')).dy;
      final examples = tester
          .getTopLeft(find.byKey(const ValueKey('example-templates-header')))
          .dy;
      expect(mine, lessThan(examples));
      // Örnekler ücretsiz şablon sınırına sayılmasın diye saklanmaz.
      final stored = await tester.runAsync(StorageService.loadTemplates);
      expect(stored!.map((t) => t.templateName), ['Benim şablonum']);
    });

    testWidgets('örneğe dokununca normal şablon gibi ad sorar', (tester) async {
      await pumpList(tester, const Locale('tr'));

      await tester.tap(find.text('Stok sayımı'));
      await tester.pumpAndSettle();

      // Şablondan oluşturma penceresi örneğin adıyla açılır.
      expect(find.widgetWithText(TextField, 'Stok sayımı'), findsOneWidget);
    });
  });
}
