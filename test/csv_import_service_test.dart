import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/services/csv_import_service.dart';

void main() {
  test('tırnaklı ve Türkçe CSV verisini tabloya dönüştürür', () {
    final bytes = Uint8List.fromList(
      utf8.encode('Nereden,Yük,Ton\nAnkara,"çimento, torbalı",25.5'),
    );

    final table = CsvImportService().parse(bytes, 'Seferler.csv');

    expect(table.tableName, 'Seferler');
    expect(table.columns.map((column) => column.name), [
      'Nereden',
      'Yük',
      'Ton',
    ]);
    expect(table.rows.single, ['Ankara', 'çimento, torbalı', '25.5']);
    expect(table.columns.last.isNumeric, isTrue);
  });
}
