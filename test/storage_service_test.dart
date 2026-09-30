import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
