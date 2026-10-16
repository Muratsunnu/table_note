import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/tally_model.dart';

void main() {
  group('model migrasyonu', () {
    test('eski tablo kaydına UUID ve güvenli sütun tipi ekler', () {
      final table = TableModel.fromJson({
        'tableName': 'Seferler',
        'columns': [
          {'name': 'Ton', 'isNumeric': true, 'columnType': 999},
        ],
        'rows': [
          ['24'],
        ],
      });

      expect(
        table.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(table.columns.single.columnType, ColumnType.normal);
      expect(table.rows.single.single, '24');
    });

    test('tablo JSON turunda kimlik ve tarihler korunur', () {
      final createdAt = DateTime.utc(2026, 9, 1, 8);
      final updatedAt = DateTime.utc(2026, 9, 1, 9);
      final original = TableModel(
        id: '12345678-1234-4234-8234-123456789abc',
        tableName: 'Seferler',
        columns: [ColumnModel(name: 'Nereden')],
        rows: const [
          ['Gebze'],
        ],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final restored = TableModel.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);
    });

    test('eski çetele ve öğelerine ayrı UUID üretir', () {
      final tally = TallyTableModel.fromJson({
        'tableName': 'Eylül',
        'startDate': '2026-09-01T00:00:00.000',
        'endDate': '2026-09-02T00:00:00.000',
        'statuses': [
          {'code': 'V', 'label': 'Var', 'colorValue': 0xFF00FF00},
        ],
        'items': [
          {
            'name': 'Ali',
            'entries': {'2026-09-01': 'V'},
          },
        ],
      });

      expect(tally.id, isNotEmpty);
      expect(tally.items.single.id, isNotEmpty);
      expect(tally.id, isNot(tally.items.single.id));
    });
  });
}
