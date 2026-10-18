import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/services/voice_row_parser.dart';
import 'package:table_note/utils/number_display.dart';
import 'package:table_note/utils/quick_options.dart';
import 'package:table_note/utils/row_sorter.dart';

/// "Numara" sütunu: rakam yazılır ama sayı değildir (fiş no, seri no).
ColumnModel _code([String name = 'fiş no']) =>
    ColumnModel(name: name, columnType: ColumnType.code);

void main() {
  test('toplanmaz, bin ayırıcıyla gösterilmez, elle yazılır', () {
    final column = _code();

    expect(column.isCode, isTrue);
    expect(column.isTyped, isTrue);
    expect(column.isSummed, isFalse);
    expect(column.isEffectivelyNumeric, isFalse);
    // "004512" olduğu gibi kalır; "4.512" olmaz.
    expect(showsGroupedNumbers(column), isFalse);
  });

  test('kaydedilip okununca tipi korunur; eski tipler yerinden oynamaz', () {
    final restored = ColumnModel.fromJson(_code().toJson());
    expect(restored.columnType, ColumnType.code);

    // Tip sırasıyla saklanır; yeni tip sona eklenmiştir.
    expect(ColumnType.values.last, ColumnType.code);
    expect(ColumnType.autoNumber.index, 5);
  });

  test('sayıya göre sıralanır, baştaki sıfırlar bozulmaz', () {
    final rows = [
      ['10'],
      ['9'],
      ['0100'],
      ['2'],
    ];
    final order = RowSorter.sort(
      indices: [0, 1, 2, 3],
      rows: rows,
      column: _code(),
      columnIndex: 0,
      ascending: true,
    ).map((index) => rows[index][0]).toList();

    expect(order, ['2', '9', '10', '0100']);
  });

  test('tekrar eden numara hızlı seçim önerisi olmaz', () {
    final table = TableModel(
      tableName: 'Fişler',
      columns: [_code()],
      rows: [
        for (var i = 0; i < 6; i++) ['4512'],
      ],
    );

    expect(quickOptionsFor(table, 0), isEmpty);
  });

  test('sesle söylenen numara rakama çevrilir', () {
    final result = const VoiceRowParser().parse(
      'fiş no bin iki yüz ürün tabela',
      [_code(), ColumnModel(name: 'ürün')],
    );

    expect(result.values[0], '1200');
    expect(result.values[1], 'tabela');
  });

  test('toplamlar kutusuna girmez', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveTables([
      TableModel(
        tableName: 'Fişler',
        columns: [
          _code(),
          ColumnModel(name: 'tutar', isNumeric: true),
        ],
        rows: [
          ['004512', '7200'],
          ['004513', '4800'],
        ],
      ),
    ]);
    final tables = TableProvider();
    addTearDown(tables.dispose);
    while (tables.isLoading || tables.currentTable == null) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(tables.calculateColumnSums(), {'tutar': 12000});
    expect(tables.columnBalances, isEmpty);
  });
}
