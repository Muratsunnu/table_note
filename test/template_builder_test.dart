import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/template_provider.dart';
import 'package:table_note/services/storage_service.dart';
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

/// Şablonlar da tablolar gibi tablonun üstünde kurulur ve düzenlenir.
void main() {
  final tr = AppLocalizations(const Locale('tr'));
  const name = ValueKey('quick-table-name');
  const add = ValueKey('quick-add-column');
  const create = ValueKey('quick-create');
  const save = ValueKey('column-save');
  const columnName = ValueKey('column-name');
  late TemplateProvider templates;

  Future<void> open(
    WidgetTester tester, {
    List<TemplateModel> own = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late TableProvider tables;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.saveTemplates(own);
      tables = TableProvider();
      templates = TemplateProvider();
      while (templates.isLoading || templates.templates.length != own.length) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
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
        child: const MaterialApp(
          locale: Locale('tr'),
          supportedLocales: [Locale('tr'), Locale('en')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: TemplateManagementDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addColumn(WidgetTester tester, String text) async {
    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(columnName), text);
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

  testWidgets('yeni şablon, tablo kurar gibi kurulur', (tester) async {
    await open(tester);
    await tester.tap(find.text(tr.createNewTemplate).last);
    await tester.pumpAndSettle();

    expect(find.byType(QuickTableBuilder), findsOneWidget);
    expect(find.text(tr.createNewTemplateTitle), findsOneWidget);
    expect(find.text(tr.templateName), findsOneWidget);
    // Şablon kurarken şablona yönlendiren bağlantı yoktur.
    expect(find.byKey(const ValueKey('quick-templates')), findsNothing);

    await tester.enterText(find.byKey(name), 'Seferler');
    await addColumn(tester, 'sıra');
    await addColumn(tester, 'nereden');
    await finish(tester);

    expect(find.byType(QuickTableBuilder), findsNothing);
    final template = templates.templates.single;
    expect(template.templateName, 'Seferler');
    expect(template.columns.map((c) => c.name), ['sıra', 'nereden']);
  });

  testWidgets('şablon düzenlenirken adı ve sütunları hazır gelir', (
    tester,
  ) async {
    await open(
      tester,
      own: [
        TemplateModel(
          templateName: 'Seferler',
          columns: [
            ColumnModel(name: 'nereden'),
            ColumnModel(name: 'kilo', isNumeric: true),
          ],
        ),
      ],
    );
    await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.edit));
    await tester.pumpAndSettle();

    expect(find.text(tr.editTemplate), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Seferler'), findsOneWidget);
    expect(find.text('nereden'), findsOneWidget);
    expect(find.text(tr.kindNumberNote), findsOneWidget);

    await addColumn(tester, 'nereye');
    await finish(tester);

    expect(templates.templates.single.columns.map((c) => c.name), [
      'nereden',
      'kilo',
      'nereye',
    ]);
  });

  Future<void> openMenu(WidgetTester tester, String id) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(id)),
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<TemplateProvider> reload(WidgetTester tester) async {
    late TemplateProvider fresh;
    await tester.runAsync(() async {
      fresh = TemplateProvider();
      while (fresh.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    addTearDown(fresh.dispose);
    return fresh;
  }

  testWidgets('hazır örnek kendi şablonu gibi düzenlenir ve öyle kalır', (
    tester,
  ) async {
    await open(tester);
    await openMenu(tester, 'example-income');
    await tester.tap(find.text(tr.edit));
    await tester.pumpAndSettle();

    expect(find.text(tr.editTemplate), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Gelir gider'), findsOneWidget);
    expect(find.text('açıklama'), findsOneWidget);

    await tester.enterText(find.byKey(name), 'Kasa');
    await addColumn(tester, 'kasa');
    await finish(tester);

    // Kendi şablonu olarak çoğalmaz; örneğin yerine düzenlenmiş hali geçer.
    expect(templates.templates, isEmpty);
    final edited = templates.examples('tr').first;
    expect(edited.id, 'example-income');
    expect(edited.templateName, 'Kasa');
    expect(edited.columns.last.name, 'kasa');
    expect(find.text('Kasa'), findsOneWidget);

    // Uygulama yeniden açıldığında da düzenlendiği gibidir.
    final fresh = await reload(tester);
    expect(fresh.examples('tr').first.templateName, 'Kasa');
    expect(fresh.examples('en').first.templateName, 'Kasa');
  });

  testWidgets('hazır örnek silinir, geri alınır ve sonradan geri getirilir', (
    tester,
  ) async {
    await open(tester);
    const restore = ValueKey('restore-examples');
    expect(find.byKey(restore), findsNothing);

    await openMenu(tester, 'example-debts');
    await tester.tap(find.text(tr.delete));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('example-debts')), findsNothing);
    expect(find.text(tr.exampleRemoved('Borç alacak')), findsOneWidget);

    await tester.tap(find.text(tr.undo));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('example-debts')), findsOneWidget);

    await openMenu(tester, 'example-debts');
    await tester.tap(find.text(tr.delete));
    await tester.pumpAndSettle();
    expect(
      (await reload(tester)).examples('tr').map((e) => e.id),
      isNot(contains('example-debts')),
    );

    await tester.tap(find.byKey(restore));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('example-debts')), findsOneWidget);
    expect(find.byKey(restore), findsNothing);
  });
}
