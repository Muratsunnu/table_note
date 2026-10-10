import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/providers/auth_provider.dart';
import 'package:table_note/providers/backup_reminder_provider.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/screens/cloud_backup_screen.dart';
import 'package:table_note/services/cloud_repository.dart';

class _Auth extends AuthProvider {
  @override
  bool get isAvailable => true;
  @override
  bool get isSignedIn => true;
  @override
  bool get isAnonymous => false;
  @override
  User? get user => const User(
    id: 'user-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-01T00:00:00Z',
  );
}

class _Subscription extends ChangeNotifier implements SubscriptionProvider {
  @override
  bool get isPremium => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements CloudRepository {
  _Repository(this.entries);

  final List<CloudEntry> entries;

  @override
  Future<List<CloudEntry>> list() async => entries;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CloudEntry _entry(
  String name, {
  String owner = 'user-1',
  String kind = 'table',
}) => CloudEntry(
  id: name,
  ownerId: owner,
  kind: kind,
  name: name,
  payload: const {},
  updatedAt: DateTime.now(),
  revision: 1,
  collaborationEnabled: false,
);

void main() {
  final tr = AppLocalizations(const Locale('tr'));

  Future<void> pumpScreen(WidgetTester tester, List<CloudEntry> entries) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _Auth();
    final subscription = _Subscription();
    final reminder = BackupReminderProvider();
    addTearDown(() {
      auth.dispose();
      subscription.dispose();
      reminder.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: subscription,
          ),
          ChangeNotifierProvider<BackupReminderProvider>.value(value: reminder),
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
          home: CloudBackupScreen(repository: _Repository(entries)),
        ),
      ),
    );
    // Hatırlatma kaydı cihazdan gerçek zamanlı okunur.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('buluttaki yedekler listelenir ve kime ait olduğu yazar', (
    tester,
  ) async {
    await pumpScreen(tester, [
      _entry('Sevkiyat'),
      _entry('Yoklama', kind: 'tally'),
      _entry('Ortak liste', owner: 'user-2'),
    ]);

    expect(find.text('Sevkiyat'), findsOneWidget);
    expect(find.text('Yoklama'), findsOneWidget);
    expect(find.text(tr.myBackup), findsNWidgets(2));
    expect(find.text(tr.sharedWithMe), findsOneWidget);
    // Yalnızca kendi yedeği başkasına açılabilir.
    expect(find.byIcon(Icons.share_rounded), findsNWidgets(2));
  });

  testWidgets('buluttaki en yeni yedek son yedekleme olarak gösterilir', (
    tester,
  ) async {
    await pumpScreen(tester, [_entry('Sevkiyat')]);

    expect(find.text(tr.lastBackupLabel(0)), findsOneWidget);
  });

  testWidgets('hiç yedek yoksa bunu söyler', (tester) async {
    await pumpScreen(tester, const []);

    expect(find.text(tr.noCloudBackup), findsOneWidget);
    expect(find.text(tr.lastBackupLabel(null)), findsOneWidget);
  });
}
