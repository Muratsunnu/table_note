import '../l10n/app_localizations.dart';
import '../models/tabel_model.dart';

/// Sutun tipi secilince ada yazilacak oneri.
///
/// Yalnizca adi kendiliginden belli olan tiplerde oneri var. "Sabit deger"
/// ya da "formul" bir sutun ADI degil, bir davranis; onlara ad onermek
/// kullaniciyi yanlis yonlendirirdi.
String? suggestedColumnName(ColumnType type, AppLocalizations loc) =>
    switch (type) {
      ColumnType.date => loc.columnNameDate,
      ColumnType.time => loc.columnNameTime,
      ColumnType.autoNumber => loc.columnNameOrder,
      _ => null,
    };

bool _isSuggestion(String name, AppLocalizations loc) {
  final lower = name.toLowerCase();
  return lower == loc.columnNameDate.toLowerCase() ||
      lower == loc.columnNameTime.toLowerCase() ||
      lower == loc.columnNameOrder.toLowerCase();
}

/// Tip degisince ad guncellenmeli mi? Guncellenecekse yeni adi, yoksa null
/// doner.
///
/// Kullanicinin kendi yazdigi ad asla ezilmez. Ad bossa doldurulur; ad baska
/// bir tipin onerisiyse degistirilir, cunku "tarih" adli bir sutunu saate
/// cevirmek adi oldugu gibi birakirsa ad yaniltici hale gelir.
String? renamedForType(String current, ColumnType type, AppLocalizations loc) {
  final suggestion = suggestedColumnName(type, loc);
  if (suggestion == null) return null;
  final trimmed = current.trim();
  if (trimmed.isNotEmpty && !_isSuggestion(trimmed, loc)) return null;
  if (trimmed == suggestion) return null;
  return suggestion;
}
