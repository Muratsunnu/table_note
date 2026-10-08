import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/utils/table_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final columns = [
    ColumnModel(name: 'Yükleme'),
    ColumnModel(name: 'İndirme'),
    ColumnModel(name: 'Saat'),
    ColumnModel(name: 'Yük cinsi'),
  ];
  TableSearch parse(String query) => TableSearch.parse(query, columns);

  group('arama sözünün çözülmesi', () {
    test('yalnızca söz yazılırsa her sütunda aranır', () {
      final search = parse('  Konya ');
      expect(search.term, 'konya');
      expect(search.columnIndex, isNull);
      expect(search.covers(0) && search.covers(3), isTrue);
    });

    test('"sütun: söz" yalnızca o sütunda arar', () {
      final search = parse('yükleme: konya');
      expect(search.term, 'konya');
      expect(search.columnIndex, 0);
      expect(search.covers(0), isTrue);
      expect(search.covers(1), isFalse);
      // Boşluk koymak şart değil.
      expect(parse('indirme:konya').columnIndex, 1);
    });

    test('sütun adı yazım farkına takılmaz', () {
      expect(parse('YÜKLEME: konya').columnIndex, 0);
      expect(parse('yukleme: konya').columnIndex, 0);
      expect(parse('indirme: konya').columnIndex, 1);
      expect(parse('İndirme: konya').columnIndex, 1);
    });

    test('tek bir sütunu gösteren başlangıç yeter, belirsizi yetmez', () {
      expect(parse('ind: konya').columnIndex, 1);
      // "yük" hem "Yükleme"nin hem "Yük cinsi"nin başı.
      final ambiguous = parse('yük: konya');
      expect(ambiguous.columnIndex, isNull);
      expect(ambiguous.term, 'yük: konya');
      // Adı tam yazılan sütun, başka bir sütunun başı olsa da seçilir.
      expect(parse('yük cinsi: çimento').columnIndex, 3);
    });

    test('sütunu göstermeyen iki nokta sıradan aramadır', () {
      // Saat değerinin içinde de iki nokta var.
      final time = parse('10:30');
      expect(time.columnIndex, isNull);
      expect(time.term, '10:30');
      expect(parse('olmayan: konya').term, 'olmayan: konya');
      expect(parse(': konya').columnIndex, isNull);
    });

    test('sütundan sonraki iki nokta aranan söze aittir', () {
      final search = parse('saat: 10:30');
      expect(search.columnIndex, 2);
      expect(search.term, '10:30');
    });

    test('söz henüz yazılmamışsa süzülecek bir şey yoktur', () {
      final search = parse('yükleme:');
      expect(search.columnIndex, 0);
      expect(search.isEmpty, isTrue);
      expect(parse('').isEmpty, isTrue);
    });
  });

  group('tabloda', () {
    Future<TableProvider> seeded() async {
      SharedPreferences.setMockInitialValues({});
      final provider = TableProvider();
      while (provider.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await provider.createTable('seferler', [
        ColumnModel(name: 'yükleme'),
        ColumnModel(name: 'indirme'),
        ColumnModel(name: 'kilosu', isNumeric: true),
      ]);
      await provider.addRow(['konya', 'ankara', '35000']);
      await provider.addRow(['ankara', 'konya', '1200']);
      await provider.addRow(['izmir', 'bursa', '500']);
      return provider;
    }

    test('söz iki sütunda da geçiyorsa sütun adı ayırır', () async {
      final provider = await seeded();

      // Sıradan arama: iki satır da çıkar.
      provider.setSearchQuery('konya');
      expect(provider.visibleRowIndices, [0, 1]);

      provider.setSearchQuery('yükleme: konya');
      expect(provider.visibleRowIndices, [0]);
      expect(provider.searchLabel, 'yükleme: konya');
      expect(provider.filteredRowCount, 1);

      provider.setSearchQuery('indirme: konya');
      expect(provider.visibleRowIndices, [1]);
    });

    test('eşleşme yalnızca aranan sütunda vurgulanır', () async {
      final provider = await seeded();
      provider.setSearchQuery('yükleme: konya');
      expect(provider.searchTermFor(0), 'konya');
      expect(provider.searchTermFor(1), isEmpty);

      provider.setSearchQuery('konya');
      expect(provider.searchTermFor(0), 'konya');
      expect(provider.searchTermFor(1), 'konya');
    });

    test('sayı sütununda ekranda görünen ayraçlı hali de bulunur', () async {
      final provider = await seeded();
      provider.setSearchQuery('kilosu: 35.000');
      expect(provider.visibleRowIndices, [0]);
      // Aynı sayı başka bir sütunda aranırsa bulunmaz.
      provider.setSearchQuery('yükleme: 35000');
      expect(provider.visibleRowIndices, isEmpty);
    });

    test('yalnızca sütun adı yazılmışken tablo boşalmaz', () async {
      final provider = await seeded();
      provider.setSearchQuery('yükleme:');
      expect(provider.isFiltering, isFalse);
      expect(provider.visibleRowIndices.length, 3);
      expect(provider.searchColumnIndex, 0);
    });

    test('bilinmeyen sütun adı sıradan arama olarak kalır', () async {
      final provider = await seeded();
      provider.setSearchQuery('şehir: konya');
      expect(provider.searchColumnIndex, isNull);
      expect(provider.visibleRowIndices, isEmpty);
    });
  });
}
