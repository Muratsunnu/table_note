import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/services/storage_service.dart';

TableModel _table() => TableModel(
  id: 't1',
  tableName: 'seferler',
  columns: [
    ColumnModel(name: 'nereden'),
    ColumnModel(name: 'kilosu'),
  ],
  rows: [
    ['konya', '35000'],
    ['izmir', '12000'],
  ],
);

TableModel _roundTrip(TableModel table) =>
    TableModel.fromJson(jsonDecode(jsonEncode(table.toJson())));

void main() {
  _persistenceTests();
  test('her satır bir kimlik alır ve kayıt/okuma arasında korunur', () {
    final table = _table();
    expect(table.rowIds, hasLength(2));
    expect(table.rowIds.toSet(), hasLength(2));

    final reopened = _roundTrip(table);
    expect(reopened.rowIds, table.rowIds);
  });

  test('satır silmek diğerlerinin kimliğini değiştirmez', () {
    final table = _table();
    final second = table.rowIds[1];
    table.removeRowAt(0);
    expect(table.rows.single, ['izmir', '12000']);
    // The surviving row is still the same row to everyone else.
    expect(table.rowIds.single, second);
  });

  test('satırı düzenlemek kimliğini korur, eklemek yeni kimlik verir', () {
    final table = _table();
    final first = table.rowIds.first;
    table.replaceRow(0, ['konya', '40000']);
    expect(table.rowIds.first, first);

    table.appendRow(['ankara', '70']);
    expect(table.rowIds, hasLength(3));
    expect(table.rowIds.last, isNot(first));
  });

  test('sütun yapısı değişince satırlar kimliğini korur', () {
    final table = _table();
    final before = List<String>.from(table.rowIds);
    table.setRows([
      ['konya', '35000', ''],
      ['izmir', '12000', ''],
    ], ids: before);
    expect(table.rowIds, before);
  });

  test('kimliksiz eski kayıtlar açılırken kimlik kazanır', () {
    final legacy = {
      'id': 't1',
      'tableName': 'seferler',
      'columns': [
        ColumnModel(name: 'nereden').toJson(),
        ColumnModel(name: 'kilosu').toJson(),
      ],
      'rows': [
        ['konya', '35000'],
        ['izmir', '12000'],
      ],
      'createdAt': DateTime(2026, 9, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
    };
    final table = TableModel.fromJson(legacy);
    expect(table.rowIds, hasLength(2));
    expect(table.rowIds.every((id) => id.isNotEmpty), isTrue);
    // And they stick from then on.
    expect(_roundTrip(table).rowIds, table.rowIds);
  });

  test('bozuk kimlik listesi sessizce onarılır', () {
    // Too few, and a duplicate: neither may leave two rows indistinguishable.
    final table = TableModel(
      tableName: 'x',
      columns: [ColumnModel(name: 'a')],
      rows: [
        ['1'],
        ['2'],
        ['3'],
      ],
      rowIds: ['same', 'same'],
    );
    expect(table.rowIds, hasLength(3));
    expect(table.rowIds.toSet(), hasLength(3));
    expect(table.rowIds.first, 'same');
  });
}

void _persistenceTests() {
  test(
    'v2 kayıt bir kez yeniden yazılır, kimlikler artık sabit kalır',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final legacy = {
        'schemaVersion': 2,
        'savedAt': DateTime(2026, 9, 1).toUtc().toIso8601String(),
        'data': [
          {
            'id': 't1',
            'tableName': 'seferler',
            'columns': [ColumnModel(name: 'nereden').toJson()],
            'rows': [
              ['konya'],
              ['izmir'],
            ],
            'createdAt': DateTime(2026, 9, 1).toIso8601String(),
            'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
          },
        ],
      };
      SharedPreferences.setMockInitialValues({
        'flutter.tables': jsonEncode(legacy),
      });

      final first = await StorageService.loadTables();
      expect(first.single.rowIds, hasLength(2));

      // A second launch must see exactly the same identities, untouched by any
      // edit in between.
      final second = await StorageService.loadTables();
      expect(second.single.rowIds, first.single.rowIds);

      // The original payload is kept, as with every other schema migration.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tables_legacy_v1_backup'), isNotNull);
    },
  );
}
