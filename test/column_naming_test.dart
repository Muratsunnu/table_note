import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/utils/column_naming.dart';

void main() {
  final tr = AppLocalizations(const Locale('tr'));
  final en = AppLocalizations(const Locale('en'));

  test('boş ada tipin adı yazılır', () {
    expect(renamedForType('', ColumnType.date, tr), 'tarih');
    expect(renamedForType('   ', ColumnType.time, tr), 'saat');
    expect(renamedForType('', ColumnType.autoNumber, tr), 'sıra');
  });

  test('kullanıcının yazdığı ad ezilmez', () {
    expect(renamedForType('sefer günü', ColumnType.date, tr), isNull);
    expect(renamedForType('kalkış', ColumnType.time, tr), isNull);
  });

  test('başka bir tipin önerisi güncellenir', () {
    // "tarih" adlı sütun saate çevrilirse ad olduğu gibi kalırsa yanıltıcı
    // olur; bu yüzden öneriler kendi aralarında değiştirilebilir.
    expect(renamedForType('tarih', ColumnType.time, tr), 'saat');
    expect(renamedForType('saat', ColumnType.autoNumber, tr), 'sıra');
  });

  test('aynı öneri yeniden yazılmaz', () {
    expect(renamedForType('tarih', ColumnType.date, tr), isNull);
  });

  test('büyük/küçük harf farkı öneri sayılır', () {
    expect(renamedForType('Tarih', ColumnType.time, tr), 'saat');
  });

  test('adı kendiliğinden belli olmayan tiplerde öneri yok', () {
    expect(renamedForType('', ColumnType.normal, tr), isNull);
    expect(renamedForType('', ColumnType.constant, tr), isNull);
    expect(renamedForType('', ColumnType.formula, tr), isNull);
  });

  test('İngilizce arayüzde İngilizce ad gelir', () {
    expect(renamedForType('', ColumnType.date, en), 'date');
    expect(renamedForType('date', ColumnType.time, en), 'time');
    expect(renamedForType('shipment day', ColumnType.date, en), isNull);
  });
}
