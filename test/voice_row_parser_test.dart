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

    final values = const VoiceRowParser()
        .parse(
          'Nereden Ankara, yük çimento, saat 10:30, nereye Bursa, ton 25,5',
          columns,
        )
        .values;

    expect(values[0], 'Ankara');
    expect(values[1], 'çimento');
    expect(values[3], 'Bursa');
    expect(values[4], '25.5');
  });

  group('sayısal sütun', () {
    final columns = [
      ColumnModel(name: 'Nereden'),
      ColumnModel(name: 'Değer', isNumeric: true),
      ColumnModel(name: 'Kilosu', isNumeric: true),
    ];
    VoiceRowResult parse(String text) =>
        const VoiceRowParser().parse(text, columns);

    test('sözcükle söylenen sayı hücreye rakam olarak girer', () {
      // Ses tanıma "değer 100" yerine "değer yüz" yazmıştı ve hücrede
      // "yüz" kalmıştı.
      expect(parse('değer yüz').values[1], '100');
      expect(parse('Değer iki yüz elli kilosu otuz beş bin').values, {
        1: '250',
        2: '35000',
      });
    });

    test('binlik ayırıcıyla yazılan sayı küçülmez', () {
      // "35.000" olduğu gibi kalsa uygulama 35 diye okurdu.
      expect(parse('kilosu 35.000').values[2], '35000');
    });

    test('sayıya çevrilemeyen söz hücreye yazılmaz, bildirilir', () {
      final result = parse('nereden konya değer bilmiyorum kilosu 500');
      expect(result.values, {0: 'konya', 2: '500'});
      expect(result.unreadNumbers, {1});
    });

    test('yazı sütunundaki sayı sözcüğüne dokunulmaz', () {
      // "Yüz" bir yer adı da olabilir; çeviri yalnızca sayısal sütunda.
      expect(parse('nereden yüz').values[0], 'yüz');
    });
  });
}
