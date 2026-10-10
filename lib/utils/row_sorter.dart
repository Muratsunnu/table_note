import '../models/tabel_model.dart';

/// Görünüm sıralaması. Kayıtlı satır sırasına dokunmaz; yalnızca hangi satırın
/// hangi sırada gösterileceğini söyler. Böylece sıra numarası, "son kayıtlar"
/// ve dışa aktarma girildiği sırayı korur.
class RowSorter {
  /// Türkçe alfabe sırası. 'ı' harfi h ile i arasına girer, 'ç' c'den sonra.
  static const String _alphabet = 'abcçdefgğhıijklmnoöprsştuüvyzqwx';

  static final Map<int, int> _ranks = {
    for (var i = 0; i < _alphabet.length; i++)
      _alphabet.codeUnitAt(i): 1000 + i,
  };

  /// Satır indekslerini sütun tipine göre yeniden dizer.
  static List<int> sort({
    required List<int> indices,
    required List<List<String>> rows,
    required ColumnModel column,
    required int columnIndex,
    required bool ascending,
  }) {
    final sorted = List<int>.from(indices);
    sorted.sort((a, b) {
      final left = cellAt(rows, a, columnIndex);
      final right = cellAt(rows, b, columnIndex);
      // Boş hücreler yönden bağımsız olarak en sonda kalır.
      if (left.isEmpty || right.isEmpty) {
        if (left.isEmpty && right.isEmpty) return a.compareTo(b);
        return left.isEmpty ? 1 : -1;
      }
      final result = compare(left, right, column);
      if (result != 0) return ascending ? result : -result;
      // Eşit hücrelerde girildiği sıra korunur.
      return a.compareTo(b);
    });
    return sorted;
  }

  static String cellAt(List<List<String>> rows, int row, int column) {
    if (row < 0 || row >= rows.length) return '';
    final cells = rows[row];
    return column < cells.length ? cells[column].trim() : '';
  }

  /// Tipine uyan karşılaştırma; çözümlenemeyen değerler metin gibi sıralanır.
  static int compare(String a, String b, ColumnModel column) {
    if (column.isDate) {
      final left = dateValue(a);
      final right = dateValue(b);
      if (left != null && right != null) return left.compareTo(right);
    } else if (column.isTime) {
      final left = timeValue(a);
      final right = timeValue(b);
      if (left != null && right != null) return left.compareTo(right);
    } else if (column.isAutoNumber || column.isEffectivelyNumeric) {
      final left = numberValue(a);
      final right = numberValue(b);
      if (left != null && right != null) return left.compareTo(right);
      // Sayıya çevrilemeyen hücreler sayıların arkasına düşer.
      if (left != null) return -1;
      if (right != null) return 1;
    }
    return compareText(a, b);
  }

  /// "14.09.2026" biçimini okur; gün ve ay tek haneli de olabilir.
  static DateTime? dateValue(String value) {
    final parts = value.split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  /// "23:37" biçimini dakikaya çevirir.
  static int? timeValue(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  /// Hem "12.5" hem "12,5" kabul edilir.
  static double? numberValue(String value) {
    final direct = double.tryParse(value);
    if (direct != null && direct.isFinite) return direct;
    final swapped = double.tryParse(value.replaceAll(',', '.'));
    return swapped != null && swapped.isFinite ? swapped : null;
  }

  /// Türkçe alfabetik karşılaştırma: "ışık" < "iyi", "çam" < "dal".
  static int compareText(String a, String b) {
    final left = fold(a);
    final right = fold(b);
    final shared = left.length < right.length ? left.length : right.length;
    for (var i = 0; i < shared; i++) {
      final rankA = _ranks[left.codeUnitAt(i)] ?? left.codeUnitAt(i);
      final rankB = _ranks[right.codeUnitAt(i)] ?? right.codeUnitAt(i);
      if (rankA != rankB) return rankA.compareTo(rankB);
    }
    return left.length.compareTo(right.length);
  }

  /// Türkçe küçültme: I → ı, İ → i. Dart'ın varsayılanı bunu yanlış yapar.
  static String fold(String value) =>
      value.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
}
