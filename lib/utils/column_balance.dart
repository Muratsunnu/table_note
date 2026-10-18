import '../models/tabel_model.dart';
import 'spoken_number.dart';

/// Başlangıç değeri olan bir sütunun durumu: ne kadarı kullanıldı, ne kaldı.
///
/// Birimi yoktur: para da olabilir, stok adedi ya da ulaşılacak bir hedef de.
class ColumnBalance {
  const ColumnBalance({
    required this.columnIndex,
    required this.name,
    required this.startingValue,
    required this.total,
  });

  final int columnIndex;
  final String name;
  final double startingValue;

  /// Sütunun bütün satırlardaki toplamı (aramadan bağımsız).
  final double total;

  /// Başlangıç değerinden toplam düşülünce kalan; eksi ise aşılmıştır.
  double get remaining => startingValue - total;
  bool get isExceeded => remaining < 0;
}

/// Tablonun, başlangıç değeri verilmiş sütunları. Toplamlar kutusuyla aynı
/// kuralla toplanır ve her zaman tablonun tamamına bakar: arama yaparken
/// "kalan" değişirse yanıltır.
List<ColumnBalance> computeColumnBalances(TableModel table) {
  return [
    for (var index = 0; index < table.columns.length; index++)
      if (table.columns[index] case final column
          when column.isSummed && column.startingValue != null)
        ColumnBalance(
          columnIndex: index,
          name: column.name,
          startingValue: column.startingValue!,
          total: table.rows.fold<double>(
            0,
            (sum, row) =>
                sum +
                (index < row.length ? double.tryParse(row[index]) ?? 0 : 0),
          ),
        ),
  ];
}

/// Elle yazılmış bir sayıyı uygulamanın diline göre okur: Türkçede "100.000"
/// yüz bindir ve virgül ondalıktır; İngilizcede tersi. Sayı değilse null.
double? parseTypedNumber(String text, {required String languageCode}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || !RegExp(r'^-?[0-9][0-9.,]*$').hasMatch(trimmed)) {
    return null;
  }
  final number = parseSpokenNumber(trimmed, languageCode: languageCode);
  return number == null ? null : double.tryParse(number);
}
