import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/providers/auth_provider.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/tally_provider.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/widgets/share_table_sheet.dart';

class _FakeAuth extends AuthProvider {
  bool account = true;
  @override
  bool get isAvailable => true;
  @override
  bool get isSignedIn => account;
}

class _FakeSubscription extends ChangeNotifier implements SubscriptionProvider {
  bool premium = true;
  @override
  bool get isPremium => premium;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepository implements CloudRepository {
  String? storedCode;
  Object? failure;
  final started = <String>[];
  int codeReads = 0;

  @override
  Future<String> startSharing({
    TableModel? table,
    TallyTableModel? tally,
  }) async {
    if (failure != null) throw failure!;
    started.add(table?.tableName ?? tally!.tableName);
    return storedCode = '463404';
  }

  @override
  Future<String?> sharedTableJoinCode(String tableId) async {
    codeReads++;
    return storedCode;
  }

  /// Yanıt bekleyen talepler; rol verilince listeden düşer.
  List<SharedTableMember> members = [];
  final roleChanges = <String>[];

  @override
  Future<List<SharedTableMember>> sharedTableMembers(String tableId) async =>
      members;

  @override
  Future<void> setSharedMemberRole(
    String tableId,
    String memberUserId,
    String role,
  ) async {
    roleChanges.add('$memberUserId=$role');
    members = [
      for (final member in members)
        if (member.userId != memberUserId) member,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _en = AppLocalizations(const Locale('en'));

void main() {
  late TableProvider tables;
  late TallyProvider tallies;
  late _FakeAuth auth;
  late _FakeSubscription subscription;
  late _FakeRepository repository;

  /// Sağlayıcılar gerçek zamanlayıcılarla yüklenir; sahte saatli test
  /// gövdesinde beklenirlerse test asılı kalır.
  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      tables = TableProvider();
      tallies = TallyProvider();
      while (tables.isLoading || tallies.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tables.createTable('seferler', [ColumnModel(name: 'nereden')]);
      await tallies.createTable(
        TallyTableModel(
          tableName: 'yoklama',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 30),
          statuses: [
            TallyStatus(code: 'v', label: 'Var', colorValue: 0xFF4CAF50),
          ],
          items: [TallyItemModel(name: 'Ahmet')],
        ),
        isPremium: true,
      );
    });
    auth = _FakeAuth();
    subscription = _FakeSubscription();
    repository = _FakeRepository();
    addTearDown(() {
      auth.dispose();
      subscription.dispose();
      tables.dispose();
      tallies.dispose();
    });
  }

  Widget sheet({bool isTally = false}) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<SubscriptionProvider>.value(value: subscription),
      ChangeNotifierProvider<TableProvider>.value(value: tables),
      ChangeNotifierProvider<TallyProvider>.value(value: tallies),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: ShareTableSheet(
          tableId: isTally ? tallies.currentTable!.id : tables.currentTable!.id,
          isTally: isTally,
          repository: repository,
        ),
      ),
    ),
  );

  /// Kod, rakamları ayrı hücrelerde çizilir.
  void expectCodeShown(String code) {
    for (final digit in code.split('').toSet()) {
      expect(find.text(digit), findsWidgets, reason: 'rakam $digit');
    }
    expect(find.byKey(const ValueKey('share-copy')), findsOneWidget);
    expect(find.byKey(const ValueKey('share-send')), findsOneWidget);
  }

  testWidgets('one tap shares an unshared table and shows its code', (
    tester,
  ) async {
    await seed(tester);
    final id = tables.currentTable!.id;
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('share-copy')), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('share-start')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    // Yalnızca bu tablo yüklendi, kod ekranda, cihaz artık sahip.
    expect(repository.started, ['seferler']);
    expectCodeShown('463404');
    expect(tables.isSharedOwner(id), isTrue);
  });

  testWidgets('the same button shares a tally through the tally provider', (
    tester,
  ) async {
    await seed(tester);
    final id = tallies.currentTable!.id;
    await tester.pumpWidget(sheet(isTally: true));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('share-start')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(repository.started, ['yoklama']);
    expectCodeShown('463404');
    // Rol yanlış sağlayıcıya yazılsaydı çetele kendini hiç ortak saymazdı.
    expect(tallies.isSharedOwner(id), isTrue);
    expect(tables.isSharedTable(id), isFalse);
  });

  testWidgets('an already shared table shows its code without asking', (
    tester,
  ) async {
    await seed(tester);
    await tester.runAsync(
      () => tables.setSharedRole(tables.currentTable!.id, 'owner'),
    );
    repository.storedCode = '222778';
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();

    expect(repository.codeReads, 1);
    expect(repository.started, isEmpty);
    expectCodeShown('222778');

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('share-copy')));
    await tester.pump();
    expect(copied, '222778');
    expect(find.text(_en.copied), findsOneWidget);
    // Onay yazısı kendiliğinden geri döner.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(_en.copy), findsOneWidget);
  });

  testWidgets('when the server says no Premium the sheet says so too', (
    tester,
  ) async {
    // Uygulama Premium sanıyor, sunucu aksini söylüyor (abonelik bitmiş ya
    // da geliştirme derlemesi). "Bir şeyler ters gitti" demek kullanıcıyı
    // ne yapacağını bilmeden bırakırdı.
    await seed(tester);
    final id = tables.currentTable!.id;
    repository.failure = const SharedTableException('owner_premium_required');
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-start')));
    await tester.pumpAndSettle();

    expect(find.text(_en.premiumRequired), findsOneWidget);
    expect(find.text(_en.sharedTableError('unknown')), findsNothing);
    expect(find.byKey(const ValueKey('share-start')), findsNothing);
    expect(tables.isSharedTable(id), isFalse);
  });

  testWidgets('an unexpected failure keeps the table unshared and retryable', (
    tester,
  ) async {
    await seed(tester);
    final id = tables.currentTable!.id;
    repository.failure = StateError('ağ koptu');
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-start')));
    await tester.pumpAndSettle();

    expect(find.text(_en.sharedTableError('unknown')), findsOneWidget);
    expect(tables.isSharedTable(id), isFalse);
    expect(find.byKey(const ValueKey('share-start')), findsOneWidget);
  });

  testWidgets('without Premium or an account the sheet says what is missing', (
    tester,
  ) async {
    await seed(tester);
    subscription.premium = false;
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();
    expect(find.text(_en.premiumRequired), findsOneWidget);
    expect(find.byKey(const ValueKey('share-start')), findsNothing);

    subscription
      ..premium = true
      ..notifyListeners();
    auth
      ..account = false
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text(_en.shareNeedsAccount), findsOneWidget);
    expect(find.byKey(const ValueKey('share-start')), findsNothing);

    // Giriş yapıp dönen kişi kaldığı yerden devam eder.
    auth
      ..account = true
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('share-start')), findsOneWidget);
    expect(repository.started, isEmpty);
  });

  testWidgets('the owner answers access requests from the same sheet', (
    tester,
  ) async {
    // Dar bir telefonda çizilir: ad, "Reddet" ve "Onayla" aynı satıra
    // sığmazsa test taşma hatasıyla düşer.
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    await tester.runAsync(
      () => tables.setSharedRole(tables.currentTable!.id, 'owner'),
    );
    SharedTableMember asking(String id, String name) => SharedTableMember(
      userId: id,
      displayName: name,
      role: 'viewer',
      joinedAt: DateTime(2026, 10, 9),
      editRequestOpen: true,
    );
    repository
      ..storedCode = '222778'
      ..members = [asking('u1', 'Ayşe'), asking('u2', 'Mehmet Yılmazoğlu')];
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();

    expect(find.text(_en.editRequests), findsOneWidget);
    expect(find.text('Ayşe'), findsOneWidget);
    expect(find.text('Mehmet Yılmazoğlu'), findsOneWidget);

    // Onaylamak düzenleme yetkisi verir, reddetmek görüntüleyen bırakır.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('request-u1')),
        matching: find.widgetWithText(FilledButton, _en.approve),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('request-u2')),
        matching: find.widgetWithText(TextButton, _en.decline),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.roleChanges, ['u1=editor', 'u2=viewer']);
    expect(find.text(_en.editRequests), findsNothing);
    // Kod yerinde duruyor.
    expectCodeShown('222778');
  });
}
