import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/tally_provider.dart';
import 'package:table_note/models/shared_row_operation.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/services/shared_sync_service.dart';
import 'package:table_note/widgets/leave_shared_table.dart';

class _FakeRepository implements CloudRepository {
  final left = <String>[];
  Object? failure;

  /// Ayrılmadan önce gönderilen değişiklikler.
  int sentRows = 0;
  Object? sendFailure;

  @override
  Future<SharedRowSyncResult> applySharedTableRows(
    String tableId,
    List<SharedRowOperation> operations,
  ) async {
    if (sendFailure != null) throw sendFailure!;
    sentRows += operations.length;
    return SharedRowSyncResult(
      revision: 2,
      applied: operations.map((operation) => operation.rowId).toList(),
      conflicts: const [],
    );
  }

  // Servis açık tabloyu izlemeye çalışır; bu testte izlenecek bir şey yok.
  @override
  Stream<int> watchSharedTableRevision(String tableId) => const Stream.empty();

  @override
  Future<SharedTableSnapshot?> fetchSharedTable(String tableId) async => null;

  @override
  Future<SharedAccess> sharedTableAccess(String tableId) async =>
      const SharedAccess(role: 'editor');

  @override
  Future<void> leaveSharedTable(String tableId) async {
    if (failure != null) throw failure!;
    left.add(tableId);
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

  Future<void> seed(WidgetTester tester, {bool pending = false}) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      tables = TableProvider();
      tallies = TallyProvider();
      while (tables.isLoading || tallies.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tables.createTable('seferler', [ColumnModel(name: 'nereden')]);
      await tables.setSharedRole(tables.currentTable!.id, 'editor');
      if (pending) await tables.addRow(['konya']);
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
      await tallies.setSharedRole(tallies.currentTable!.id, 'viewer');
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

  Widget app({required bool isTally}) => MultiProvider(
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
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => leaveSharedTableFlow(
                context,
                tableId: isTally
                    ? tallies.currentTable!.id
                    : tables.currentTable!.id,
                tableName: isTally ? 'yoklama' : 'seferler',
                isTally: isTally,
                repository: repository,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> leave(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('leave-confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('leaving removes the membership and then the local table', (
    tester,
  ) async {
    await seed(tester);
    final id = tables.currentTable!.id;
    await tester.pumpWidget(app(isTally: false));
    await tester.pumpAndSettle();
    await leave(tester);

    expect(repository.left, [id]);
    expect(tables.tables, isEmpty);
    // Silinen tablo "katılınmış tablo var" diye görünmeye devam etmemeli.
    expect(tables.isSharedTable(id), isFalse);
    expect(tables.hasJoinedTables, isFalse);
    expect(find.text(_en.leftShared('seferler')), findsOneWidget);
  });

  testWidgets('a tally is left through the tally provider', (tester) async {
    await seed(tester);
    final id = tallies.currentTable!.id;
    await tester.pumpWidget(app(isTally: true));
    await tester.pumpAndSettle();
    await leave(tester);

    expect(repository.left, [id]);
    expect(tallies.tables, isEmpty);
    expect(tallies.hasJoinedTallies, isFalse);
    // Tablo tarafına dokunulmadı.
    expect(tables.tables.length, 1);
  });

  testWidgets('if the server cannot be reached nothing is removed', (
    tester,
  ) async {
    // Üyelik silinemeden tablo cihazdan kaldırılsaydı kişi sahibin
    // listesinde kalır ama tablosunu göremezdi.
    await seed(tester);
    final id = tables.currentTable!.id;
    repository.failure = StateError('ağ yok');
    await tester.pumpWidget(app(isTally: false));
    await tester.pumpAndSettle();
    await leave(tester);

    expect(find.text(_en.sharedTableError('unknown')), findsOneWidget);
    expect(tables.tables.length, 1);
    expect(tables.sharedRole(id), 'editor');
    // Pencere açık kalır; yeniden denenebilir ya da vazgeçilebilir.
    expect(find.byKey(const ValueKey('leave-confirm')), findsOneWidget);
  });

  testWidgets('unsent changes are sent before leaving, not thrown away', (
    tester,
  ) async {
    await seed(tester, pending: true);
    final id = tables.currentTable!.id;
    await tester.pumpWidget(app(isTally: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    // Ne olacağı ayrılmadan önce yazıyor.
    expect(find.text(_en.leavePendingWillSend(1)), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('leave-confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();

    expect(repository.sentRows, 1);
    expect(repository.left, [id]);
    expect(tables.tables, isEmpty);
  });

  testWidgets('if sending fails the user decides whether to leave anyway', (
    tester,
  ) async {
    await seed(tester, pending: true);
    final id = tables.currentTable!.id;
    repository.sendFailure = const SharedTableException(
      'shared_table_edit_access_required',
    );
    await tester.pumpWidget(app(isTally: false));
    await tester.pumpAndSettle();
    await leave(tester);

    // Gönderilemedi: hiçbir şey silinmedi, kişiye soruluyor.
    expect(find.text(_en.leaveSendFailed), findsOneWidget);
    expect(repository.left, isEmpty);
    expect(tables.tables.length, 1);
    expect(tables.pendingChangeCount(id), 1);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, _en.leaveAnyway));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(repository.left, [id]);
    expect(tables.tables, isEmpty);
  });
}
