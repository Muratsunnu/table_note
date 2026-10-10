import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/template_provider.dart';
import 'package:table_note/widgets/create_table_dialog.dart';

class _Subscription extends ChangeNotifier implements SubscriptionProvider {
  @override
  bool get isPremium => true;
  @override
  bool get hasUnlimitedPlan => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Yeni tabloda sayısal sütuna başlangıç değeri verilebilir.
void main() {
  final tr = AppLocalizations(const Locale('tr'));

  testWidgets('sayısal sütunda alan çıkar ve değer tabloyla kaydedilir', (
    tester,
  ) async {
    // Test yazı tipi gerçeğinden geniş; ekran ona göre geniş tutulur.
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final tables = TableProvider();
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
        child: const MaterialApp(
          locale: Locale('tr'),
          supportedLocales: [Locale('tr'), Locale('en')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: CreateTableDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    const field = ValueKey('starting-value');

    // Düz yazı sütununda alan yoktur.
    await tester.tap(find.textContaining('gelişmiş'));
    await tester.pumpAndSettle();
    expect(find.byKey(field), findsNothing);

    // Sayısal yapılınca çıkar.
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.byKey(field), findsOneWidget);

    final texts = find.byType(TextField);
    await tester.enterText(texts.at(0), 'Harcamalar');
    await tester.enterText(texts.at(1), 'harcama');
    await tester.enterText(find.byKey(field), '100.000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, tr.createTable));
    await tester.pumpAndSettle();

    final table = tables.tables.single;
    expect(table.tableName, 'Harcamalar');
    expect(table.columns.single.isNumeric, isTrue);
    expect(table.columns.single.startingValue, 100000);
  });
}
