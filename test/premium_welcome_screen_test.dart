import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/screens/premium_welcome_screen.dart';
import 'package:table_note/services/storage_service.dart';

class _Subscription extends ChangeNotifier implements SubscriptionProvider {
  @override
  DateTime? get validUntil => DateTime(2026, 10, 17);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final tr = AppLocalizations(const Locale('tr'));

  Future<void> pumpWelcome(WidgetTester tester, {bool withTable = true}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    if (withTable) {
      await StorageService.saveTables([
        TableModel(
          tableName: 'Seferler',
          columns: [ColumnModel(name: 'nereden')],
          rows: const [],
        ),
      ]);
    }
    final subscription = _Subscription();
    final tables = TableProvider();
    addTearDown(subscription.dispose);
    addTearDown(tables.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: subscription,
          ),
          ChangeNotifierProvider<TableProvider>.value(value: tables),
        ],
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
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PremiumWelcomeScreen(),
                    ),
                  ),
                  child: const Text('aç'),
                ),
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

  testWidgets('teşekkür eder, geçerlilik tarihini ve üç kısa yolu gösterir', (
    tester,
  ) async {
    await pumpWelcome(tester);

    expect(find.text(tr.premiumWelcomeTitle), findsOneWidget);
    expect(find.textContaining('17 Eki 2026'), findsOneWidget);
    expect(find.text(tr.welcomeBackup), findsOneWidget);
    expect(find.text(tr.welcomeShare), findsOneWidget);
    expect(find.text(tr.welcomeVoice), findsOneWidget);
  });

  testWidgets('tablosu olmayan kişiye paylaşma ve sesle kayıt önerilmez', (
    tester,
  ) async {
    await pumpWelcome(tester, withTable: false);

    expect(find.text(tr.welcomeBackup), findsOneWidget);
    expect(find.text(tr.welcomeShare), findsNothing);
    expect(find.text(tr.welcomeVoice), findsNothing);
  });

  testWidgets('"Uygulamaya dön" ekranı kapatır', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.byKey(const ValueKey('welcome-close')));
    await tester.pumpAndSettle();

    expect(find.byType(PremiumWelcomeScreen), findsNothing);
    expect(find.text('aç'), findsOneWidget);
  });
}
