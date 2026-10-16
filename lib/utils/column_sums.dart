import '../models/tabel_model.dart';

/// Verilen satırlarda toplanan sütunların toplamları, sütun adına göre.
///
/// Toplamlar kutusu ekranda görünen satırları, dosya ise içine yazılan
/// satırları toplar; ikisi aynı kuralı izlesin diye hesap burada durur.
/// Sabit değer ve sıra numarası sütunları toplanmaz.
Map<String, double> columnSums(TableModel table, List<List<String>> rows) {
  final totals = columnTotals(table, rows);
  return {
    for (var index = 0; index < totals.length; index++)
      if (totals[index] case final total?) table.columns[index].name: total,
  };
}

/// Sütun sütun toplamlar, sütunların sırasıyla; toplanmayan sütun için null.
/// Aynı adlı iki sütun olsa da karışmaz: PDF'in toplam satırı bunu kullanır.
List<double?> columnTotals(TableModel table, List<List<String>> rows) => [
  for (var index = 0; index < table.columns.length; index++)
    if (table.columns[index].isSummed)
      rows.fold<double>(
        0,
        (sum, row) =>
            sum + (index < row.length ? double.tryParse(row[index]) ?? 0 : 0),
      )
    else
      null,
];
