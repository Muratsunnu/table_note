import '../models/tabel_model.dart';

/// Tablo içi aramanın çözülmüş hali: ne aranıyor ve nerede.
///
/// Arama kutusuna yalnızca bir söz yazılırsa her sütunda aranır. Söz
/// "sütun adı: aranan" biçiminde yazılırsa yalnızca o sütunda aranır. İki
/// sütunda da aynı değerin geçtiği tablolarda ("yükleme" ve "indirme"
/// sütunlarının ikisinde de Konya) aranan satırı bulmanın başka yolu yoktu.
///
/// İki nokta üst üste şarttır ve öncesindeki söz gerçekten bir sütunu
/// göstermelidir. Göstermiyorsa yazılanın tamamı sıradan bir arama sayılır;
/// böylece "10:30" gibi içinde iki nokta geçen bir değer de aranabilir.
class TableSearch {
  const TableSearch({required this.term, this.columnIndex});

  static const none = TableSearch(term: '');

  /// Aranan söz; küçük harfe çevrilmiş ve kırpılmış.
  final String term;

  /// Aramanın sınırlandığı sütun. null ise her sütunda aranır.
  final int? columnIndex;

  bool get isScoped => columnIndex != null;
  bool get isEmpty => term.isEmpty;

  /// Bu sütundaki hücreler aramaya dahil mi.
  bool covers(int column) => columnIndex == null || columnIndex == column;

  static TableSearch parse(String query, List<ColumnModel> columns) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return none;
    final colon = text.indexOf(':');
    if (colon > 0) {
      final index = _columnNamed(text.substring(0, colon), columns);
      if (index != null) {
        return TableSearch(
          term: text.substring(colon + 1).trim(),
          columnIndex: index,
        );
      }
    }
    return TableSearch(term: text);
  }

  /// Yazılan adın gösterdiği sütun.
  ///
  /// Önce adı tam tutan sütuna bakılır. Yoksa ad, tek bir sütunun başlangıcı
  /// ise o sütun kabul edilir: "yük:" yazmak "yükleme" için yeter. Birden
  /// fazla sütuna uyan bir başlangıç hiçbirini göstermez.
  static int? _columnNamed(String typed, List<ColumnModel> columns) {
    final name = _fold(typed);
    if (name.isEmpty) return null;
    final names = [for (final column in columns) _fold(column.name)];
    final exact = names.indexOf(name);
    if (exact >= 0) return exact;
    // Rakamla başlayan bir söz ("10:30" deki "10") sütun adının kısaltması
    // sayılmaz; öyle bir sütun ancak adı tam yazılarak seçilir.
    if (name.length < 2 || !RegExp(r'^[a-z]').hasMatch(name)) return null;
    final starting = [
      for (var index = 0; index < names.length; index++)
        if (names[index].startsWith(name)) index,
    ];
    return starting.length == 1 ? starting.single : null;
  }

  /// Sütun adları yazım farkına takılmadan eşleşir: "Yükleme", "yukleme"
  /// ve "YÜKLEME" aynı sütundur.
  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll('̇', '')
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
