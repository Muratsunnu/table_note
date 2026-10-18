import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/shared_row_operation.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/services/storage_service.dart';

void main() {
  _persistenceTests();
  test('aynı satırın beş düzenlemesi tek işleme iner', () {
    final pending = PendingRowChanges();
    pending.recordUpsert('r1', ['a'], base: ['x']);
    pending.recordUpsert('r1', ['b'], base: ['a']);
    pending.recordUpsert('r1', ['c'], base: ['b']);

    expect(pending.length, 1);
    final operation = pending.operations.single;
    expect(operation.values, ['c']);
    // The base must stay what the cloud last had, not an intermediate step of
    // the user's own; otherwise a conflict would go unnoticed.
    expect(operation.base, ['x']);
  });

  test('yerelde eklenip yerelde silinen satır hiç gönderilmez', () {
    final pending = PendingRowChanges();
    pending.recordUpsert('new', ['a']); // base yok: bulutta hiç olmadı
    expect(pending.length, 1);

    pending.recordDelete('new');
    expect(pending.isEmpty, isTrue);
  });

  test('bulutta var olan satırın silinmesi base ile gönderilir', () {
    final pending = PendingRowChanges();
    pending.recordUpsert('r1', ['b'], base: ['a']);
    pending.recordDelete('r1');

    final operation = pending.operations.single;
    expect(operation.isDelete, isTrue);
    expect(operation.base, ['a']);
    expect(operation.toJson()['op'], 'delete');
  });

  test('yeni satırda base null gider', () {
    final pending = PendingRowChanges();
    pending.recordUpsert('new', ['a', 'b']);
    final json = pending.operations.single.toJson();
    expect(json['base'], isNull);
    expect(json['values'], ['a', 'b']);
    expect(pending.operations.single.isNew, isTrue);
  });

  test('uygulananlar düşer, çakışanlar kuyrukta kalır', () {
    final pending = PendingRowChanges();
    pending.recordUpsert('r1', ['a'], base: ['x']);
    pending.recordUpsert('r2', ['b'], base: ['y']);
    pending.recordUpsert('r3', ['c'], base: ['z']);

    pending.clearApplied(['r1', 'r3']);
    expect(pending.length, 1);
    expect(pending.contains('r2'), isTrue);
  });

  test('bekleyenler kayıt/okuma turunu atlatır', () {
    final pending = PendingRowChanges();
    pending.recordUpsert('r1', ['a'], base: ['x']);
    pending.recordDelete('r2', base: ['y']);
    pending.recordUpsert('r3', ['new']);

    // Offline edits have to survive an app restart.
    final restored = PendingRowChanges.fromJson(
      jsonDecode(jsonEncode(pending.toJson())),
    );
    expect(restored.length, 3);
    expect(restored.operations.firstWhere((o) => o.rowId == 'r1').base, ['x']);
    expect(
      restored.operations.firstWhere((o) => o.rowId == 'r2').isDelete,
      isTrue,
    );
    expect(
      restored.operations.firstWhere((o) => o.rowId == 'r3').isNew,
      isTrue,
    );
  });

  test('bozuk kayıt çökertmez', () {
    expect(PendingRowChanges.fromJson(null).isEmpty, isTrue);
    expect(PendingRowChanges.fromJson('bozuk').isEmpty, isTrue);
    expect(
      PendingRowChanges.fromJson([
        {'op': 'upsert'},
        {'rowId': '', 'op': 'upsert'},
      ]).isEmpty,
      isTrue,
    );
  });
}

void _persistenceTests() {
  test('bekleyen değişiklikler diske yazılır ve geri okunur', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final pending = PendingRowChanges();
    pending.recordUpsert('r1', ['a'], base: ['x']);
    expect(await StorageService.savePendingRowChanges({'t1': pending}), isTrue);

    final loaded = await StorageService.loadPendingRowChanges();
    expect(loaded['t1']!.operations.single.base, ['x']);

    // Kuyruk boşalınca kayıt da silinir, boş girdi birikmez.
    pending.clear();
    await StorageService.savePendingRowChanges({'t1': pending});
    expect(await StorageService.loadPendingRowChanges(), isEmpty);
  });

  test('sunucu yanıtı uygulanan ve çakışanlara ayrılır', () {
    final result = SharedRowSyncResult.fromJson({
      'revision': 7,
      'applied': ['r1', 'r3'],
      'conflicts': [
        {
          'rowId': 'r2',
          'reason': 'changed',
          'current': ['güncel'],
        },
        {'rowId': 'r4', 'reason': 'deleted', 'current': null},
      ],
    });
    expect(result.revision, 7);
    expect(result.applied, ['r1', 'r3']);
    expect(result.hasConflicts, isTrue);
    expect(result.conflicts.first.current, ['güncel']);
    // A row deleted by someone else has no current value to show.
    expect(result.conflicts.last.reason, 'deleted');
    expect(result.conflicts.last.current, isNull);
  });
}
