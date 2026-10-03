import 'app_localizations.dart';

/// Copy shared by the simplified forms and table controls.
extension UxLocalizations on AppLocalizations {
  bool get _english => locale.languageCode == 'en';

  String get switchTable => _english ? 'Switch table' : 'Tablo değiştir';
  String get todayShort => _english ? 'Today' : 'Bugün';
  String get savingProgress => _english ? 'Saving…' : 'Kaydediliyor…';
  String get clear => _english ? 'Clear' : 'Temizle';
  String get advancedSettings =>
      _english ? 'Type and advanced settings' : 'Tür ve gelişmiş ayarlar';
  String get hideAdvancedSettings =>
      _english ? 'Hide settings' : 'Ayarları gizle';
  String get draftRestored => _english
      ? 'Your unfinished draft has been restored.'
      : 'Yarım kalan taslağın geri getirildi.';
  String get draftSavedLocally => _english
      ? 'Your draft is kept on this device.'
      : 'Taslağın bu cihazda saklanır.';
  String get draftSaved => draftSavedLocally;
  String get discardDraft => _english ? 'Discard draft' : 'Taslağı sil';
  String get draftSaveFailed => _english
      ? 'Could not save the draft. Keep this screen open and try again.'
      : 'Taslak saklanamadı. Bu ekranı açık tutup yeniden dene.';
  String get voiceStepSpeak => _english ? 'Speak' : 'Konuş';
  String get voiceStepReview => _english ? 'Review' : 'Kontrol et';
  String get voiceStepAdd => _english ? 'Add' : 'Ekle';
  String get voiceInstructions => _english
      ? 'Say the column name, then its value.'
      : 'Önce sütun adını, ardından değerini söyle.';
  String voiceExampleFor(String sentence) =>
      _english ? 'For example: “$sentence”' : 'Örneğin: “$sentence”';
  String get voiceExampleValue => _english ? 'example' : 'örnek';
  String get voiceNoEditableColumns => _english
      ? 'These fields are filled automatically. Review them before adding.'
      : 'Bu alanlar otomatik doldurulur. Eklemeden önce kontrol et.';
  String get voicePermissionDenied => _english
      ? 'Allow microphone and speech access in device settings, or enter the values below.'
      : 'Cihaz ayarlarından mikrofon ve konuşma iznini aç veya değerleri aşağıya yaz.';
  String get voiceServiceUnavailable => _english
      ? 'Offline speech is unavailable for this language on this device. Check your device’s speech language settings or enter the values below.'
      : 'Bu cihazda seçilen dil için çevrimdışı konuşma kullanılamıyor. Cihazın konuşma dili ayarlarını kontrol et veya değerleri aşağıya yaz.';
  String get voiceNoSpeech => _english
      ? 'No speech was detected. Try again closer to the microphone.'
      : 'Konuşma duyulmadı. Mikrofona biraz daha yakın konuşarak yeniden dene.';
  String get voiceRecognitionFailed => _english
      ? 'Speech recognition stopped. Try again or enter the values below.'
      : 'Konuşma algılama durdu. Yeniden dene veya değerleri aşağıya yaz.';
  String get voiceTryAgain => _english ? 'Try again' : 'Yeniden dene';
  String get voiceTypeInstead => _english ? 'Enter manually' : 'Yazarak doldur';
  String get voiceReviewHint => _english
      ? 'Review the values, correct anything needed, then confirm.'
      : 'Değerleri kontrol et, gerekiyorsa düzelt ve onayla.';
  String get voiceReadyToReview =>
      _english ? 'Ready to review' : 'Kontrol etmeye hazır';
  String get voiceFilledField =>
      _english ? 'Filled from speech' : 'Konuşmadan dolduruldu';
  String get rowSaveFailed => _english
      ? 'The record could not be saved. Your entries are still here; try again.'
      : 'Kayıt eklenemedi. Yazdıkların burada duruyor; yeniden dene.';
  String get recordChanged => _english
      ? 'This record or its table has changed. Reopen it to continue.'
      : 'Bu kayıt veya tablonun yapısı değişti. Devam etmek için yeniden aç.';
}
