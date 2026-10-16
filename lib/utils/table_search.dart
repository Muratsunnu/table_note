import '../models/tabel_model.dart';

/// Aramanın tek bir koşulu: bir söz ve varsa sınırlandığı sütun.
class SearchClause {
  const SearchClause({required this.term, this.columnIndex, String? rawTerm})
    : rawTerm = rawTerm ?? term;

  /// Aranan söz; küçük harfe çevrilmiş ve kırpılmış.
  final String term;

  /// Aranan söz, kullanıcının yazdığı gibi: "Konya". Dosya adına ve
  /// dosyanın başlığına bu geçer.
  final String rawTerm;

  /// Koşulun sınırlandığı sütun. null ise her sütunda aranır.
  final int? columnIndex;

  bool get isEmpty => term.isEmpty;

  /// Bu sütundaki hücreler bu koşula bakar mı.
  bool covers(int column) => columnIndex == null || columnIndex == column;
}

/// Tablo içi aramanın çözülmüş hali: ne aranıyor ve nerede.
///
/// Arama kutusuna yalnızca bir söz yazılırsa her sütunda aranır. Söz
/// "sütun adı: aranan" biçiminde yazılırsa yalnızca o sütunda aranır. İki
/// sütunda da aynı değerin geçtiği tablolarda ("yükleme" ve "indirme"
/// sütunlarının ikisinde de Konya) aranan satırı bulmanın başka yolu yoktu.
///
/// Koşullar virgülle eklenir: "nereden: konya, nereye: ankara" Konya'dan
/// Ankara'ya gidenleri bulur; satır her koşulu birden sağlamalıdır. Virgül
/// ancak ardından yeni bir "sütun:" geliyorsa koşulları ayırır; "12,5" gibi
/// bir ondalık ya da düz bir yazı bölünmez.
///
/// İki nokta üst üste şarttır ve öncesindeki söz gerçekten bir sütunu
/// göstermelidir. Göstermiyorsa yazılanın tamamı sıradan bir arama sayılır;
/// böylece "10:30" gibi içinde iki nokta geçen bir değer de aranabilir.
class TableSearch {
  const TableSearch(this.clauses);

  static const none = TableSearch([]);

  /// Yazılış sırasıyla koşullar; sözü henüz yazılmamış olanlar da dahil.
  final List<SearchClause> clauses;

  /// Süzmeye katılan koşullar: sözü yazılmış olanlar.
  Iterable<SearchClause> get active =>
      clauses.where((clause) => !clause.isEmpty);

  bool get isEmpty => active.isEmpty;

  /// Aramanın sınırlandığı sütunlar, yazılış sırasıyla ve birer kez.
  /// "yükleme:" yazılıp söz henüz girilmemişken de sütun bellidir.
  List<int> get columnIndices => [
    for (final clause in clauses)
      if (clause.columnIndex case final index?) index,
  ].toSet().toList();

  /// Bu sütunun hücrelerinde vurgulanacak söz: sütuna sınırlı bir koşul
  /// varsa onunki, yoksa her sütunda aranan söz. Aranmayan sütunda boştur.
  String termFor(int column) {
    for (final clause in active) {
      if (clause.columnIndex == column) return clause.term;
    }
    for (final clause in active) {
      if (clause.columnIndex == null) return clause.term;
    }
    return '';
  }

  static TableSearch parse(String query, List<ColumnModel> columns) {
    final parts = query.trim().split(',');
    final segments = <String>[];
    for (var index = 0; index < parts.length; index++) {
      final part = parts[index];
      final last = index == parts.length - 1;
      if (segments.isEmpty || _namesColumn(part, columns)) {
        segments.add(part);
      } else if (last && _stillTyping(part, columns)) {
        // "nereden: konya, ner" — ikinci sütunun adı yazılıyor; o bitene
        // kadar tablo boşalmasın.
      } else {
        // Virgül yeni bir koşul başlatmıyor: sözün kendisine aittir.
        segments[segments.length - 1] = '${segments.last},$part';
      }
    }
    final clauses = [
      for (final segment in segments)
        if (segment.trim().isNotEmpty) _clause(segment, columns),
    ];
    return clauses.isEmpty ? none : TableSearch(clauses);
  }

  static SearchClause _clause(String segment, List<ColumnModel> columns) {
    final original = segment.trim();
    final text = original.toLowerCase();
    final colon = text.indexOf(':');
    if (colon > 0) {
      final index = _columnNamed(text.substring(0, colon), columns);
      if (index != null) {
        // Küçük harfe çevirmek bazı harflerin uzunluğunu değiştirir ("İ");
        // yazılan hâlin iki noktası ayrıca bulunur.
        return SearchClause(
          term: text.substring(colon + 1).trim(),
          columnIndex: index,
          rawTerm: original.substring(original.indexOf(':') + 1).trim(),
        );
      }
    }
    return SearchClause(term: text, rawTerm: original);
  }

  /// Parça "sütun: …" ile mi başlıyor.
  static bool _namesColumn(String part, List<ColumnModel> columns) {
    final text = part.trim().toLowerCase();
    final colon = text.indexOf(':');
    return colon > 0 && _columnNamed(text.substring(0, colon), columns) != null;
  }

  /// Son parça boş mu ya da hâlâ bir sütun adı mı yazılıyor ("ner").
  static bool _stillTyping(String part, List<ColumnModel> columns) {
    final name = _fold(part);
    if (name.isEmpty) return true;
    if (name.contains(':') || !RegExp(r'^[a-z]').hasMatch(name)) return false;
    return columns.any((column) => _fold(column.name).startsWith(name));
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
