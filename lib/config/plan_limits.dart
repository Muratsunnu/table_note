/// Ücretsiz kullanımın sınırları.
///
/// Sınır yalnızca yeni bir şey OLUŞTURMAYI durdurur. Elde olan tablo, çetele
/// ve şablonlar her zaman açılır ve düzenlenir: Premium'u biten ya da sınırı
/// aşmış halde güncelleyen kimsenin verisi kilitlenmez.
///
/// İki durum sınıra sayılmaz:
///  * Kodla katılınan tablolar. Davet edilen kişi sınıra takılıp giremezse
///    bunun bedelini davet eden, yani ödeme yapan kişi öder.
///  * Sınırlar gelmeden önceki sürümden gelen kullanıcılar. O sürümde hiçbir
///    sınır yoktu; güncellemeyle ellerinden bir şey alınmaz.
class PlanLimits {
  PlanLimits._();

  static const int freeTables = 5;
  static const int freeTallies = 5;
  static const int freeTemplates = 3;
}
