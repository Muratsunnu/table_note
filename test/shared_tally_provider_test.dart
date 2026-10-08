import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/providers/tally_provider.dart';

Future<TallyProvider> _seeded({String? role}) async {
  SharedPreferences.setMockInitialValues({});
  final provider = TallyProvider();
  while (provider.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  await provider.createTable(
    TallyTableModel(
      tableName: 'çetele1',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 30),
      statuses: [TallyStatus(code: 'v', label: 'Var', colorValue: 0xFF4CAF50)],
      items: [TallyItemModel(name: 'Ahmet')],
    ),
    isPremium: true,
  );
  if (role != null) {
    await provider.setSharedRole(provider.currentTable!.id, role);
  }
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ortak olmayan çetelede kuyruk tutulmaz', () async {
    final provider = await _seeded();
    final id = provider.currentTable!.id;
    await provider.setCellStatus(0, DateTime(2026, 10, 5), 'v');
    expect(provider.pendingChangeCount(id), 0);
  });

  test('işaret koymak kuyruğa düşer, temel önceki değerdir', () async {
    final provider = await _seeded(role: 'editor');
    final id = provider.currentTable!.id;
    final itemId = provider.currentTable!.items.first.id;

    await provider.setCellStatus(0, DateTime(2026, 10, 5), 'v');
    final operation = provider.pendingChanges(id)!.operations.single;
    expect(operation.itemId, itemId);
    expect(operation.days['2026-10-05'], 'v');
    expect(operation.dayBase['2026-10-05'], isNull);
  });

  test('geri alma da kuyruğa düşer, silinmez', () async {
    final provider = await _seeded(role: 'editor');
    final id = provider.currentTable!.id;

    await provider.setCellStatus(0, DateTime(2026, 10, 5), 'v');
    await provider.undoLastEdit();

    // Karşı taraf o arada işareti görmüş olabilir; "hiç olmamış" sayılamaz.
    final operation = provider.pendingChanges(id)!.operations.single;
    expect(operation.days['2026-10-05'], isNull);
    // Temel yine ilk dokunuştan öncesi: boş.
    expect(operation.dayBase['2026-10-05'], isNull);
    expect(provider.currentTable!.items.first.entries['2026-10-05'], isNull);
  });

  test('yeni öğe ve silinmesi kuyruktan tamamen düşer', () async {
    final provider = await _seeded(role: 'editor');
    final id = provider.currentTable!.id;
    await provider.addItem('Mehmet');
    expect(provider.pendingChangeCount(id), 1);
    await provider.removeItem(1);
    expect(provider.pendingChangeCount(id), 0);
  });

  test('buluttaki öğeyi silmek işlem olarak kalır', () async {
    final provider = await _seeded(role: 'editor');
    final id = provider.currentTable!.id;
    await provider.removeItem(0);
    expect(provider.pendingChanges(id)!.operations.single.isDelete, isTrue);
  });

  test('paylaşım kapatılınca kuyruk da gider', () async {
    final provider = await _seeded(role: 'editor');
    final id = provider.currentTable!.id;
    await provider.setCellStatus(0, DateTime(2026, 10, 5), 'v');
    expect(provider.pendingChangeCount(id), 1);
    await provider.setSharedRole(id, null);
    expect(provider.pendingChangeCount(id), 0);
    expect(provider.isSharedTally(id), isFalse);
  });

  test('toplu işaretleme her günü ayrı kaydeder', () async {
    final provider = await _seeded(role: 'editor');
    final id = provider.currentTable!.id;
    await provider.setBulkStatus(
      itemIndices: [0],
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 7),
      statusCode: 'v',
    );
    final operation = provider.pendingChanges(id)!.operations.single;
    expect(operation.days.keys.toList()..sort(), [
      '2026-10-05',
      '2026-10-06',
      '2026-10-07',
    ]);
  });

  test('hesap değişince katılınan çetele kopar, paylaşılan kalır', () async {
    final joined = await _seeded(role: 'editor');
    final joinedId = joined.currentTable!.id;
    await joined.setCellStatus(0, DateTime(2026, 10, 5), 'v');
    expect(joined.pendingChangeCount(joinedId), greaterThan(0));
    expect(joined.hasJoinedTallies, isTrue);
    await joined.clearSharedState(joinedOnly: true);
    expect(joined.isSharedTally(joinedId), isFalse);
    expect(joined.pendingChangeCount(joinedId), 0);
    expect(joined.tables.length, 1);

    final owned = await _seeded(role: 'owner');
    final ownedId = owned.currentTable!.id;
    await owned.clearSharedState(joinedOnly: true);
    expect(owned.isSharedOwner(ownedId), isTrue);
    await owned.clearSharedState();
    expect(owned.isSharedTally(ownedId), isFalse);
  });

  test('görüntüleyen kişi çeteleyi hiçbir yoldan değiştiremez', () async {
    final provider = await _seeded(role: 'viewer');
    final id = provider.currentTable!.id;
    final day = DateTime(2026, 10, 5);
    final before = provider.currentTable!.toJson().toString();

    expect(provider.canEditCurrent, isFalse);
    await provider.cycleCellStatus(0, day);
    await provider.setCellStatus(0, day, 'v');
    await provider.setBulkStatus(
      itemIndices: [0],
      startDate: day,
      endDate: day,
      statusCode: 'v',
    );
    expect(await provider.addItem('Mehmet'), isFalse);
    expect(await provider.renameItem(0, 'Ali'), isFalse);
    expect(await provider.removeItem(0), isFalse);
    await provider.reorderItem(0, 1);

    expect(provider.currentTable!.toJson().toString(), before);
    expect(provider.pendingChangeCount(id), 0);
    expect(provider.canUndo, isFalse);

    // Yetki verilince aynı işlem geçer.
    await provider.setSharedRole(id, 'editor');
    await provider.setCellStatus(0, day, 'v');
    expect(provider.pendingChangeCount(id), 1);
  });
}
