/// Hücrelerin ekranda binlik ayraçla gösterilmesi. Yalnızca görünümü etkiler;
/// saklanan ve dışa aktarılan değer her zaman kullanıcının yazdığı metindir.
library;

import '../models/tabel_model.dart';

final _plainNumber = RegExp(r'^([+-]?)(\d+)(?:[.,](\d+))?$');

/// Ekranda ayraç gösterilen sütunlar: miktarlar evet, sıra numarası ve metin
/// hayır — metin sütununa yazılmış bir posta kodu bozulmasın.
bool showsGroupedNumbers(ColumnModel column) =>
    column.isEffectivelyNumeric && !column.isAutoNumber;

/// Bir sayının ekrandaki hâli ve girdideki her karakterin orada nereye
/// düştüğü. Kullanıcının yazdığı metinde bulunan bir eşleşme, ekrandaki
/// ayraçlı metinde doğru yere vurgulanabilsin diye.
class GroupedNumber {
  final String text;
  final List<int> _starts;
  final List<int> _ends;

  const GroupedNumber(this.text, this._starts, this._ends);

  /// Girdinin [start]..[end) aralığını gösteren, [text] içindeki aralık.
  /// Araya giren binlik ayracı da kapsar: "35000" içinde "5000", ekranda
  /// "5.000" olarak işaretlenir.
  (int, int)? spanOf(int start, int end) {
    if (start < 0 || end > _ends.length || start >= end) return null;
    return (_starts[start], _ends[end - 1]);
  }
}

/// Düz bir sayıyı binlik ayraçla yazar: 12000 → 12.000 (tr) / 12,000 (en).
/// Ondalıklar yazıldığı gibi kalır, yuvarlanmaz. "12 kg" ya da zaten ayraçlı
/// "12.000,5" gibi düz sayı olmayan değerlerde null döner; hücre olduğu gibi
/// gösterilir. Nokta da virgül de ondalık sayılır, uygulamanın toplamlarıyla
/// aynı yorum.
GroupedNumber? groupNumberForDisplay(String raw, {required String language}) {
  final trimmed = raw.trim();
  final match = _plainNumber.firstMatch(trimmed);
  if (match == null) return null;
  final tr = language != 'en';
  final sign = match[1]!;
  final whole = match[2]!;
  final fraction = match[3];

  final out = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  void emit(String piece) {
    starts.add(out.length);
    out.write(piece);
    ends.add(out.length);
  }

  // A leading "+" is dropped, so it maps onto an empty span of its own.
  if (sign.isNotEmpty) emit(sign == '-' ? '-' : '');
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(tr ? '.' : ',');
    emit(whole[i]);
  }
  if (fraction != null) {
    emit(tr ? ',' : '.');
    for (var i = 0; i < fraction.length; i++) {
      emit(fraction[i]);
    }
  }
  return GroupedNumber(out.toString(), starts, ends);
}

String? formatNumericCell(String raw, {required String language}) =>
    groupNumberForDisplay(raw, language: language)?.text;

/// Ekranda ayraçlı görünen bir hücrenin aranabilir bütün yazılışları: hem
/// "35.000" hem "35,000", ondalıklıysa ayraçsız "1234,5" ve "1234.5" de.
/// Ham hâline zaten çağıran tarafta bakılır.
Iterable<String> groupedSearchForms(String raw) sync* {
  final trimmed = raw.trim();
  final match = _plainNumber.firstMatch(trimmed);
  if (match == null) return;
  final seen = <String>{trimmed};
  for (final form in [
    formatNumericCell(trimmed, language: 'tr'),
    formatNumericCell(trimmed, language: 'en'),
    // Ungrouped, with the other decimal mark: what someone types when they
    // skip the thousands separator but keep their own decimal comma.
    if (match[3] != null) ...[
      '${match[1]}${match[2]},${match[3]}',
      '${match[1]}${match[2]}.${match[3]}',
    ],
  ]) {
    if (form != null && seen.add(form)) yield form;
  }
}

/// Aramanın vurgulayacağı aralık, her zaman ekrandaki metin ([shown])
/// üzerinde. Sorgu sırayla ekrandaki metinde, kullanıcının yazdığı ham
/// metinde ve ayraçsız ondalık yazılışlarında aranır; hangisi tutarsa konum
/// ekrandaki metne çevrilir.
(int, int)? highlightSpanIn({
  required String raw,
  required String shown,
  required String query,
  required String language,
}) {
  if (query.isEmpty) return null;
  final needle = query.toLowerCase();

  final direct = shown.toLowerCase().indexOf(needle);
  if (direct >= 0) return (direct, direct + needle.length);

  final grouped = groupNumberForDisplay(raw, language: language);
  if (grouped == null || grouped.text != shown) return null;

  final trimmed = raw.trim();
  final plain = trimmed.toLowerCase().indexOf(needle);
  if (plain >= 0) return grouped.spanOf(plain, plain + needle.length);

  // The ungrouped forms have one character per character of the raw text, so
  // a position found in them is a position in the raw text.
  final match = _plainNumber.firstMatch(trimmed);
  if (match == null || match[3] == null) return null;
  for (final mark in ['.', ',']) {
    final form = '${match[1]}${match[2]}$mark${match[3]}';
    final hit = form.toLowerCase().indexOf(needle);
    if (hit >= 0) return grouped.spanOf(hit, hit + needle.length);
  }
  return null;
}

/// A computed number, grouped and with the locale's decimal mark:
/// 1.234.567,5 (tr) / 1,234,567.5 (en). Totals everywhere in the app — the
/// totals box, the overview, the widget and the PDF — go through this.
String formatGroupedNumber(double value, String language) {
  if (!value.isFinite) return '—';
  final raw = value.abs() >= 1e12
      ? value.toStringAsPrecision(6)
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  final tr = language != 'en';
  // Very large values fall back to exponent form, which must not be grouped.
  if (raw.contains('e') || raw.contains('E')) {
    return tr ? raw.replaceAll('.', ',') : raw;
  }
  final negative = raw.startsWith('-');
  final body = negative ? raw.substring(1) : raw;
  final point = body.indexOf('.');
  final whole = point < 0 ? body : body.substring(0, point);
  final result = StringBuffer(negative ? '-' : '');
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) result.write(tr ? '.' : ',');
    result.write(whole[i]);
  }
  if (point >= 0) {
    result.write(tr ? ',' : '.');
    result.write(body.substring(point + 1));
  }
  return result.toString();
}
