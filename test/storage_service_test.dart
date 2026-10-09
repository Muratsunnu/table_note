import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('okunamayan kayıt', () {
    Map<String, dynamic> table(String name) => {
      'tableName': name,
      'columns': [
        {'name': 'Nereden'},
      ],
      'rows': [
        ['Gebze'],
      ],
    };

    test('tek bozuk tablo ötekileri gizlemez, ham kayıt saklanır', () async {
      final raw = jsonEncode({
        'schemaVersion': 3,
        'data': [
          table('Seferler'),
          // Sütunları liste olmayan, çözülemeyen bir tablo.
          {'tableName': 'Bozuk', 'columns': 'yok', 'rows': 7},
          table('Yakıt'),
        ],
      });
      SharedPreferences.setMockInitialValues({'tables': raw});

      final tables = await StorageService.loadTables();
      final prefs = await SharedPreferences.getInstance();

      expect(tables.map((table) => table.tableName), ['Seferler', 'Yakıt']);
      expect(prefs.getString('tables_unreadable_backup'), raw);

      // Sonraki kayıt asıl anahtarın üstüne yazar; kopya yerinde kalır.
      await StorageService.saveTables(tables);
      expect(prefs.getString('tables_unreadable_backup'), raw);
    });

    test('hiç okunamayan liste boş açılır ama veri silinmez', () async {
      const raw = '{"schemaVersion": 3, "data": [ bozuk';
      SharedPreferences.setMockInitialValues({'tables': raw});

      expect(await StorageService.loadTables(), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tables_unreadable_backup'), raw);
      // Boş listeyle başlayıp yeni tablo kaydetmek eski veriyi yok etmez.
      await StorageService.saveTables([]);
      expect(prefs.getString('tables_unreadable_backup'), raw);
    });

    test('daha yeni bir sürümün kaydı da saklanır', () async {
      final raw = jsonEncode({'schemaVersion': 99, 'data': <Object>[]});
      SharedPreferences.setMockInitialValues({'tally_tables': raw});

      expect(await StorageService.loadTallyTables(), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tally_tables_unreadable_backup'), raw);
    });

    test('sağlam kayıt için kopya oluşturulmaz', () async {
      SharedPreferences.setMockInitialValues({
        'tables': jsonEncode({
          'schemaVersion': 3,
          'data': [table('Seferler')],
        }),
      });

      expect(await StorageService.loadTables(), hasLength(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('tables_unreadable_backup'), isFalse);
    });
  });

  test('eski tablo listesini sürümlü zarfa kayıpsız taşır', () async {
    SharedPreferences.setMockInitialValues({
      'tables': jsonEncode([
        {
          'tableName': 'Seferler',
          'columns': [
            {'name': 'Nereden'},
            {'name': 'Nereye'},
          ],
          'rows': [
            ['Gebze', 'Bursa'],
          ],
        },
      ]),
    });

    final tables = await StorageService.loadTables();
    final prefs = await SharedPreferences.getInstance();
    final migrated =
        jsonDecode(prefs.getString('tables')!) as Map<String, dynamic>;
    final migratedData = migrated['data'] as List<dynamic>;

    expect(tables, hasLength(1));
    expect(tables.single.rows.single, ['Gebze', 'Bursa']);
    expect(migrated['schemaVersion'], 3);
    expect(migratedData.single['id'], tables.single.id);
    expect(prefs.getString('tables_legacy_v1_backup'), isNotNull);
  });

  test('eski çetele listesini kimlikleriyle birlikte taşır', () async {
    SharedPreferences.setMockInitialValues({
      'tally_tables': jsonEncode([
        {
          'tableName': 'Eylül',
          'startDate': '2026-09-01T00:00:00.000',
          'endDate': '2026-09-01T00:00:00.000',
          'statuses': [
            {'code': 'V', 'label': 'Var', 'colorValue': 0xFF00FF00},
          ],
          'items': [
            {'name': 'Ali', 'entries': <String, String>{}},
          ],
        },
      ]),
    });

    final tallies = await StorageService.loadTallyTables();
    final prefs = await SharedPreferences.getInstance();
    final migrated =
        jsonDecode(prefs.getString('tally_tables')!) as Map<String, dynamic>;

    expect(tallies.single.id, isNotEmpty);
    expect(tallies.single.items.single.id, isNotEmpty);
    expect(migrated['schemaVersion'], 3);
    expect(prefs.getString('tally_tables_legacy_v1_backup'), isNotNull);
  });

  test('gelecek sürümdeki kayıtları ezmeden reddeder', () async {
    final futureData = jsonEncode({'schemaVersion': 999, 'data': <dynamic>[]});
    SharedPreferences.setMockInitialValues({'tables': futureData});

    final tables = await StorageService.loadTables();
    final prefs = await SharedPreferences.getInstance();

    expect(tables, isEmpty);
    expect(prefs.getString('tables'), futureData);
  });
}
