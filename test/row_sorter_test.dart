import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/utils/row_sorter.dart';

List<String> order(
  List<List<String>> rows,
  ColumnModel column, {
  bool ascending = true,
  int columnIndex = 0,
}) => RowSorter.sort(
  indices: List<int>.generate(rows.length, (i) => i),
  rows: rows,
  column: column,
  columnIndex: columnIndex,
  ascending: ascending,
).map((index) => RowSorter.cellAt(rows, index, columnIndex)).toList();

void main() {
  test('sayısal sütun değere göre sıralanır, metin gibi değil', () {
    final column = ColumnModel(name: 'kilosu', isNumeric: true);
    final rows = [
      ['9'],
      ['35000'],
      ['12,5'],
      ['120'],
    ];
    // Metin sıralamasında "12,5" < "9" olurdu; sayı sıralamasında olmaz.
    expect(order(rows, column), ['9', '12,5', '120', '35000']);
    expect(order(rows, column, ascending: false), [
      '35000',
      '120',
      '12,5',
      '9',
    ]);
  });

  test('sayıya çevrilemeyen hücreler sayıların arkasına düşer', () {
    final column = ColumnModel(name: 'kilosu', isNumeric: true);
    final rows = [
      ['abc'],
      ['5'],
      ['1'],
    ];
    expect(order(rows, column), ['1', '5', 'abc']);
  });

  test('tarih sütunu gün/ay/yıl olarak okunur', () {
    final column = ColumnModel(name: 'tarih', columnType: ColumnType.date);
    final rows = [
      ['02.01.2027'],
      ['14.09.2026'],
      ['3.1.2026'],
      ['15.09.2026'],
    ];
    // Metin sıralaması "02..." < "14..." derdi; tarih sıralaması yılı görür.
    expect(order(rows, column), [
      '3.1.2026',
      '14.09.2026',
      '15.09.2026',
      '02.01.2027',
    ]);
  });

  test('saat sütunu dakikaya çevrilerek sıralanır', () {
    final column = ColumnModel(name: 'saat', columnType: ColumnType.time);
    final rows = [
      ['9:05'],
      ['23:37'],
      ['01:00'],
      ['09:50'],
    ];
    expect(order(rows, column), ['01:00', '9:05', '09:50', '23:37']);
  });

  test('sıra numarası sütunu sayısal sıralanır', () {
    final column = ColumnModel(
      name: 'sıra',
      isNumeric: true,
      columnType: ColumnType.autoNumber,
    );
    final rows = [
      ['10'],
      ['2'],
      ['1'],
    ];
    expect(order(rows, column), ['1', '2', '10']);
  });

  test('alfabetik sıralama Türkçe harfleri doğru yerleştirir', () {
    final column = ColumnModel(name: 'nereden');
    final rows = [
      ['izmir'],
      ['ısparta'],
      ['çorum'],
      ['ankara'],
      ['istanbul'],
      ['diyarbakır'],
    ];
    // ı harfi h ile i arasında, ç harfi c ile d arasında gelir.
    expect(order(rows, column), [
      'ankara',
      'çorum',
      'diyarbakır',
      'ısparta',
      'istanbul',
      'izmir',
    ]);
  });

  test('büyük harf Türkçe kurallarıyla küçültülür', () {
    expect(RowSorter.fold('İZMİR'), 'izmir');
    expect(RowSorter.fold('ISPARTA'), 'ısparta');
    expect(RowSorter.compareText('Ankara', 'ankara'), 0);
  });

  test('boş hücreler her iki yönde de en sonda kalır', () {
    final column = ColumnModel(name: 'malzeme');
    final rows = <List<String>>[
      ['b'],
      [''],
      ['a'],
      [],
    ];
    expect(order(rows, column), ['a', 'b', '', '']);
    expect(order(rows, column, ascending: false), ['b', 'a', '', '']);
  });

  test('eşit hücrelerde girildiği sıra korunur', () {
    final column = ColumnModel(name: 'nereden');
    final rows = [
      ['konya', 'ilk'],
      ['konya', 'ikinci'],
      ['ankara', 'üçüncü'],
    ];
    final sorted = RowSorter.sort(
      indices: [0, 1, 2],
      rows: rows,
      column: column,
      columnIndex: 0,
      ascending: true,
    );
    expect(sorted, [2, 0, 1]);
  });

  test('kısa satırlarda eksik hücre boş sayılır', () {
    final column = ColumnModel(name: 'kilosu', isNumeric: true);
    final rows = [
      ['a', '5'],
      ['b'],
      ['c', '3'],
    ];
    expect(order(rows, column, columnIndex: 1), ['3', '5', '']);
  });
}
