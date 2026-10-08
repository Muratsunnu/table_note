import 'package:in_app_purchase/in_app_purchase.dart';

/// Premium'un ödeme dönemi.
enum PlanPeriod { yearly, monthly }

/// Mağazanın bir Premium paketi için söyledikleri.
///
/// Fiyat ve deneme süresi uygulamada yazılı değildir; ikisi de mağazadan
/// gelir. Fiyat ülkeye ve zamana göre değişir, mağazada değiştirildiğinde
/// uygulamanın güncellenmesi gerekmez. Kullanıcıya gösterilen ile mağazanın
/// tahsil ettiği de böylece hiç ayrışmaz.
class PlanOffer {
  const PlanOffer({
    required this.period,
    required this.product,
    required this.price,
    required this.rawPrice,
    this.trialDays,
  });

  final PlanPeriod period;

  /// Satın almada mağazaya verilecek ürün. Android'de seçilen teklifi
  /// (örneğin ücretsiz denemeli olanı) de taşır.
  final ProductDetails product;

  /// Mağazanın kendi biçimiyle yazdığı, her dönem yinelenen fiyat.
  final String price;

  /// Aynı fiyatın sayı hali; yalnızca paketleri birbiriyle kıyaslamak için.
  final double rawPrice;

  /// Mağaza bu kullanıcıya ücretsiz deneme veriyorsa kaç gün.
  final int? trialDays;
}

/// Bir abonelik teklifinin ödeme aşaması: önce (varsa) ücretsiz ya da
/// indirimli dönem, en sonda süresiz yinelenen asıl fiyat.
class PlanPhase {
  const PlanPhase({
    required this.formattedPrice,
    required this.priceMicros,
    required this.billingPeriod,
    this.cycles = 1,
  });

  final String formattedPrice;
  final int priceMicros;

  /// ISO 8601 süre: "P1W", "P1M", "P1Y".
  final String billingPeriod;

  /// Bu aşamanın kaç kez yinelendiği.
  final int cycles;
}

/// Aşamalardan fiyatı ve deneme süresini çıkarır.
///
/// Mağaza ücretsiz denemeli bir teklifi ilk aşaması bedava olan bir dizi
/// olarak verir. Gösterilecek fiyat ilk aşamanınki değil ("Ücretsiz"),
/// son aşamanınkidir.
({String price, double rawPrice, int? trialDays})? readPlanPhases(
  List<PlanPhase> phases,
) {
  if (phases.isEmpty) return null;
  final recurring = phases.last;
  var trialDays = 0;
  for (final phase in phases.take(phases.length - 1)) {
    if (phase.priceMicros != 0) continue;
    final days = isoPeriodDays(phase.billingPeriod);
    if (days != null) trialDays += days * (phase.cycles < 1 ? 1 : phase.cycles);
  }
  return (
    price: recurring.formattedPrice,
    rawPrice: recurring.priceMicros / 1000000,
    trialDays: trialDays > 0 ? trialDays : null,
  );
}

/// "P1W" → 7, "P3D" → 3, "P1M" → 30, "P1Y" → 365. Tanınmayan süre null.
int? isoPeriodDays(String period) {
  final match = RegExp(
    r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$',
  ).firstMatch(period.trim().toUpperCase());
  if (match == null) return null;
  int part(int group) => int.tryParse(match.group(group) ?? '') ?? 0;
  final days = part(1) * 365 + part(2) * 30 + part(3) * 7 + part(4);
  return days > 0 ? days : null;
}

/// Yıllık paketin, aynı süreyi aylık ödemeye göre yüzde kaç ucuz olduğu.
/// Ucuz değilse ya da hesaplanamıyorsa null: olmayan bir indirim yazılmaz.
int? yearlySavingPercent({required double yearly, required double monthly}) {
  final twelveMonths = monthly * 12;
  if (yearly <= 0 || twelveMonths <= 0 || yearly >= twelveMonths) return null;
  final percent = ((1 - yearly / twelveMonths) * 100).round();
  return percent > 0 ? percent : null;
}
