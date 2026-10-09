import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/auth_provider.dart';
import 'package:table_note/providers/backup_reminder_provider.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/widgets/backup_help.dart';
import 'package:table_note/widgets/backup_reminder.dart';

class _Auth extends AuthProvider {
  bool signedIn = true;
  @override
  bool get isSignedIn => signedIn;
  @override
  bool get isAnonymous => false;
  @override
  User? get user => signedIn
      ? const User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-10-01T00:00:00Z',
        )
      : null;
}

class _Subscription extends ChangeNotifier implements SubscriptionProvider {
  bool premium = true;
  @override
  bool get isPremium => premium;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late DateTime now;
  late BackupReminderProvider reminder;
  late _Auth auth;
  late _Subscription subscription;
  late int opened;

  Future<void> pumpScreen(
    WidgetTester tester, {
    int? daysSinceBackup,
    Locale locale = const Locale('tr'),
  }) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveTables([
      TableModel(
        tableName: 'Seferler',
        columns: [ColumnModel(name: 'nereden')],
        rows: [
          ['Konya'],
        ],
      ),
    ]);
    now = DateTime.now().add(const Duration(minutes: 1));
    reminder = BackupReminderProvider(now: () => now);
    auth = _Auth();
    subscription = _Subscription();
    final tables = TableProvider();
    opened = 0;
    addTearDown(reminder.dispose);
    addTearDown(auth.dispose);
    addTearDown(subscription.dispose);
    addTearDown(tables.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BackupReminderProvider>.value(value: reminder),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: subscription,
          ),
          ChangeNotifierProvider<TableProvider>.value(value: tables),
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
          home: Scaffold(
            body: Column(
              children: [
                BackupReminderCard(onBackUp: () => opened++),
                BackupStatusLine(onTap: () => opened++),
                const BackupHelpLink(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (daysSinceBackup != null) {
      await reminder.markBackedUp(
        'user-1',
        at: now.subtract(Duration(days: daysSinceBackup, hours: 1)),
      );
      await tester.pumpAndSettle();
    }
  }

  const card = ValueKey('backup-reminder');
  const line = ValueKey('backup-status-line');
  final tr = AppLocalizations(const Locale('tr'));
  final en = AppLocalizations(const Locale('en'));

  testWidgets('yeni yedeklenmişse hiçbir şey görünmez', (tester) async {
    await pumpScreen(tester, daysSinceBackup: 1);

    expect(find.byKey(card), findsNothing);
    expect(find.byKey(line), findsNothing);
  });

  testWidgets('üç günden sonra yalnızca küçük satır çıkar', (tester) async {
    await pumpScreen(tester, daysSinceBackup: 4);

    expect(find.byKey(card), findsNothing);
    expect(find.text('Son yedekleme: 4 gün önce'), findsOneWidget);

    await tester.tap(find.byKey(line));
    expect(opened, 1);
  });

  testWidgets('yedi günden sonra kart çıkar; "Şimdi Yedekle" ekranı açar', (
    tester,
  ) async {
    await pumpScreen(tester, daysSinceBackup: 9);

    expect(find.text(tr.backupReminderDays(9)), findsOneWidget);
    // Kart varken aynı bilgiyi satır yinelemez.
    expect(find.byKey(line), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backup-reminder-now')));
    expect(opened, 1);
  });

  testWidgets('"Sonra" kartı bugünlük kaldırır, yarın yeniden getirir', (
    tester,
  ) async {
    await pumpScreen(tester, daysSinceBackup: 9);

    await tester.tap(find.byKey(const ValueKey('backup-reminder-later')));
    await tester.pumpAndSettle();
    expect(find.byKey(card), findsNothing);
    expect(find.byKey(line), findsOneWidget);

    now = now.add(const Duration(days: 1));
    reminder.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text(tr.backupReminderDays(10)), findsOneWidget);
  });

  testWidgets('hiç yedek almamış Premium kullanıcıya kart çıkar', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text(tr.backupReminderNever), findsOneWidget);
  });

  testWidgets('Premium ya da hesap yoksa hatırlatılmaz', (tester) async {
    await pumpScreen(tester, daysSinceBackup: 30);
    expect(find.byKey(card), findsOneWidget);

    subscription.premium = false;
    subscription.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byKey(card), findsNothing);
    expect(find.byKey(line), findsNothing);

    subscription.premium = true;
    auth.signedIn = false;
    auth.notifyListeners();
    subscription.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byKey(card), findsNothing);
  });

  testWidgets('metinler İngilizce arayüzde İngilizcedir', (tester) async {
    await pumpScreen(tester, daysSinceBackup: 9, locale: const Locale('en'));

    expect(find.text(en.backupReminderDays(9)), findsOneWidget);
    expect(find.text(en.backupLater), findsOneWidget);
    expect(find.text(en.backupNow), findsOneWidget);
  });

  testWidgets('"Yedekleme nedir?" kısa açıklamayı açar', (tester) async {
    await pumpScreen(tester, daysSinceBackup: 1);

    await tester.tap(find.byKey(const ValueKey('backup-help')));
    await tester.pumpAndSettle();

    expect(find.text(tr.backupHelpWhat), findsOneWidget);
    expect(find.text(tr.backupHelpRestore), findsOneWidget);
    expect(find.text(tr.backupHelpManual), findsOneWidget);
    expect(find.text(tr.backupHelpShared), findsOneWidget);

    await tester.tap(find.text(tr.understood));
    await tester.pumpAndSettle();
    expect(find.text(tr.backupHelpWhat), findsNothing);
  });
}
