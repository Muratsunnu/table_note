import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/services/voice_row_parser.dart';

void main() {
  test('Türkçe sefer cümlesini ilgili sütunlara ayırır', () {
    final columns = [
      ColumnModel(name: 'Nereden'),
      ColumnModel(name: 'Yük'),
      ColumnModel(name: 'Saat'),
      ColumnModel(name: 'Nereye'),
      ColumnModel(name: 'Ton', isNumeric: true),
    ];

    final values = const VoiceRowParser().parse(
      'Nereden Ankara, yük çimento, saat 10:30, nereye Bursa, ton 25,5',
      columns,
    );

    expect(values[0], 'Ankara');
    expect(values[1], 'çimento');
    expect(values[3], 'Bursa');
    expect(values[4], '25.5');
  });
}
