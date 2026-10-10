import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/utils/spoken_number.dart';

void main() {
  String? tr(String text) => parseSpokenNumber(text);
  String? en(String text) => parseSpokenNumber(text, languageCode: 'en');

  test('sözcükle söylenen Türkçe sayılar rakama çevrilir', () {
    // Ses tanıma "değer yüz" yazıp bırakabiliyor.
    expect(tr('yüz'), '100');
    expect(tr('bir'), '1');
    expect(tr('on beş'), '15');
    expect(tr('iki yüz elli'), '250');
    expect(tr('bin'), '1000');
    expect(tr('bin beş yüz'), '1500');
    expect(tr('otuz beş bin'), '35000');
    expect(tr('iki yüz bin'), '200000');
    expect(tr('bir milyon iki yüz elli bin üç yüz'), '1250300');
    expect(tr('sıfır'), '0');
  });

  test('cümle başındaki büyük harf ve Türkçe harfler fark etmez', () {
    expect(tr('İki'), '2');
    expect(tr('ALTI'), '6');
    expect(tr('Üç yüz kırk dört'), '344');
  });

  test('rakam ve sözcük karışık söylenebilir', () {
    expect(tr('35 bin'), '35000');
    expect(tr('2 bin 500'), '2500');
    expect(tr('1 milyon 200 bin'), '1200000');
    expect(tr('3 yüz'), '300');
  });

  test('Türkçede nokta binliktir, virgül ondalıktır', () {
    // "35.000" olduğu gibi kalsaydı uygulama onu 35 diye okurdu.
    expect(tr('35.000'), '35000');
    expect(tr('1.250.000'), '1250000');
    expect(tr('1.250,75'), '1250.75');
    expect(tr('25,5'), '25.5');
    // Üçlü grup değilse nokta ondalıktır.
    expect(tr('2.5'), '2.5');
    expect(tr('100'), '100');
  });

  test('ondalıklar sözcükle de söylenebilir', () {
    expect(tr('on iki virgül beş'), '12.5');
    expect(tr('üç virgül yirmi beş'), '3.25');
    expect(tr('sıfır virgül sıfır beş'), '0.05');
    expect(tr('yüz nokta beş'), '100.5');
    expect(tr('bir buçuk'), '1.5');
    expect(tr('yarım'), '0.5');
    expect(tr('bir buçuk milyon'), '1500000');
    expect(tr('2,5 bin'), '2500');
    expect(tr('yirmi beş virgül elli'), '25.5');
  });

  test('eksi işareti ve çevredeki sözcükler', () {
    expect(tr('eksi on'), '-10');
    expect(tr('-5'), '-5');
    expect(tr('yaklaşık yüz kilo'), '100');
    expect(tr('100tl'), '100');
    expect(tr('yüz lira'), '100');
  });

  test('art arda iki ayrı sayıdan ilki alınır, toplanmaz', () {
    expect(tr('100 200'), '100');
  });

  test('sayı yoksa null döner; yazı sayısal hücreye giremez', () {
    expect(tr(''), isNull);
    expect(tr('konya'), isNull);
    expect(tr('bilmiyorum'), isNull);
    // Tek başına işaret sözcüğü sayı değildir.
    expect(tr('eksi'), isNull);
  });

  test('İngilizce sayılar', () {
    expect(en('one hundred'), '100');
    expect(en('a hundred'), '100');
    expect(en('one hundred and five'), '105');
    expect(en('twenty-five'), '25');
    expect(en('thirty five thousand'), '35000');
    expect(en('one point five'), '1.5');
    expect(en('minus twelve'), '-12');
    // İngilizcede virgül binliktir.
    expect(en('35,000'), '35000');
    expect(en('1,250.75'), '1250.75');
    expect(en('12.5'), '12.5');
    expect(en('table'), isNull);
  });
}
