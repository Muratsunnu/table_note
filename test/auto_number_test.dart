import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/models/tabel_model.dart';

TableModel _table(List<List<String>> rows) => TableModel(
  columns: [
    ColumnModel(name: 'sıra', columnType: ColumnType.autoNumber),
    ColumnModel(name: 'nereden'),
  ],
  rows: rows,
  tableName: 'seferler',
);

void main() {
  test('boş tabloda ilk numara 1', () {
    expect(_table([]).nextAutoNumber(0), 1);
  });

  test('silinen satırdan sonra numara tekrarlanmaz', () {
    // 1..5 varken 2 silindi: satır sayısı 4, ama en büyük numara 5.
    // Eski hesap (sayı + 1) burada ikinci bir 5 üretiyordu.
    final table = _table([
      ['1', 'konya'],
      ['3', 'izmir'],
      ['4', 'karaman'],
      ['5', 'ankara'],
    ]);
    expect(table.nextAutoNumber(0), 6);
  });

  test('karşı tarafın satırı indikten sonra onun üstünden devam eder', () {
    // Ortak tabloda indirilen satır 6 numarayı almış; yerelde 5 satır var.
    final table = _table([
      ['1', 'konya'],
      ['2', 'izmir'],
      ['3', 'karaman'],
      ['4', 'ankara'],
      ['6', 'bursa'],
    ]);
    expect(table.nextAutoNumber(0), 7);
  });

  test('sayıya çevrilemeyen hücreler numarayı bozmaz', () {
    final table = _table([
      ['1', 'konya'],
      ['', 'izmir'],
      ['abc', 'karaman'],
    ]);
    expect(table.nextAutoNumber(0), 2);
  });

  test('kısa satırlar hata üretmez', () {
    final table = _table([
      ['1', 'konya'],
      <String>[],
    ]);
    expect(table.nextAutoNumber(0), 2);
  });
}
