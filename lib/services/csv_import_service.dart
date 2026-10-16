import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../models/tabel_model.dart';

class CsvImportException implements Exception {
  final String code;

  const CsvImportException(this.code);
}

class CsvImportService {
  static const int maxBytes = 10 * 1024 * 1024;
  static const int maxRows = 10000;

  TableModel parse(
    Uint8List bytes,
    String fileName, {
    String fallbackTableName = 'CSV',
  }) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const CsvImportException('empty_or_too_large');
    }
    final content = utf8
        .decode(bytes, allowMalformed: false)
        .replaceFirst('\ufeff', '');
    final decoded = csv.decode(content);
    if (decoded.isEmpty || decoded.first.isEmpty) {
      throw const CsvImportException('header_missing');
    }
    if (decoded.length - 1 > maxRows) {
      throw const CsvImportException('too_many_rows');
    }

    final columnCount = decoded
        .map((row) => row.length)
        .reduce((a, b) => a > b ? a : b);
    final usedNames = <String>{};
    final headers = List.generate(columnCount, (index) {
      final raw = index < decoded.first.length
          ? decoded.first[index].toString().trim()
          : '';
      final base = raw.isEmpty ? 'Sütun ${index + 1}' : raw;
      var name = base;
      var suffix = 2;
      while (!usedNames.add(name.toLowerCase())) {
        name = '$base $suffix';
        suffix++;
      }
      return name;
    });
    final rows = decoded
        .skip(1)
        .map((source) {
          return List.generate(
            columnCount,
            (index) => index < source.length ? source[index].toString() : '',
          );
        })
        .where((row) => row.any((value) => value.trim().isNotEmpty))
        .toList();
    final columns = List.generate(
      columnCount,
      (index) => ColumnModel(
        name: headers[index],
        isNumeric:
            rows.isNotEmpty &&
            rows
                .map((row) => row[index].trim())
                .where((value) => value.isNotEmpty)
                .every(
                  (value) =>
                      double.tryParse(value.replaceAll(',', '.')) != null,
                ),
      ),
    );
    final tableName = fileName
        .replaceFirst(RegExp(r'\.csv$', caseSensitive: false), '')
        .trim();
    return TableModel(
      tableName: tableName.isEmpty ? fallbackTableName : tableName,
      columns: columns,
      rows: rows,
    );
  }
}
