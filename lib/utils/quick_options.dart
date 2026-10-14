import '../models/tabel_model.dart';

/// Bir değer bir sütuna bundan fazla kez girilince hızlı seçime kendiliğinden
/// eklenir: dördüncü girişten sonra.
const quickOptionThreshold = 3;

/// Kendiliğinden öğrenilen seçeneklerin üst sınırı; en sık girilenler kalır.
/// Yüzlerce farklı müşteri adı olan bir sütunda alan çiplerle dolmasın.
const maxLearnedQuickOptions = 12;

/// Aynı değerin farklı yazılışlarını tek değer sayan karşılaştırma anahtarı:
/// "konya", "Konya" ve "KONYA" aynıdır. Türkçedeki I/ı ve İ/i de tek harfe
/// iner; böylece "ISPARTA" ile "Isparta" da, "ITEM" ile "item" da eşleşir.
/// Yalnızca saymak için kullanılır, ekranda gösterilmez.
String quickOptionKey(String value) => value
    .trim()
    .replaceAll('İ', 'i')
    .replaceAll('I', 'i')
    .replaceAll('ı', 'i')
    .toLowerCase();

/// Bir sütunun hızlı seçim seçenekleri.
///
/// Tabloya [quickOptionThreshold]'dan fazla kez girilmiş değerlerden oluşur.
/// Elle liste tanımlama kaldırıldı; eski sürümde tanımlanmış listeler
/// kaybolmasın diye öneri olarak görünmeye devam eder ve × ile kaldırılabilir. Sayısal sütunlarda öğrenme yoktur: rakamlar tekrar etse de
/// seçenek olarak anlamlı değildir.
///
/// Büyük küçük harf ayrımı yapılmaz; çipte en çok kullanılan yazılış görünür.
///
/// [dismissed], kullanıcının ×'e basarak kaldırdığı seçenekleri
/// ([quickOptionKey] ile), kaldırıldığı andaki giriş sayısıyla tutar. Kaldırılan seçenek o andan sonra yeniden
/// [quickOptionThreshold]'dan fazla kez girilirse geri gelir.
List<String> quickOptionsFor(
  TableModel table,
  int columnIndex, {
  Map<String, int> dismissed = const {},
}) {
  if (columnIndex < 0 || columnIndex >= table.columns.length) return const [];
  final column = table.columns[columnIndex];
  // Tarih, saat, sabit, formül ve sıra numarası kendiliğinden dolar.
  if (!column.isNormal) return const [];

  // Anahtar başına toplam giriş ve her yazılışın kaç kez kullanıldığı.
  final counts = <String, int>{};
  final spellings = <String, Map<String, int>>{};
  for (final row in table.rows) {
    if (columnIndex >= row.length) continue;
    final value = row[columnIndex].trim();
    if (value.isEmpty) continue;
    final key = quickOptionKey(value);
    counts[key] = (counts[key] ?? 0) + 1;
    final forms = spellings[key] ??= {};
    forms[value] = (forms[value] ?? 0) + 1;
  }

  bool visible(String key) {
    final dismissedAt = dismissed[key];
    if (dismissedAt == null) return true;
    return (counts[key] ?? 0) - dismissedAt > quickOptionThreshold;
  }

  // Elle tanımlananlar kendi yazılışlarıyla kalır.
  final manual = <String, String>{};
  for (final option in column.autoFillOptions) {
    final value = option.trim();
    if (value.isEmpty) continue;
    manual.putIfAbsent(quickOptionKey(value), () => value);
  }

  final learned = <String>[];
  if (!column.isNumeric) {
    // Map giriş sırasını korur; eşit sayıda girilenler ilk girilene göre dizilir.
    final frequent =
        counts.entries
            .where(
              (entry) =>
                  entry.value > quickOptionThreshold &&
                  !manual.containsKey(entry.key),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in frequent.where((entry) => visible(entry.key))) {
      if (learned.length == maxLearnedQuickOptions) break;
      // En çok kullanılan yazılış; eşitlikte ilk yazılan.
      final forms = spellings[entry.key]!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      learned.add(forms.first.key);
    }
  }

  return [
    for (final entry in manual.entries)
      if (visible(entry.key)) entry.value,
    ...learned,
  ];
}
