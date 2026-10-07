import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';

Future<TableProvider> _seeded({bool shared = true}) async {
  SharedPreferences.setMockInitialValues({});
  final provider = TableProvider();
  while (provider.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(
    await provider.createTable('seferler', [
      ColumnModel(name: 'nereden'),
      ColumnModel(name: 'kilosu', isNumeric: true),
    ]),
    isTrue,
  );
  expect(await provider.addRow(['konya', '35000']), isTrue);
  if (shared) {
    await provider.setSharedRole(provider.currentTable!.id, 'editor');
  }
  return provider;
}

String _tableId(TableProvider provider) => provider.currentTable!.id;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ortak olmayan tabloda kuyruk hiç dolmaz', () async {
    final provider = await _seeded(shared: false);
    await provider.addRow(['izmir', '12000']);
    await provider.updateRow(0, ['konya', '40000']);
    await provider.deleteRow(0);
    expect(provider.pendingChangeCount(_tableId(provider)), 0);
  });

  test('eklenen satır yeni olarak kuyruğa girer', () async {
    final provider = await _seeded();
    await provider.addRow(['izmir', '12000']);

    final pending = provider.pendingChanges(_tableId(provider))!;
    expect(pending.length, 1);
    expect(pending.operations.single.isNew, isTrue);
    expect(pending.operations.single.values, ['izmir', '12000']);
  });

  test('güncellemede base, değişiklikten önceki değerdir', () async {
    final provider = await _seeded();
    await provider.updateRow(0, ['konya', '40000']);

    final operation = provider
        .pendingChanges(_tableId(provider))!
        .operations
        .single;
    expect(operation.values, ['konya', '40000']);
    // The cloud must be told what this device saw before it touched the row.
    expect(operation.base, ['konya', '35000']);
  });

  test('art arda düzenlemede base ilk değerde kalır', () async {
    final provider = await _seeded();
    await provider.updateRow(0, ['konya', '40000']);
    await provider.updateRow(0, ['konya', '45000']);

    final operation = provider
        .pendingChanges(_tableId(provider))!
        .operations
        .single;
    expect(operation.values, ['konya', '45000']);
    expect(operation.base, ['konya', '35000']);
  });

  test('silmede base, silinmeden önceki satırdır', () async {
    final provider = await _seeded();
    await provider.deleteRow(0);

    final operation = provider
        .pendingChanges(_tableId(provider))!
        .operations
        .single;
    expect(operation.isDelete, isTrue);
    expect(operation.base, ['konya', '35000']);
  });

  test('uygulananlar kuyruktan düşer', () async {
    final provider = await _seeded();
    await provider.addRow(['izmir', '12000']);
    final rowId = provider.currentTable!.rowIds.last;

    await provider.markChangesApplied(_tableId(provider), [rowId]);
    expect(provider.pendingChangeCount(_tableId(provider)), 0);
  });

  test('paylaşım kapatılınca bekleyenler de düşer', () async {
    final provider = await _seeded();
    await provider.addRow(['izmir', '12000']);
    expect(provider.pendingChangeCount(_tableId(provider)), 1);

    await provider.setSharedRole(_tableId(provider), null);
    expect(provider.isSharedTable(_tableId(provider)), isFalse);
    expect(provider.pendingChangeCount(_tableId(provider)), 0);
  });

  test('rol ve kuyruk uygulama yeniden açılınca geri gelir', () async {
    final provider = await _seeded();
    final id = _tableId(provider);
    await provider.addRow(['izmir', '12000']);

    final reopened = TableProvider();
    while (reopened.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(reopened.sharedRole(id), 'editor');
    expect(reopened.pendingChangeCount(id), 1);
  });

  test('misafir hesaba geçince yalnızca katılınan tablolar kopar', () async {
    final provider = await _seeded();
    final joined = _tableId(provider);
    await provider.addRow(['izmir', '12000']);
    expect(provider.pendingChangeCount(joined), greaterThan(0));
    expect(provider.hasJoinedTables, isTrue);

    expect(
      await provider.createTable('benim', [
        ColumnModel(name: 'not'),
      ], isPremium: true),
      isTrue,
    );
    final owned = _tableId(provider);
    expect(owned, isNot(joined));
    await provider.setSharedRole(owned, 'owner');

    await provider.clearSharedState(joinedOnly: true);
    expect(provider.isSharedTable(joined), isFalse);
    expect(provider.pendingChangeCount(joined), 0);
    expect(provider.hasJoinedTables, isFalse);
    // Kullanıcının kendi hesabıyla paylaştığı tablo hâlâ onun.
    expect(provider.isSharedOwner(owned), isTrue);
    // Tabloların kendisi cihazda durur.
    expect(provider.tables.length, 2);
  });

  test('hesap silinince paylaşılan tablolar da kopar, veri kalır', () async {
    final provider = await _seeded();
    final id = _tableId(provider);
    await provider.setSharedRole(id, 'owner');
    await provider.addRow(['izmir', '12000']);

    await provider.clearSharedState();
    expect(provider.isSharedTable(id), isFalse);
    expect(provider.pendingChangeCount(id), 0);
    expect(provider.currentTable!.rows.length, 2);
  });
}
