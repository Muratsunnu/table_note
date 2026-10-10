import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/tally_provider.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/services/shared_sync_service.dart';
import 'package:table_note/widgets/edit_access.dart';

class _FakeRepository implements CloudRepository {
  int requests = 0;
  Object? failure;

  @override
  Future<SharedAccess> requestSharedEditAccess(String tableId) async {
    requests++;
    if (failure != null) throw failure!;
    return const SharedAccess(role: 'viewer', editRequested: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _en = AppLocalizations(const Locale('en'));

void main() {
  late TableProvider tables;
  late TallyProvider tallies;
  late _FakeRepository repository;
  late SharedSyncService sync;

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      tables = TableProvider();
      tallies = TallyProvider();
      while (tables.isLoading || tallies.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tables.createTable('seferler', [ColumnModel(name: 'nereden')]);
      await tables.setSharedRole(tables.currentTable!.id, 'viewer');
    });
    repository = _FakeRepository();
    sync = SharedSyncService(
      tables: tables,
      tallies: tallies,
      repository: repository,
    );
    addTearDown(() {
      sync.dispose();
      tables.dispose();
      tallies.dispose();
    });
  }

  Widget app() => MultiProvider(
    providers: [
      ChangeNotifierProvider<TableProvider>.value(value: tables),
      ChangeNotifierProvider<TallyProvider>.value(value: tallies),
      ChangeNotifierProvider<SharedSyncService>.value(value: sync),
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
        body: Center(
          child: RequestEditAccessButton(tableId: tables.currentTable!.id),
        ),
      ),
    ),
  );

  final button = find.byKey(const ValueKey('request-edit-access'));
  final confirm = find.byKey(const ValueKey('request-edit-access-confirm'));

  testWidgets('the request is sent only after the user confirms', (
    tester,
  ) async {
    await seed(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text(_en.requestEditAccess), findsOneWidget);

    // Vazgeçen kişi adına talep gitmez.
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(_en.requestEditAccessMessage), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, _en.cancel));
    await tester.pumpAndSettle();
    expect(repository.requests, 0);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repository.requests, 1);
    expect(find.text(_en.editAccessRequestSent), findsOneWidget);

    // Yanıt beklerken düğme bunu söyler ve yeniden basılamaz.
    expect(find.text(_en.editAccessRequested), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('a refused request says why and can be tried again', (
    tester,
  ) async {
    await seed(tester);
    repository.failure = const SharedTableException('too_many_attempts');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(
      find.text(_en.sharedTableError('too_many_attempts')),
      findsOneWidget,
    );
    expect(find.text(_en.requestEditAccess), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });
}
