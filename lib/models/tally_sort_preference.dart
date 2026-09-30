/// Bir çetelenin kalıcı sıralama tercihi. Çetele verisinin parçası değildir;
/// sıralamak çeteleyi "değişmiş" saymaz ve bulutla senkronlanmaz.
///
/// Çetelede sıralanabilir iki şey vardır: öğe adı ve bir durumun tarih
/// aralığındaki sayısı ("en çok devamsız" gibi). Durum koduyla tanınır; durum
/// silinirse sıralama sessizce kalkar, başka bir duruma kaymaz.
class TallySortPreference {
  /// Durum kodu; null ise öğe adına göre sıralanır.
  final String? statusCode;
  final bool ascending;

  const TallySortPreference.byName({required this.ascending})
    : statusCode = null;

  const TallySortPreference.byStatus(String code, {required this.ascending})
    : statusCode = code;

  bool get isByName => statusCode == null;

  @override
  bool operator ==(Object other) =>
      other is TallySortPreference &&
      other.statusCode == statusCode &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(statusCode, ascending);

  Map<String, dynamic> toJson() => {
    'by': isByName ? 'name' : 'status',
    if (statusCode != null) 'status': statusCode,
    'ascending': ascending,
  };

  /// Bozuk ya da eski biçimdeki kayıtlar yok sayılır.
  static TallySortPreference? fromJson(Object? json) {
    if (json is! Map) return null;
    final ascending = json['ascending'];
    if (ascending is! bool) return null;
    switch (json['by']) {
      case 'name':
        return TallySortPreference.byName(ascending: ascending);
      case 'status':
        final code = json['status'];
        if (code is! String || code.isEmpty) return null;
        return TallySortPreference.byStatus(code, ascending: ascending);
      default:
        return null;
    }
  }
}
