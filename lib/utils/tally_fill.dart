import 'dart:math' as math;

/// Çetelede dolu bir günü basılı tutup kaydırarak yan günleri doldurmanın
/// hesapları. Ekrandan ayrı durur; testler doğrudan çağırır.

/// Gün şeridinin solundan [dx] uzaklıktaki günün sırası. Şeridin dışına
/// taşan parmak ilk ya da son günde kalır.
int tallyDayAt(double dx, {required double dayWidth, required int dayCount}) {
  if (dayCount <= 0) return 0;
  return (dx / dayWidth).floor().clamp(0, dayCount - 1);
}

/// Parmak görünen gün alanının kenarına yaklaştıkça tablonun bir karede
/// kayacağı piksel: solda eksi, sağda artı, ortada sıfır. Kenara ne kadar
/// yakınsa (ya da dışına ne kadar taşmışsa) o kadar hızlı.
double tallyAutoScrollStep(
  double x,
  double viewportWidth, {
  double edge = 44,
  double minStep = 2,
  double maxStep = 14,
}) {
  final zone = math.min(edge, viewportWidth / 4);
  if (zone <= 0) return 0;
  final double depth;
  if (x < zone) {
    depth = -(zone - x) / zone;
  } else if (x > viewportWidth - zone) {
    depth = (x - (viewportWidth - zone)) / zone;
  } else {
    return 0;
  }
  final strength = depth.abs().clamp(0.0, 1.0);
  return depth.sign * (minStep + (maxStep - minStep) * strength);
}

/// Süren bir doldurma: hangi kayıtta, hangi günden parmağın olduğu güne.
class TallyFill {
  TallyFill({required this.itemIndex, required this.anchor, required this.code})
    : current = anchor;

  final int itemIndex;

  /// Basılı tutulan gün; durumu zaten [code].
  final int anchor;
  final String code;

  /// Parmağın şu an üstünde olduğu gün.
  int current;

  int get first => math.min(anchor, current);
  int get last => math.max(anchor, current);

  /// Parmak başladığı günden hiç ayrılmadıysa yazılacak bir şey yok.
  bool get isEmpty => anchor == current;

  /// Önizlemede soluk renkle görünecek gün: başlanan gün dışında aralıktakiler.
  bool previews(int itemIndex, int day) =>
      itemIndex == this.itemIndex &&
      day != anchor &&
      day >= first &&
      day <= last;
}
