import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/table_sort_preference.dart';
import 'package:table_note/services/storage_service.dart';

List<ColumnModel> columns(List<String> names) => [
  for (final name in names) ColumnModel(name: name),
];

void main() {
  test('sütunlar yer değiştirse de aynı sütunu bulur', () {
    final before = columns(['tarih', 'nereden', 'kilosu']);
    final preference = TableSortPreference.forColumn(
      before,
      2,
      ascending: false,
    );
    expect(preference.resolve(before), 2);
    expect(preference.resolve(columns(['kilosu', 'tarih', 'nereden'])), 0);
  });

  test('aynı adlı sütunları birbirinden ayırır', () {
    final table = columns(['not', 'kilosu', 'not']);
    final second = TableSortPreference.forColumn(table, 2, ascending: true);
    expect(second.occurrence, 1);
    expect(second.resolve(table), 2);
    expect(
      TableSortPreference.forColumn(table, 0, ascending: true).resolve(table),
      0,
    );
  });

  test('silinen ya da adı değişen sütun yanlış sütuna kaymaz', () {
    final preference = TableSortPreference.forColumn(
      columns(['tarih', 'kilosu']),
      1,
      ascending: true,
    );
    expect(preference.resolve(columns(['tarih'])), isNull);
    expect(preference.resolve(columns(['tarih', 'ağırlık'])), isNull);
  });

  test('JSON gidiş-dönüşü korunur, bozuk kayıtlar reddedilir', () {
    const original = TableSortPreference(
      column: 'kilosu',
      occurrence: 0,
      ascending: false,
    );
    final restored = TableSortPreference.fromJson(original.toJson())!;
    expect(restored.column, 'kilosu');
    expect(restored.occurrence, 0);
    expect(restored.ascending, isFalse);

    expect(TableSortPreference.fromJson(null), isNull);
    expect(TableSortPreference.fromJson('kilosu'), isNull);
    expect(TableSortPreference.fromJson({'column': 'x'}), isNull);
    expect(
      TableSortPreference.fromJson({
        'column': 'x',
        'occurrence': -1,
        'ascending': true,
      }),
      isNull,
    );
  });

  test(
    'depolama kaydeder, bozuk girdiyi atlar ve tüm verileri temizleyince siler',
    () async {
      SharedPreferences.setMockInitialValues({
        // One valid and one corrupt entry written by some older build.
        'table_sorts_v1':
            '{"a":{"column":"kilosu","occurrence":0,"ascending":true},'
            '"b":{"column":5}}',
      });
      final loaded = await StorageService.loadTableSorts();
      expect(loaded.keys, ['a']);

      expect(
        await StorageService.saveTableSorts({
          'c': const TableSortPreference(
            column: 'tarih',
            occurrence: 0,
            ascending: false,
          ),
        }),
        isTrue,
      );
      expect((await StorageService.loadTableSorts()).keys, ['c']);

      await StorageService.clearAllData();
      expect(await StorageService.loadTableSorts(), isEmpty);
    },
  );
}
