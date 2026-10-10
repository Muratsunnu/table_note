import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/shared_row_operation.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/tally_provider.dart';
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

  /// Canli yayin yerine gecen akis; testi surum olayini kendi uretir.
  final live = StreamController<int>.broadcast();

  /// Gonderilen sutun yapilari.
  final List<List<Map<String, dynamic>>> sentColumns = [];

  /// Sunucunun bu cihaz icin soyledigi yetki. null ise soru hata verir.
  SharedAccess? access;
  int accessReads = 0;
  Object? requestFailure;
  int requests = 0;

  @override
  Future<SharedAccess> sharedTableAccess(String tableId) async {
    accessReads++;
    if (access == null) throw StateError('yetki okunamadi');
    return access!;
  }

  @override
  Future<SharedAccess> requestSharedEditAccess(String tableId) async {
    requests++;
    if (requestFailure != null) throw requestFailure!;
    return access = const SharedAccess(role: 'viewer', editRequested: true);
  }

  @override
  Future<SharedRowSyncResult> applySharedTableColumns({
    required String tableId,
    required String name,
    required List<Map<String, dynamic>> columns,
  }) async {
    sentColumns.add(columns);
    return const SharedRowSyncResult(revision: 5, applied: [], conflicts: []);
  }

  @override
  Stream<int> watchSharedTableRevision(String tableId) => live.stream;

  @override
  Future<SharedTableSnapshot?> fetchSharedTable(String tableId) async {
    fetchCount++;
    return snapshot;
  }

  /// Yalnizca surum soran ucuz istekler.
  int versionChecks = 0;

  @override
  Future<SharedTableVersion?> fetchSharedTableVersion(String tableId) async {
    versionChecks++;
    final current = snapshot;
    return current == null
        ? null
        : SharedTableVersion(
            revision: current.revision,
            updatedAt: current.updatedAt,
          );
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

/// Testler yalnizca tablo yolunu deniyor; servis yine de bir cetele
/// saglayicisi istiyor.
Future<TallyProvider> _emptyTallies() async {
  final provider = TallyProvider();
  while (provider.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return provider;
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

  test('canlı yayın sürüm artınca indirmeyi tetikler', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    addTearDown(sync.dispose);
    addTearDown(repository.live.close);
    final table = tables.currentTable!;

    // Servis acik tabloya abone olsun diye bir bildirim uretilir.
    tables.notifyListeners();
    await Future<void>.delayed(Duration.zero);

    final server = TableModel.fromJson(table.toJson());
    server.replaceRow(0, ['ankara', '35000']);
    repository.snapshot = SharedTableSnapshot(
      revision: 9,
      payload: server.toJson(),
    );

    // Karsi taraf kaydetti: sunucu yeni surumu yayinlar.
    repository.live.add(9);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Kullanici hicbir sey yapmadan ekrandaki satir guncellenmis olmali.
    expect(tables.currentTable!.rows.single, ['ankara', '35000']);
  });

  test('sahip sütun eklerse yapı kendiliğinden gider', () async {
    final tables = await _seeded('owner');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    addTearDown(sync.dispose);
    final table = tables.currentTable!;

    // Imza sunucudan indirilen yukla kurulur; yoksa her açılışta yapı
    // boşuna yeniden gönderilirdi.
    repository.snapshot = SharedTableSnapshot(
      revision: 3,
      payload: table.toJson(),
    );
    await sync.pull(table.id);
    expect(repository.sentColumns, isEmpty);

    await tables.updateTableStructure('seferler', [
      ...table.columns.map((column) => column.copyWith()),
      ColumnModel(name: 'notlar'),
    ], table.columns.length);
    await Future<void>.delayed(SharedSyncService.ownerDebounce * 2);

    expect(repository.sentColumns.single.length, 3);
    expect(repository.sentColumns.single.last['name'], 'notlar');
  });

  test('yapı değişmediyse tekrar gönderilmez', () async {
    final tables = await _seeded('owner');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    addTearDown(sync.dispose);
    final table = tables.currentTable!;
    repository.snapshot = SharedTableSnapshot(
      revision: 3,
      payload: table.toJson(),
    );
    await sync.pull(table.id);

    // Satır düzenlemek yapıya dokunmaz.
    await tables.updateRow(0, ['ankara', '40000']);
    await Future<void>.delayed(SharedSyncService.ownerDebounce * 2);
    expect(repository.sentColumns, isEmpty);
  });

  test('indirme sunucudaki hali yerele alir', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
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

    // Ayni surum yeniden indirilmez; yalnizca surumu sorulur.
    await sync.pull(table.id);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(repository.fetchCount, 1);
    expect(repository.versionChecks, greaterThan(0));
  });

  test('bekleyen değişiklik varken indirme yapılmaz', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
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

  test('katılanın değişikliği de kendiliğinden gider', () async {
    // Eskiden butona basana kadar beklerdi; o sırada başkası aynı satırı
    // eklerse karışıklık çıkıyordu.
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    addTearDown(sync.dispose);
    final id = tables.currentTable!.id;

    await tables.updateRow(0, ['konya', '40000']);
    // Sahibinkinden uzun bir toplama süresi var; o dolmadan gitmez.
    await Future<void>.delayed(SharedSyncService.ownerDebounce);
    expect(repository.sent, isEmpty);

    await Future<void>.delayed(SharedSyncService.editorDebounce);
    expect(repository.sent.single.single.values, ['konya', '40000']);
    expect(tables.pendingChangeCount(id), 0);
  });

  test('katılanın art arda düzenlemeleri tek istekte toplanır', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    addTearDown(sync.dispose);

    await tables.updateRow(0, ['konya', '40000']);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await tables.addRow(['izmir', '12000']);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await tables.updateRow(0, ['konya', '50000']);
    await Future<void>.delayed(SharedSyncService.editorDebounce * 1.5);

    // Her gönderim, tabloyu açık tutan herkese bir indirme yaptırır.
    expect(repository.sent, hasLength(1));
    expect(repository.sent.single, hasLength(2));
  });

  test('görüntüleyen kişinin kuyruğu kendiliğinden gönderilmez', () async {
    // Yetkisi alınmış birinin elinde gönderilmemiş değişiklik kalabilir.
    // Sunucu bunu zaten reddeder; boşuna denenmez.
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    addTearDown(sync.dispose);
    final id = tables.currentTable!.id;

    await tables.updateRow(0, ['konya', '40000']);
    await tables.setSharedRole(id, 'viewer');
    await Future<void>.delayed(SharedSyncService.editorDebounce * 1.5);

    expect(repository.sent, isEmpty);
    expect(tables.pendingChangeCount(id), 1);
  });

  test('çözülmemiş çakışma tekrar tekrar gönderilmez', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
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
          current: const ['ankara', '35000'],
        ),
      ],
    );

    await tables.updateRow(0, ['konya', '40000']);
    await Future<void>.delayed(SharedSyncService.editorDebounce * 3);
    // Reddedilen içerik değişmedi; aynı isteği yinelemek yalnızca masraf.
    expect(repository.sent, hasLength(1));
    expect(sync.stateFor(id).hasConflicts, isTrue);

    // Kullanıcı karar verince yeniden gönderilir.
    repository.responder = null;
    await sync.keepLocalVersion(id, sync.stateFor(id).conflicts.single);
    await Future<void>.delayed(SharedSyncService.editorDebounce * 1.5);
    expect(repository.sent, hasLength(2));
    expect(tables.pendingChangeCount(id), 0);
  });

  test(
    'uygulama arka plana geçerken bekleyen değişiklik hemen gider',
    () async {
      final tables = await _seeded('editor');
      final repository = _FakeRepository();
      final sync = SharedSyncService(
        tables: tables,
        tallies: await _emptyTallies(),
        repository: repository,
      );
      addTearDown(sync.dispose);

      await tables.updateRow(0, ['konya', '40000']);
      // Sayaç dolmadan uygulama kapatılıyor.
      sync.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repository.sent, hasLength(1));
    },
  );

  test(
    'değişmemiş tablo yeniden indirilmez, yalnızca sürümü sorulur',
    () async {
      final tables = await _seeded('editor');
      final repository = _FakeRepository();
      final sync = SharedSyncService(
        tables: tables,
        tallies: await _emptyTallies(),
        repository: repository,
      );
      addTearDown(sync.dispose);
      final table = tables.currentTable!;
      repository.snapshot = SharedTableSnapshot(
        revision: 5,
        payload: table.toJson(),
        updatedAt: '2026-10-09T10:00:00Z',
      );

      // Servis arka planda da soru sorabildiği için sayımlar durulduktan
      // sonra, bir öncekine göre karşılaştırılır.
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 30));

      // İlk seferde sürüm bilinmiyor; tablo indirilir.
      await sync.pull(table.id);
      await settle();
      expect(repository.fetchCount, 1);
      final checks = repository.versionChecks;

      // Tablo yeniden açıldı, uygulama öne geldi: yalnızca ucuz soru gider.
      await sync.pull(table.id);
      await settle();
      await sync.pull(table.id);
      await settle();
      expect(repository.fetchCount, 1);
      expect(repository.versionChecks, greaterThanOrEqualTo(checks + 2));

      // Sürüm aynı ama içerik değişmiş (paylaşım kapalıyken yedeklenmiş):
      // değişiklik anı farklıdır, tablo indirilir.
      final server = TableModel.fromJson(table.toJson());
      server.replaceRow(0, ['ankara', '35000']);
      repository.snapshot = SharedTableSnapshot(
        revision: 5,
        payload: server.toJson(),
        updatedAt: '2026-10-09T11:00:00Z',
      );
      await sync.pull(table.id);
      await settle();
      expect(repository.fetchCount, 2);
      expect(tables.currentTable!.rows.single, ['ankara', '35000']);
    },
  );

  test('bilinen sürüm uygulama yeniden açılınca hatırlanır', () async {
    final tables = await _seeded('editor');
    final repository = _FakeRepository();
    final first = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    final table = tables.currentTable!;
    repository.snapshot = SharedTableSnapshot(
      revision: 5,
      payload: table.toJson(),
      updatedAt: '2026-10-09T10:00:00Z',
    );
    await first.pull(table.id);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    first.dispose();
    expect(repository.fetchCount, 1);
    final checks = repository.versionChecks;

    // Uygulama kapanıp açıldı: her açılışta tablonun tamamı inmemeli.
    final second = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    addTearDown(second.dispose);
    await second.pull(table.id);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(repository.fetchCount, 1);
    expect(repository.versionChecks, greaterThan(checks));
  });

  test('sahibin değişikliği gecikmeyle kendiliğinden gider', () async {
    final tables = await _seeded('owner');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    addTearDown(sync.dispose);

    await tables.updateRow(0, ['konya', '40000']);
    await Future<void>.delayed(SharedSyncService.ownerDebounce * 2);

    expect(repository.sent, hasLength(1));
    expect(tables.pendingChangeCount(tables.currentTable!.id), 0);
  });

  test('art arda düzenleme tek istek üretir', () async {
    final tables = await _seeded('owner');
    final repository = _FakeRepository();
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
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
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
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
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
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
      final sync = SharedSyncService(
        tables: tables,
        tallies: await _emptyTallies(),
        repository: repository,
      );
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
    final sync = SharedSyncService(
      tables: tables,
      tallies: await _emptyTallies(),
      repository: repository,
    );
    addTearDown(sync.dispose);
    final id = tables.currentTable!.id;

    await tables.updateRow(0, ['konya', '40000']);
    expect(await sync.push(id), isFalse);
    expect(sync.stateFor(id).errorCode, 'owner_premium_required');
    expect(tables.pendingChangeCount(id), 1);
  });

  group('roller', () {
    Future<(TableProvider, _FakeRepository, SharedSyncService)> setup(
      String role,
    ) async {
      final tables = await _seeded(role);
      final repository = _FakeRepository();
      final sync = SharedSyncService(
        tables: tables,
        tallies: await _emptyTallies(),
        repository: repository,
      );
      addTearDown(sync.dispose);
      addTearDown(repository.live.close);
      return (tables, repository, sync);
    }

    test('sahip yetkiyi geri alınca düzenleyen görüntüleyene döner', () async {
      final (tables, repository, sync) = await setup('editor');
      final id = tables.currentTable!.id;
      repository.access = const SharedAccess(role: 'viewer');

      await sync.refreshAccess(id);
      expect(tables.isSharedViewer(id), isTrue);
      expect(tables.canEditCurrent, isFalse);
      // Artık eklenemez; sunucu da zaten reddederdi.
      expect(await tables.addRow(['izmir', '12000']), isFalse);
    });

    test('sahip onaylayınca görüntüleyen düzenleyebilir', () async {
      final (tables, repository, sync) = await setup('viewer');
      final id = tables.currentTable!.id;
      expect(await tables.addRow(['izmir', '12000']), isFalse);

      repository.access = const SharedAccess(role: 'editor');
      // Sahip rolü değiştirdiğinde sürüm artar; ekran bunu canlı duyar.
      tables.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      repository.live.add(4);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(tables.sharedRole(id), 'editor');
      expect(await tables.addRow(['izmir', '12000']), isTrue);
    });

    test('sunucunun yanıtı sahipliği ya da üyeliği yerelde silmez', () async {
      final (tables, repository, sync) = await setup('owner');
      final id = tables.currentTable!.id;
      // Yanlış okunan tek bir yanıt tabloyu bulutla bağlantısız bırakmamalı.
      for (final role in ['viewer', 'editor', null]) {
        repository.access = SharedAccess(role: role);
        await sync.refreshAccess(id);
        expect(tables.isSharedOwner(id), isTrue, reason: '$role');
      }
    });

    test('sahip bekleyen talep sayısını görür', () async {
      final (tables, repository, sync) = await setup('owner');
      final id = tables.currentTable!.id;
      expect(sync.accessFor(id).pendingRequests, 0);
      repository.access = const SharedAccess(role: 'owner', pendingRequests: 2);
      await sync.refreshAccess(id);
      expect(sync.accessFor(id).pendingRequests, 2);
    });

    test('yetki okunamazsa eldeki rol geçerli kalır', () async {
      final (tables, repository, sync) = await setup('editor');
      final id = tables.currentTable!.id;
      repository.access = null;
      await sync.refreshAccess(id);
      expect(tables.sharedRole(id), 'editor');
    });

    test('yetki talebi gönderilir ve yanıt beklediği bilinir', () async {
      final (tables, repository, sync) = await setup('viewer');
      final id = tables.currentTable!.id;
      expect(sync.accessFor(id).editRequested, isFalse);

      expect(await sync.requestEditAccess(id), isNull);
      expect(repository.requests, 1);
      expect(sync.accessFor(id).editRequested, isTrue);
      // Talep göndermek yetki vermez.
      expect(tables.isSharedViewer(id), isTrue);
    });

    test('reddedilen talebin nedeni koda çevrilir', () async {
      final (tables, repository, sync) = await setup('viewer');
      final id = tables.currentTable!.id;
      repository.requestFailure = const SharedTableException(
        'too_many_attempts',
      );
      expect(await sync.requestEditAccess(id), 'too_many_attempts');
      expect(sync.accessFor(id).editRequested, isFalse);
    });

    test('yetkisi alınan kişinin gönderemediği değişiklik silinmez', () async {
      final (tables, repository, sync) = await setup('editor');
      final id = tables.currentTable!.id;
      await tables.addRow(['izmir', '12000']);
      expect(tables.pendingChangeCount(id), 1);

      repository
        ..throwThis = const SharedTableException(
          'shared_table_edit_access_required',
        )
        ..access = const SharedAccess(role: 'viewer');
      expect(await sync.push(id), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Rol güncellendi ama emek yerinde: yetki geri verilirse gönderilir.
      expect(tables.isSharedViewer(id), isTrue);
      expect(tables.pendingChangeCount(id), 1);
      expect(tables.currentTable!.rows.length, 2);
    });
  });
}
