import '../models/tabel_model.dart';
import 'number_display.dart';

/// Bir satırın tek satırlık özeti: dolu hücreler, ekrandaki yazılışlarıyla.
/// Paylaşım kâğıdı, dosyaya hangi kayıtların gireceğini bununla gösterir.
/// Sıra numarası atlanır; kayıt onsuz da tanınır.
String rowPreview(TableModel table, List<String> row, String language) {
  final parts = <String>[];
  for (var index = 0; index < table.columns.length; index++) {
    final column = table.columns[index];
    if (column.isAutoNumber || index >= row.length) continue;
    final cell = row[index].trim();
    if (cell.isEmpty) continue;
    parts.add(
      showsGroupedNumbers(column)
          ? formatNumericCell(cell, language: language) ?? cell
          : cell,
    );
  }
  return parts.join(' · ');
}

/// "Tek sütunda aramak için “…: …” yaz" ipucundaki örnek sütun: yazı
/// sütunlarından ilki. Sıra numarası ya da tutar örnek olarak bir şey
/// anlatmaz.
ColumnModel? searchExampleColumn(List<ColumnModel> columns) {
  for (final column in columns) {
    if (column.isNormal && !column.isNumeric) return column;
  }
  for (final column in columns) {
    if (!column.isAutoNumber) return column;
  }
  return columns.isEmpty ? null : columns.first;
}
