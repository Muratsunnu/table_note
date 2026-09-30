import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/shared_row_operation.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/services/shared_sync_service.dart';

/// Sunucu yerine geçen sahte depo: ne gönderildiğini kaydeder, ne döneceğini
/// test belirler.
class _FakeRepository implements CloudRepository {
  final List<List<SharedRowOperation>> sent = [];
  SharedRowSyncResult Function(List<SharedRowOperation>)? responder;
  Object? throwThis;

  /// Sunucuda duran hal. null ise tablo yok sayilir.
  SharedTableSnapshot? snapshot;
  int fetchCount = 0;

  @override
  Future<SharedTableSnapshot?> fetchSharedTable(String tableId) async {
    fetchCount++;
    return snapshot;
  }

  @override
  Future<SharedRowSyncResult> applySharedTableRows(
    String tableId,
    List<SharedRowOperation> operations,
  ) async {
    sent.add(operations);
    if (throwThis != null) throw throwThis!;
    return responder?.call(operations) ??
        SharedRowSyncResult(
          revision: 2,
          applied: operations.map((op) => op.rowId).toList(),
          conflicts: const [],
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<TableProvider> _seeded(String role) async {
  SharedPreferences.setMockInitialValues({});
  final provider = TableProvider();
  while (provider.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  await provider.createTable('seferler', [
    ColumnModel(name: 'nereden'),
    ColumnModel(name: 'kilosu', isNumeric: true),
  ]);
  await provider.addRow(['konya', '35000']);
  await provider.setSharedRole(provider.currentTable!.id, role);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('indirme sunucudaki hali yerele alir', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(tables: tables, repository: repository);
    addTearDown(sync.dispose);
    final table = tables.currentTable!;
    final rowId = table.rowIdAt(0)!;

    // Karsi taraf ayni satiri degistirmis.
    final server = TableModel.fromJson(table.toJson());
    server.replaceRow(0, ['ankara', '35000']);
    repository.snapshot = SharedTableSnapshot(
      revision: 7,
      payload: server.toJson(),
    );

    await sync.pull(table.id);
    expect(tables.currentTable!.rows.single, ['ankara', '35000']);
    // Satir kimlikleri korunmali; yoksa bekleyen islemler eslesemez.
    expect(tables.currentTable!.rowIdAt(0), rowId);

    // Ayni surum yeniden indirilmez.
    await sync.pull(table.id);
    expect(repository.fetchCount, 2);
  });

  test('bekleyen değişiklik varken indirme yapılmaz', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(tables: tables, repository: repository);
    addTearDown(sync.dispose);
    final table = tables.currentTable!;

    final server = TableModel.fromJson(table.toJson());
    server.replaceRow(0, ['ankara', '35000']);
    repository.snapshot = SharedTableSnapshot(
      revision: 7,
      payload: server.toJson(),
    );

    // Henuz gonderilmemis yerel duzenleme.
    await tables.updateRow(0, ['konya', '99000']);
    await sync.pull(table.id);

    // Gonderilmemis duzenlemenin sunucunun eski haliyle ezilmesi veri
    // kaybidir; indirme hic istek bile atmamali.
    expect(repository.fetchCount, 0);
    expect(tables.currentTable!.rows.single, ['konya', '99000']);
    expect(tables.pendingChangeCount(table.id), 1);
  });

  test('katılanın değişikliği kendiliğinden gitmez, butonla gider', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(tables: tables, repository: repository);
    addTearDown(sync.dispose);
    final id = tables.currentTable!.id;

    await tables.updateRow(0, ['konya', '40000']);
    // A joiner's half-finished edit must not drip onto everyone's screen.
    await Future<void>.delayed(SharedSyncService.ownerDebounce * 2);
    expect(repository.sent, isEmpty);

    expect(await sync.push(id), isTrue);
    expect(repository.sent.single.single.values, ['konya', '40000']);
    expect(tables.pendingChangeCount(id), 0);
  });

  test('sahibin değişikliği gecikmeyle kendiliğinden gider', () async {
    final tables = await _seeded('owner');
    final repository = _FakeRepository();
    final sync = SharedSyncService(tables: tables, repository: repository);
    addTearDown(sync.dispose);

    await tables.updateRow(0, ['konya', '40000']);
    await Future<void>.delayed(SharedSyncService.ownerDebounce * 2);

    expect(repository.sent, hasLength(1));
    expect(tables.pendingChangeCount(tables.currentTable!.id), 0);
  });

  test('art arda düzenleme tek istek üretir', () async {
    final tables = await _seeded('owner');
    final repository = _FakeRepository();
    final sync = SharedSyncService(tables: tables, repository: repository);
    addTearDown(sync.dispose);

    await tables.updateRow(0, ['konya', '40000']);
    await tables.updateRow(0, ['konya', '45000']);
    await tables.updateRow(0, ['konya', '50000']);
    await Future<void>.delayed(SharedSyncService.ownerDebounce * 2);

    expect(repository.sent, hasLength(1));
    expect(repository.sent.single.single.values, ['konya', '50000']);
  });

  test('çakışan satır kuyrukta kalır ve ekrana taşınır', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(tables: tables, repository: repository);
    addTearDown(sync.dispose);
    final id = tables.currentTable!.id;
    final rowId = tables.currentTable!.rowIds.first;

    repository.responder = (operations) => SharedRowSyncResult(
      revision: 3,
      applied: const [],
      conflicts: [
        SharedRowConflict(
          rowId: rowId,
          reason: 'changed',
          current: const ['konya', '99999'],
        ),
      ],
    );

    await tables.updateRow(0, ['konya', '40000']);
    expect(await sync.push(id), isFalse);
    expect(sync.stateFor(id).hasConflicts, isTrue);
    // Nothing was applied, so the change must stay queued.
    expect(tables.pendingChangeCount(id), 1);
  });

  test('"kayıttaki kalsın" yerel satırı sunucununkiyle değiştirir', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(tables: tables, repository: repository);
    addTearDown(sync.dispose);
    final id = tables.currentTable!.id;
    final rowId = tables.currentTable!.rowIds.first;

    await tables.updateRow(0, ['konya', '40000']);
    await sync.keepServerVersion(
      id,
      SharedRowConflict(
        rowId: rowId,
        reason: 'changed',
        current: const ['konya', '99999'],
      ),
    );

    expect(tables.currentTable!.rows.first, ['konya', '99999']);
    expect(tables.pendingChangeCount(id), 0);
  });

  test(
    '"benimki kalsın" temeli değiştirir, değişiklik kuyrukta kalır',
    () async {
      final tables = await _seeded('editor');
      final repository = _FakeRepository();
      final sync = SharedSyncService(tables: tables, repository: repository);
      addTearDown(sync.dispose);
      final id = tables.currentTable!.id;
      final rowId = tables.currentTable!.rowIds.first;

      await tables.updateRow(0, ['konya', '40000']);
      await sync.keepLocalVersion(
        id,
        SharedRowConflict(
          rowId: rowId,
          reason: 'changed',
          current: const ['konya', '99999'],
        ),
      );

      final operation = tables.pendingChanges(id)!.operations.single;
      expect(operation.values, ['konya', '40000']);
      // Rebased onto what the server has now, so the next push goes through.
      expect(operation.base, ['konya', '99999']);
    },
  );

  test('sunucu hatası koda çevrilir, değişiklik kaybolmaz', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository()
      ..throwThis = const SharedTableException('owner_premium_required');
    final sync = SharedSyncService(tables: tables, repository: repository);
    addTearDown(sync.dispose);
    final id = tables.currentTable!.id;

    await tables.updateRow(0, ['konya', '40000']);
    expect(await sync.push(id), isFalse);
    expect(sync.stateFor(id).errorCode, 'owner_premium_required');
    expect(tables.pendingChangeCount(id), 1);
  });
}
