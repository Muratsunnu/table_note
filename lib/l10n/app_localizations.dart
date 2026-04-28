import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'tr': _tr,
    'en': _en,
  };

  String _t(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['tr']?[key] ??
        key;
  }

  // ============== GENEL ==============
  String get appTitle => _t('appTitle');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get close => _t('close');
  String get create => _t('create');
  String get add => _t('add');
  String get update => _t('update');
  String get yes => _t('yes');
  String get no => _t('no');
  String get error => _t('error');
  String get success => _t('success');
  String get search => _t('search');
  String get filter => _t('filter');
  String get settings => _t('settings');
  String get language => _t('language');
  String get turkish => _t('turkish');
  String get english => _t('english');
  String get languageSettings => _t('languageSettings');
  String get selectLanguage => _t('selectLanguage');
  String get menu => _t('menu');

  // ============== TABLE SCREEN ==============
  String get tableNote => _t('tableNote');
  String get findTable => _t('findTable');
  String get exportData => _t('exportData');
  String get newTable => _t('newTable');
  String get templates => _t('templates');
  String get addRecord => _t('addRecord');
  String get searchInTable => _t('searchInTable');
  String nRecords(int n) => _t('nRecords').replaceAll('{n}', n.toString());
  String nColumns(int n) => _t('nColumns').replaceAll('{n}', n.toString());
  String recordsAndColumns(int r, int c) => '${nRecords(r)} • ${nColumns(c)}';

  // ============== EMPTY STATE ==============
  String get welcome => _t('welcome');
  String get createFirstTable => _t('createFirstTable');
  String get createTable => _t('createTable');
  String get orSelectFromTemplates => _t('orSelectFromTemplates');

  // ============== CREATE TABLE ==============
  String get createNewTable => _t('createNewTable');
  String get manualCreate => _t('manualCreate');
  String get createFromTemplate => _t('createFromTemplate');
  String get tableName => _t('tableName');
  String get tableNameHint => _t('tableNameHint');
  String get columns => _t('columns');
  String get help => _t('help');
  String columnN(int n) => _t('columnN').replaceAll('{n}', n.toString());
  String get columnName => _t('columnName');
  String get addColumn => _t('addColumn');
  String get deleteColumn => _t('deleteColumn');
  String get tableNameEmpty => _t('tableNameEmpty');
  String get atLeastOneColumn => _t('atLeastOneColumn');
  String formulaRequired(String n) => _t('formulaRequired').replaceAll('{name}', n);
  String defaultValueRequired(String n) => _t('defaultValueRequired').replaceAll('{name}', n);
  String get tableCreateFailed => _t('tableCreateFailed');
  String get noTemplatesYet => _t('noTemplatesYet');
  String get createTableFromTemplate => _t('createTableFromTemplate');

  // ============== COLUMN TYPES ==============
  String get columnType => _t('columnType');
  String get normal => _t('normal');
  String get constantValue => _t('constantValue');
  String get formula => _t('formula');
  String get date => _t('date');
  String get time => _t('time');
  String get autoNumber => _t('autoNumber');
  String get numericColumn => _t('numericColumn');
  String get numericColumnDesc => _t('numericColumnDesc');
  String get manualInput => _t('manualInput');
  String get defaultValueComes => _t('defaultValueComes');
  String get autoCalculated => _t('autoCalculated');
  String get todaysDateAuto => _t('todaysDateAuto');
  String get currentTimeAuto => _t('currentTimeAuto');
  String get autoIncrement => _t('autoIncrement');

  // ============== COLUMN SETTINGS ==============
  String get quickSelectionList => _t('quickSelectionList');
  String get quickSelectionHint => _t('quickSelectionHint');
  String get addQuickSelectionList => _t('addQuickSelectionList');
  String get defaultValue => _t('defaultValue');
  String get defaultValueHint => _t('defaultValueHint');
  String get defaultValueInfo => _t('defaultValueInfo');
  String get formulaAutoCalcInfo => _t('formulaAutoCalcInfo');
  String get formulaHint => _t('formulaHint');
  String get operationsHint => _t('operationsHint');
  String get clickToAddColumn => _t('clickToAddColumn');
  String get addOperation => _t('addOperation');
  String get autoDate => _t('autoDate');
  String get autoDateDesc => _t('autoDateDesc');
  String get autoTime => _t('autoTime');
  String get autoTimeDesc => _t('autoTimeDesc');
  String get autoNumberTitle => _t('autoNumberTitle');
  String get autoNumberDesc => _t('autoNumberDesc');
  String example(String v) => _t('example').replaceAll('{val}', v);

  // ============== HELP DIALOG ==============
  String get columnTypes => _t('columnTypes');
  String get normalColumn => _t('normalColumn');
  String get normalColumnDesc => _t('normalColumnDesc');
  String get constantColumnTitle => _t('constantColumnTitle');
  String get constantColumnDesc => _t('constantColumnDesc');
  String get formulaColumnTitle => _t('formulaColumnTitle');
  String get formulaColumnDesc => _t('formulaColumnDesc');
  String get exampleFormulas => _t('exampleFormulas');
  String get multiplyKgPrice => _t('multiplyKgPrice');
  String get priceVat => _t('priceVat');
  String get netWeight => _t('netWeight');
  String get understood => _t('understood');

  // ============== OPERATORS ==============
  String get addition => _t('addition');
  String get subtraction => _t('subtraction');
  String get multiplication => _t('multiplication');
  String get division => _t('division');
  String get percentage => _t('percentage');
  String get openParen => _t('openParen');
  String get closeParen => _t('closeParen');

  // ============== ADD/EDIT ROW ==============
  String get addNewRecord => _t('addNewRecord');
  String get calculating => _t('calculating');
  String get formulaLabel => _t('formulaLabel');
  String get quickSelect => _t('quickSelect');
  String get today => _t('today');
  String get selectDate => _t('selectDate');
  String get now => _t('now');
  String get selectTime => _t('selectTime');
  String get todaysDateAutoSet => _t('todaysDateAutoSet');
  String get currentTimeAutoSet => _t('currentTimeAutoSet');
  String get addFailed => _t('addFailed');
  String get orderNo => _t('orderNo');
  String get autoLabel => _t('autoLabel');
  String recordN(int n) => _t('recordN').replaceAll('{n}', n.toString());
  String get updateFailed => _t('updateFailed');

  // ============== TABLE LIST ==============
  String get noResults => _t('noResults');
  String noMatchingRecord(String q) => _t('noMatchingRecord').replaceAll('{query}', q);
  String get tableEmpty => _t('tableEmpty');
  String get tapToAddFirst => _t('tapToAddFirst');
  String get deleteRecord => _t('deleteRecord');
  String get deleteRecordConfirm => _t('deleteRecordConfirm');

  // ============== COLUMN SUMS ==============
  String get filteredTotals => _t('filteredTotals');
  String get totals => _t('totals');
  String searchOf(String q) => _t('searchOf').replaceAll('{query}', q);
  String get record => _t('record');

  // ============== DRAWER ==============
  String get myTables => _t('myTables');
  String get selectOrCreateTable => _t('selectOrCreateTable');
  String get noTablesYet => _t('noTablesYet');
  String get createYourFirstTable => _t('createYourFirstTable');
  String get switchToTable => _t('switchToTable');
  String get editStructure => _t('editStructure');
  String get deleteTable => _t('deleteTable');
  String deleteTableConfirm(String n) => _t('deleteTableConfirm').replaceAll('{name}', n);
  String nRecordsPermanentDelete(int n) => _t('nRecordsPermanentDelete').replaceAll('{n}', n.toString());

  // ============== SEARCH DIALOG ==============
  String get searchTable => _t('searchTable');
  String get typeTableName => _t('typeTableName');
  String get noTablesCreated => _t('noTablesCreated');
  String get createYourFirst => _t('createYourFirst');
  String noMatchingTable(String q) => _t('noMatchingTable').replaceAll('{query}', q);
  String get active => _t('active');
  String totalNTables(int n) => _t('totalNTables').replaceAll('{n}', n.toString());
  String showingNofM(int n, int m) => _t('showingNofM').replaceAll('{n}', n.toString()).replaceAll('{m}', m.toString());

  // ============== EXPORT ==============
  String get exportTitle => _t('exportTitle');
  String get selectFormat => _t('selectFormat');
  String get csvDesc => _t('csvDesc');
  String get pdfDesc => _t('pdfDesc');
  String fileCreated(String f) => _t('fileCreated').replaceAll('{format}', f);
  String get shareWhatsApp => _t('shareWhatsApp');
  String get saveToDevice => _t('saveToDevice');
  String get selectAnotherFormat => _t('selectAnotherFormat');
  String get creatingFile => _t('creatingFile');
  String fileSaved(String n) => _t('fileSaved').replaceAll('{name}', n);
  String get fileSaveFailed => _t('fileSaveFailed');
  String get tableData => _t('tableData');

  // ============== TABLE SELECTOR ==============
  String get selectTable => _t('selectTable');
  String deleteTableConfirmFull(String n) => _t('deleteTableConfirmFull').replaceAll('{name}', n);

  // ============== TEMPLATE MANAGEMENT ==============
  String get tableTemplates => _t('tableTemplates');
  String get searchTemplate => _t('searchTemplate');
  String get closeSearch => _t('closeSearch');
  String get typeTemplateName => _t('typeTemplateName');
  String get noTemplatesCreated => _t('noTemplatesCreated');
  String get saveFrequentStructures => _t('saveFrequentStructures');
  String get createNewTemplate => _t('createNewTemplate');
  String showingTemplates(int n, int m) => _t('showingTemplates').replaceAll('{n}', n.toString()).replaceAll('{m}', m.toString());
  String get deleteTemplate => _t('deleteTemplate');
  String deleteTemplateConfirm(String n) => _t('deleteTemplateConfirm').replaceAll('{name}', n);
  String get columnsLabel => _t('columnsLabel');

  // ============== CREATE/EDIT TEMPLATE ==============
  String get createNewTemplateTitle => _t('createNewTemplateTitle');
  String get templateName => _t('templateName');
  String get templateNameHint => _t('templateNameHint');
  String get templateCreate => _t('templateCreate');
  String get templateNameEmpty => _t('templateNameEmpty');
  String get templateCreateFailed => _t('templateCreateFailed');
  String get editTemplate => _t('editTemplate');
  String get templateNameEmptyError => _t('templateNameEmptyError');
  String columnNameEmpty(int n) => _t('columnNameEmpty').replaceAll('{n}', n.toString());
  String get templateUpdated => _t('templateUpdated');
  String get templateUpdateFailed => _t('templateUpdateFailed');

  // ============== EDIT TABLE STRUCTURE ==============
  String get editTableStructure => _t('editTableStructure');
  String get newColumn => _t('newColumn');
  String get newBadge => _t('newBadge');
  String get removeColumn => _t('removeColumn');
  String get columnNameLabel => _t('columnNameLabel');
  String typeName(String n) => _t('typeName').replaceAll('{name}', n);
  String get cannotChange => _t('cannotChange');
  String get tableStructureUpdated => _t('tableStructureUpdated');
  String get tableUpdateError => _t('tableUpdateError');
  String get constant => _t('constant');

  // ============== PDF ==============
  String totalNRecords(int n) => _t('totalNRecords').replaceAll('{n}', n.toString());
  String get totalsLabel => _t('totalsLabel');
  String pageNofM(int n, int m) => _t('pageNofM').replaceAll('{n}', n.toString()).replaceAll('{m}', m.toString());

  // ============== MISC ==============
  String get autoNumberDescShort => _t('autoNumberDescShort');
  String get dateAutoDescShort => _t('dateAutoDescShort');
  String get timeAutoDescShort => _t('timeAutoDescShort');
  String get quickSelectionListOptional => _t('quickSelectionListOptional');
  String get quickSelectionHintShort => _t('quickSelectionHintShort');
  String get quickSelectionAdd => _t('quickSelectionAdd');
  String get addColumnLabel => _t('addColumnLabel');


  // ============== TALLY ==============
  String get tallyTable => _t('tallyTable');
  String get tallyEmptyTitle => _t('tallyEmptyTitle');
  String get tallyEmptySubtitle => _t('tallyEmptySubtitle');
  String get tallyItems => _t('tallyItems');
  String get tallyDays => _t('tallyDays');
  String get tallySearchHint => _t('tallySearchHint');
  String get tallyAddItemHint => _t('tallyAddItemHint');
  String get tallyAddItem => _t('tallyAddItem');
  String get tallyItemName => _t('tallyItemName');
  String get tallyClear => _t('tallyClear');
  String get tallySummary => _t('tallySummary');
  String get tallyRenameItem => _t('tallyRenameItem');
  String get tallyDeleteItem => _t('tallyDeleteItem');
  String tallyDeleteItemConfirm(String name) => _t('tallyDeleteItemConfirm').replaceAll('{name}', name);
  String get tallyTotalDays => _t('tallyTotalDays');
  String get tallyEmpty => _t('tallyEmpty');
  String get tallyNameHint => _t('tallyNameHint');
  String get tallyDateRange => _t('tallyDateRange');
  String get tallyStartDate => _t('tallyStartDate');
  String get tallyEndDate => _t('tallyEndDate');
  String get tallyStatuses => _t('tallyStatuses');
  String get tallyAddStatus => _t('tallyAddStatus');
  String get tallyCreate => _t('tallyCreate');
  String get tallyLabel => _t('tallyLabel');
  String get tallyFullName => _t('tallyFullName');
  String get tallyFullNameHint => _t('tallyFullNameHint');
  String get tallySelectColor => _t('tallySelectColor');
  String get tallyAtLeastOneStatus => _t('tallyAtLeastOneStatus');
  String get tallyTab => _t('tallyTab');
  String get tallySwitch => _t('tallySwitch');
  String get tallyDeleteTable => _t('tallyDeleteTable');
  String get tallyTableName => _t('tallyTableName');
  String get tallyTableNameHint => _t('tallyTableNameHint');
  String get tallyAddStatusHint => _t('tallyAddStatusHint');
  String get tallyCode => _t('tallyCode');
  String get tallyStatusLabel => _t('tallyStatusLabel');
  String get tallyPickColor => _t('tallyPickColor');
  String get tallyNameRequired => _t('tallyNameRequired');
  String get tallyDateError => _t('tallyDateError');
  String get tallyStatusRequired => _t('tallyStatusRequired');
  String get tallyCodeRequired => _t('tallyCodeRequired');
  String get tallyCreateFailed => _t('tallyCreateFailed');
  String get tallyItemsLabel => _t('tallyItemsLabel');
  String get tallyItem => _t('tallyItem');
  String get tallyItemNameHint => _t('tallyItemNameHint');
  String get tallyNoItems => _t('tallyNoItems');
  String get tallyItemHeader => _t('tallyItemHeader');

  // ============== TÜRKÇE ==============
  static const Map<String, String> _tr = {
    'appTitle': 'Table Note',
    'cancel': 'İptal',
    'save': 'Kaydet',
    'delete': 'Sil',
    'edit': 'Düzenle',
    'close': 'Kapat',
    'create': 'Oluştur',
    'add': 'Ekle',
    'update': 'Güncelle',
    'yes': 'Evet',
    'no': 'Hayır',
    'error': 'Hata',
    'success': 'Başarılı',
    'search': 'Ara',
    'filter': 'Filtre',
    'settings': 'Ayarlar',
    'language': 'Dil',
    'turkish': 'Türkçe',
    'english': 'English',
    'languageSettings': 'Dil Ayarları',
    'selectLanguage': 'Dil Seçin',
    'menu': 'Menü',
    'tableNote': 'Table Note',
    'findTable': 'Tablo Bul',
    'exportData': 'Çıktı Al',
    'newTable': 'Yeni Tablo',
    'templates': 'Şablonlar',
    'addRecord': 'Kayıt Ekle',
    'searchInTable': 'Tabloda ara...',
    'nRecords': '{n} kayıt',
    'nColumns': '{n} sütun',
    'welcome': 'Hoş Geldiniz!',
    'createFirstTable': 'Verilerinizi düzenlemek için\nilk tablonuzu oluşturun',
    'createTable': 'Tablo Oluştur',
    'orSelectFromTemplates': 'veya Şablonlardan Seç',
    'createNewTable': 'Yeni Tablo Oluştur',
    'manualCreate': 'Manuel Oluştur',
    'createFromTemplate': 'Şablondan Oluştur',
    'tableName': 'Tablo Adı',
    'tableNameHint': 'Örn: Sefer Kayıtları',
    'columns': 'Sütunlar',
    'help': 'Yardım',
    'columnN': 'Sütun {n}',
    'columnName': 'Sütun adı',
    'addColumn': 'Sütun Ekle',
    'deleteColumn': 'Sütunu Sil',
    'tableNameEmpty': 'Tablo adı boş olamaz',
    'atLeastOneColumn': 'En az bir sütun eklemelisiniz',
    'formulaRequired': '{name} sütunu için formül girilmeli',
    'defaultValueRequired': '{name} sütunu için varsayılan değer girilmeli',
    'tableCreateFailed': 'Tablo oluşturulamadı',
    'noTemplatesYet': 'Henüz şablon yok',
    'createTableFromTemplate': 'Şablondan Tablo Oluştur',
    'columnType': 'Sütun Tipi:',
    'normal': 'Normal',
    'constantValue': 'Sabit Değer',
    'formula': 'Formül',
    'date': 'Tarih',
    'time': 'Saat',
    'autoNumber': 'Sıra No',
    'numericColumn': 'Sayısal Sütun',
    'numericColumnDesc': 'Bu sütundaki değerler toplanabilir',
    'manualInput': 'Manuel veri girişi',
    'defaultValueComes': 'Varsayılan değer gelir',
    'autoCalculated': 'Otomatik hesaplanır',
    'todaysDateAuto': 'Bugünün tarihi otomatik gelir',
    'currentTimeAuto': 'Şu anki saat otomatik gelir',
    'autoIncrement': 'Otomatik artan numara',
    'quickSelectionList': 'Hızlı Seçim Listesi',
    'quickSelectionHint': 'Virgülle ayırın (örn: İstanbul, Ankara)',
    'addQuickSelectionList': 'Hızlı Seçim Listesi Ekle',
    'defaultValue': 'Varsayılan Değer',
    'defaultValueHint': 'Örn: 0.2',
    'defaultValueInfo': 'Bu değer tüm satırlara varsayılan olarak gelir. Satır bazında değiştirilebilir.',
    'formulaAutoCalcInfo': 'Bu sütun diğer sütunlardan otomatik hesaplanır.',
    'formulaHint': 'Örn: {Kg}*{Birim Fiyat}',
    'operationsHint': 'İşlemler: + - * / % (yüzde)',
    'clickToAddColumn': 'Sütun eklemek için tıklayın:',
    'addOperation': 'İşlem ekle:',
    'autoDate': 'Otomatik Tarih',
    'autoDateDesc': 'Yeni kayıt eklerken bugünün tarihi otomatik gelir.\nİsterseniz değiştirebilirsiniz.',
    'autoTime': 'Otomatik Saat',
    'autoTimeDesc': 'Yeni kayıt eklerken şu anki saat otomatik gelir.\nİsterseniz değiştirebilirsiniz.',
    'autoNumberTitle': 'Otomatik Sıra Numarası',
    'autoNumberDesc': 'Her yeni kayıt için otomatik artan numara atanır.\n1, 2, 3, 4... şeklinde devam eder.',
    'example': 'Örnek: {val}',
    'columnTypes': 'Sütun Tipleri',
    'normalColumn': 'Normal Sütun',
    'normalColumnDesc': 'Manuel veri girişi yapılır. Hızlı seçim listesi eklenebilir.',
    'constantColumnTitle': 'Sabit Değer Sütunu',
    'constantColumnDesc': 'Belirlediğiniz varsayılan değer tüm satırlara otomatik gelir. İsterseniz satır bazında değiştirebilirsiniz.',
    'formulaColumnTitle': 'Formül Sütunu',
    'formulaColumnDesc': "Diğer sütunlardan otomatik hesaplanır. Desteklenen işlemler:\n• + (toplama)\n• - (çıkarma)\n• * (çarpma)\n• / (bölme)\n• % (yüzde: {Fiyat}%18 = Fiyatın %18'i)",
    'exampleFormulas': 'Örnek Formüller:',
    'multiplyKgPrice': 'Kg ile Birim Fiyatı çarp',
    'priceVat': 'Fiyat + KDV',
    'netWeight': 'Net ağırlık',
    'understood': 'Anladım',
    'addition': 'Toplama',
    'subtraction': 'Çıkarma',
    'multiplication': 'Çarpma',
    'division': 'Bölme',
    'percentage': 'Yüzde',
    'openParen': 'Parantez Aç',
    'closeParen': 'Parantez Kapat',
    'addNewRecord': 'Yeni Kayıt Ekle',
    'calculating': 'Hesaplanıyor...',
    'formulaLabel': 'Formül',
    'quickSelect': 'Hızlı Seç',
    'today': 'Bugün',
    'selectDate': 'Tarih Seç',
    'now': 'Şu an',
    'selectTime': 'Saat Seç',
    'todaysDateAutoSet': 'Bugünün tarihi otomatik geldi',
    'currentTimeAutoSet': 'Şu anki saat otomatik geldi',
    'addFailed': 'Kayıt eklenemedi',
    'orderNo': 'Sıra No',
    'autoLabel': 'Otomatik',
    'recordN': 'Kayıt #{n}',
    'updateFailed': 'Kayıt güncellenemedi',
    'noResults': 'Sonuç bulunamadı',
    'noMatchingRecord': '"{query}" ile eşleşen kayıt yok',
    'tableEmpty': 'Tablo boş',
    'tapToAddFirst': 'İlk kaydınızı eklemek için\naşağıdaki butona dokunun',
    'deleteRecord': 'Kaydı Sil',
    'deleteRecordConfirm': 'Bu kaydı silmek istediğinizden emin misiniz?',
    'filteredTotals': 'Filtrelenmiş Toplamlar',
    'totals': 'Toplamlar',
    'searchOf': '"{query}" araması',
    'record': 'kayıt',
    'myTables': 'Tablolarım',
    'selectOrCreateTable': 'Tablo seçin veya yeni oluşturun',
    'noTablesYet': 'Henüz tablo yok',
    'createYourFirstTable': 'İlk tablonuzu oluşturun',
    'switchToTable': 'Tabloya Geç',
    'editStructure': 'Yapıyı Düzenle',
    'deleteTable': 'Tabloyu Sil',
    'deleteTableConfirm': '"{name}" tablosunu silmek istediğinizden emin misiniz?',
    'nRecordsPermanentDelete': '{n} kayıt kalıcı olarak silinecek.',
    'searchTable': 'Tablo Ara',
    'typeTableName': 'Tablo adı yazın...',
    'noTablesCreated': 'Henüz tablo yok',
    'createYourFirst': 'İlk tablonuzu oluşturun',
    'noMatchingTable': '"{query}" ile eşleşen tablo yok',
    'active': 'Aktif',
    'totalNTables': 'Toplam {n} tablo',
    'showingNofM': '{n} / {m} tablo gösteriliyor',
    'exportTitle': 'Çıktı Al',
    'selectFormat': 'Format Seçin:',
    'csvDesc': 'Excel ve diğer uygulamalarda açılabilir',
    'pdfDesc': 'Yazdırılabilir profesyonel rapor',
    'fileCreated': '{format} dosyası oluşturuldu!',
    'shareWhatsApp': 'Paylaş (WhatsApp, Mail, vb.)',
    'saveToDevice': 'Cihaza Kaydet',
    'selectAnotherFormat': 'Başka format seç',
    'creatingFile': 'Dosya oluşturuluyor...',
    'fileSaved': 'Dosya kaydedildi: {name}',
    'fileSaveFailed': 'Dosya kaydedilemedi. Depolama izni gerekebilir.',
    'tableData': 'Tablo Verisi',
    'selectTable': 'Tablo Seç',
    'deleteTableConfirmFull': '{name} tablosunu silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
    'tableTemplates': 'Tablo Şablonları',
    'searchTemplate': 'Şablon Ara',
    'closeSearch': 'Aramayı Kapat',
    'typeTemplateName': 'Şablon adı yazın...',
    'noTemplatesCreated': 'Henüz şablon oluşturmadınız',
    'saveFrequentStructures': 'Sık kullandığınız tablo yapılarını şablon olarak kaydedin',
    'createNewTemplate': 'Yeni Şablon Oluştur',
    'showingTemplates': '{n} / {m} şablon gösteriliyor',
    'deleteTemplate': 'Şablonu Sil',
    'deleteTemplateConfirm': '{name} şablonunu silmek istediğinizden emin misiniz?',
    'columnsLabel': 'Sütunlar:',
    'createNewTemplateTitle': 'Yeni Şablon Oluştur',
    'templateName': 'Şablon Adı',
    'templateNameHint': 'Örn: Sefer Kayıt Şablonu',
    'templateCreate': 'Şablon Oluştur',
    'templateNameEmpty': 'Şablon adı boş olamaz',
    'templateCreateFailed': 'Şablon oluşturulamadı',
    'editTemplate': 'Şablonu Düzenle',
    'templateNameEmptyError': 'Şablon adı boş olamaz',
    'columnNameEmpty': 'Sütun {n} adı boş olamaz',
    'templateUpdated': 'Şablon güncellendi',
    'templateUpdateFailed': 'Şablon güncellenirken hata oluştu',
    'editTableStructure': 'Tablo Yapısını Düzenle',
    'newColumn': 'Yeni Sütun',
    'newBadge': 'Yeni',
    'removeColumn': 'Sütunu Kaldır',
    'columnNameLabel': 'Sütun Adı',
    'typeName': 'Tip: {name}',
    'cannotChange': '(değiştirilemez)',
    'tableStructureUpdated': 'Tablo yapısı güncellendi',
    'tableUpdateError': 'Tablo güncellenirken hata oluştu',
    'constant': 'Sabit',
    'totalNRecords': 'Toplam: {n} kayıt',
    'totalsLabel': 'TOPLAMLAR',
    'pageNofM': 'Sayfa {n} / {m}',
    'autoNumberDescShort': 'Her yeni kayıt için otomatik artan numara (1, 2, 3...) atanır.',
    'dateAutoDescShort': 'Kayıt eklerken bugünün tarihi otomatik gelir, değiştirilebilir.',
    'timeAutoDescShort': 'Kayıt eklerken şu anki saat otomatik gelir, değiştirilebilir.',
    'quickSelectionListOptional': 'Hızlı Seçim Listesi (opsiyonel)',
    'quickSelectionHintShort': 'Virgülle ayırın: Ankara, İstanbul, İzmir',
    'quickSelectionAdd': 'Hızlı Seçim Ekle',
    'addColumnLabel': 'Sütun ekle:',
    'tallyTable': 'Çetele Tablosu',
    'tallyEmptyTitle': 'Çetele Tablosu Yok',
    'tallyEmptySubtitle': 'Yeni tablo oluşturarak\nçetele tutmaya başlayın',
    'tallyItems': 'öğe',
    'tallyDays': 'gün',
    'tallySearchHint': 'Öğe ara...',
    'tallyAddItemHint': 'Öğe eklemek için aşağıdaki butona dokunun',
    'tallyAddItem': 'Öğe Ekle',
    'tallyItemName': 'Öğe Adı',
    'tallyClear': 'Temizle',
    'tallySummary': 'Özet',
    'tallyRenameItem': 'Yeniden Adlandır',
    'tallyDeleteItem': 'Öğeyi Sil',
    'tallyDeleteItemConfirm': '"{name}" öğesini silmek istediğinizden emin misiniz?',
    'tallyTotalDays': 'Toplam Gün',
    'tallyEmpty': 'Boş',
    'tallyNameHint': 'Örn: Ocak 2026 Puantaj',
    'tallyDateRange': 'Tarih Aralığı',
    'tallyStartDate': 'Başlangıç',
    'tallyEndDate': 'Bitiş',
    'tallyStatuses': 'Durum Etiketleri',
    'tallyAddStatus': 'Durum Ekle',
    'tallyCreate': 'Çetele Oluştur',
    'tallyLabel': 'Etiket',
    'tallyFullName': 'Tam Ad',
    'tallyFullNameHint': 'Örn: Çalıştı',
    'tallySelectColor': 'Renk Seçin',
    'tallyAtLeastOneStatus': 'En az bir durum etiketi tanımlamalısınız',
    'tallyTab': 'Çetele',
    'tallySwitch': 'Çetele Değiştir',
    'tallyDeleteTable': 'Çeteleyi Sil',
    'tallyTableName': 'Çetele Adı',
    'tallyTableNameHint': 'Örn: Ocak 2026 Puantaj',
    'tallyAddStatusHint': 'En az bir durum etiketi ekleyin (örn: Ç-Çalıştı, İ-İzinli)',
    'tallyCode': 'Kod',
    'tallyStatusLabel': 'Açıklama',
    'tallyPickColor': 'Renk Seçin',
    'tallyNameRequired': 'Çetele adı boş olamaz',
    'tallyDateError': 'Başlangıç tarihi bitiş tarihinden sonra olamaz',
    'tallyStatusRequired': 'En az bir durum etiketi eklemelisiniz',
    'tallyCodeRequired': 'Durum kodu boş olamaz',
    'tallyCreateFailed': 'Çetele oluşturulamadı',
    'tallyItemsLabel': 'Öğeler',
    'tallyItem': 'Öğe',
    'tallyItemNameHint': 'Örn: Ali, Ürün A',
    'tallyNoItems': 'Henüz öğe eklenmemiş',
    'tallyItemHeader': 'Ad',
  };

  // ============== ENGLISH ==============
  static const Map<String, String> _en = {
    'appTitle': 'Table Note',
    'cancel': 'Cancel',
    'save': 'Save',
    'delete': 'Delete',
    'edit': 'Edit',
    'close': 'Close',
    'create': 'Create',
    'add': 'Add',
    'update': 'Update',
    'yes': 'Yes',
    'no': 'No',
    'error': 'Error',
    'success': 'Success',
    'search': 'Search',
    'filter': 'Filter',
    'settings': 'Settings',
    'language': 'Language',
    'turkish': 'Türkçe',
    'english': 'English',
    'languageSettings': 'Language Settings',
    'selectLanguage': 'Select Language',
    'menu': 'Menu',
    'tableNote': 'Table Note',
    'findTable': 'Find Table',
    'exportData': 'Export',
    'newTable': 'New Table',
    'templates': 'Templates',
    'addRecord': 'Add Record',
    'searchInTable': 'Search in table...',
    'nRecords': '{n} records',
    'nColumns': '{n} columns',
    'welcome': 'Welcome!',
    'createFirstTable': 'Create your first table\nto organize your data',
    'createTable': 'Create Table',
    'orSelectFromTemplates': 'or Select from Templates',
    'createNewTable': 'Create New Table',
    'manualCreate': 'Manual Create',
    'createFromTemplate': 'From Template',
    'tableName': 'Table Name',
    'tableNameHint': 'e.g. Trip Records',
    'columns': 'Columns',
    'help': 'Help',
    'columnN': 'Column {n}',
    'columnName': 'Column name',
    'addColumn': 'Add Column',
    'deleteColumn': 'Delete Column',
    'tableNameEmpty': 'Table name cannot be empty',
    'atLeastOneColumn': 'You must add at least one column',
    'formulaRequired': 'Formula is required for column {name}',
    'defaultValueRequired': 'Default value is required for column {name}',
    'tableCreateFailed': 'Failed to create table',
    'noTemplatesYet': 'No templates yet',
    'createTableFromTemplate': 'Create Table from Template',
    'columnType': 'Column Type:',
    'normal': 'Normal',
    'constantValue': 'Constant',
    'formula': 'Formula',
    'date': 'Date',
    'time': 'Time',
    'autoNumber': 'Auto #',
    'numericColumn': 'Numeric Column',
    'numericColumnDesc': 'Values in this column can be summed',
    'manualInput': 'Manual data entry',
    'defaultValueComes': 'Default value is applied',
    'autoCalculated': 'Automatically calculated',
    'todaysDateAuto': "Today's date auto-fills",
    'currentTimeAuto': 'Current time auto-fills',
    'autoIncrement': 'Auto-incrementing number',
    'quickSelectionList': 'Quick Selection List',
    'quickSelectionHint': 'Separate with commas (e.g. New York, London)',
    'addQuickSelectionList': 'Add Quick Selection List',
    'defaultValue': 'Default Value',
    'defaultValueHint': 'e.g. 0.2',
    'defaultValueInfo': 'This value is applied to all rows by default. Can be changed per row.',
    'formulaAutoCalcInfo': 'This column is automatically calculated from other columns.',
    'formulaHint': 'e.g. {Kg}*{Unit Price}',
    'operationsHint': 'Operations: + - * / % (percent)',
    'clickToAddColumn': 'Click to add column:',
    'addOperation': 'Add operation:',
    'autoDate': 'Auto Date',
    'autoDateDesc': "Today's date auto-fills when adding a new record.\nYou can change it if needed.",
    'autoTime': 'Auto Time',
    'autoTimeDesc': 'Current time auto-fills when adding a new record.\nYou can change it if needed.',
    'autoNumberTitle': 'Auto Number',
    'autoNumberDesc': 'An auto-incrementing number is assigned to each new record.\nContinues as 1, 2, 3, 4...',
    'example': 'Example: {val}',
    'columnTypes': 'Column Types',
    'normalColumn': 'Normal Column',
    'normalColumnDesc': 'Manual data entry. Quick selection list can be added.',
    'constantColumnTitle': 'Constant Value Column',
    'constantColumnDesc': 'Your default value is automatically applied to all rows. Can be changed per row.',
    'formulaColumnTitle': 'Formula Column',
    'formulaColumnDesc': "Automatically calculated from other columns. Supported operations:\n• + (addition)\n• - (subtraction)\n• * (multiplication)\n• / (division)\n• % (percent: {Price}%18 = 18% of Price)",
    'exampleFormulas': 'Example Formulas:',
    'multiplyKgPrice': 'Multiply Kg by Unit Price',
    'priceVat': 'Price + VAT',
    'netWeight': 'Net weight',
    'understood': 'Got it',
    'addition': 'Addition',
    'subtraction': 'Subtraction',
    'multiplication': 'Multiplication',
    'division': 'Division',
    'percentage': 'Percentage',
    'openParen': 'Open Parenthesis',
    'closeParen': 'Close Parenthesis',
    'addNewRecord': 'Add New Record',
    'calculating': 'Calculating...',
    'formulaLabel': 'Formula',
    'quickSelect': 'Quick Select',
    'today': 'Today',
    'selectDate': 'Select Date',
    'now': 'Now',
    'selectTime': 'Select Time',
    'todaysDateAutoSet': "Today's date auto-filled",
    'currentTimeAutoSet': 'Current time auto-filled',
    'addFailed': 'Failed to add record',
    'orderNo': 'Order #',
    'autoLabel': 'Auto',
    'recordN': 'Record #{n}',
    'updateFailed': 'Failed to update record',
    'noResults': 'No results found',
    'noMatchingRecord': 'No records matching "{query}"',
    'tableEmpty': 'Table is empty',
    'tapToAddFirst': 'Tap the button below\nto add your first record',
    'deleteRecord': 'Delete Record',
    'deleteRecordConfirm': 'Are you sure you want to delete this record?',
    'filteredTotals': 'Filtered Totals',
    'totals': 'Totals',
    'searchOf': '"{query}" search',
    'record': 'records',
    'myTables': 'My Tables',
    'selectOrCreateTable': 'Select or create a new table',
    'noTablesYet': 'No tables yet',
    'createYourFirstTable': 'Create your first table',
    'switchToTable': 'Switch to Table',
    'editStructure': 'Edit Structure',
    'deleteTable': 'Delete Table',
    'deleteTableConfirm': 'Are you sure you want to delete "{name}"?',
    'nRecordsPermanentDelete': '{n} records will be permanently deleted.',
    'searchTable': 'Search Table',
    'typeTableName': 'Type table name...',
    'noTablesCreated': 'No tables yet',
    'createYourFirst': 'Create your first table',
    'noMatchingTable': 'No tables matching "{query}"',
    'active': 'Active',
    'totalNTables': 'Total {n} tables',
    'showingNofM': 'Showing {n} / {m} tables',
    'exportTitle': 'Export',
    'selectFormat': 'Select Format:',
    'csvDesc': 'Can be opened in Excel and other apps',
    'pdfDesc': 'Printable professional report',
    'fileCreated': '{format} file created!',
    'shareWhatsApp': 'Share (WhatsApp, Email, etc.)',
    'saveToDevice': 'Save to Device',
    'selectAnotherFormat': 'Select another format',
    'creatingFile': 'Creating file...',
    'fileSaved': 'File saved: {name}',
    'fileSaveFailed': 'Could not save file. Storage permission may be required.',
    'tableData': 'Table Data',
    'selectTable': 'Select Table',
    'deleteTableConfirmFull': 'Are you sure you want to delete {name}? This action cannot be undone.',
    'tableTemplates': 'Table Templates',
    'searchTemplate': 'Search Template',
    'closeSearch': 'Close Search',
    'typeTemplateName': 'Type template name...',
    'noTemplatesCreated': 'No templates created yet',
    'saveFrequentStructures': 'Save your frequently used table structures as templates',
    'createNewTemplate': 'Create New Template',
    'showingTemplates': '{n} / {m} templates shown',
    'deleteTemplate': 'Delete Template',
    'deleteTemplateConfirm': 'Are you sure you want to delete {name} template?',
    'columnsLabel': 'Columns:',
    'createNewTemplateTitle': 'Create New Template',
    'templateName': 'Template Name',
    'templateNameHint': 'e.g. Trip Record Template',
    'templateCreate': 'Create Template',
    'templateNameEmpty': 'Template name cannot be empty',
    'templateCreateFailed': 'Failed to create template',
    'editTemplate': 'Edit Template',
    'templateNameEmptyError': 'Template name cannot be empty',
    'columnNameEmpty': 'Column {n} name cannot be empty',
    'templateUpdated': 'Template updated',
    'templateUpdateFailed': 'Error updating template',
    'editTableStructure': 'Edit Table Structure',
    'newColumn': 'New Column',
    'newBadge': 'New',
    'removeColumn': 'Remove Column',
    'columnNameLabel': 'Column Name',
    'typeName': 'Type: {name}',
    'cannotChange': '(cannot change)',
    'tableStructureUpdated': 'Table structure updated',
    'tableUpdateError': 'Error updating table',
    'constant': 'Constant',
    'totalNRecords': 'Total: {n} records',
    'totalsLabel': 'TOTALS',
    'pageNofM': 'Page {n} / {m}',
    'autoNumberDescShort': 'Auto-incrementing number (1, 2, 3...) for each new record.',
    'dateAutoDescShort': "Today's date auto-fills when adding, can be changed.",
    'timeAutoDescShort': 'Current time auto-fills when adding, can be changed.',
    'quickSelectionListOptional': 'Quick Selection List (optional)',
    'quickSelectionHintShort': 'Separate with commas: NYC, London, Berlin',
    'quickSelectionAdd': 'Add Quick Selection',
    'addColumnLabel': 'Add column:',
    'tallyTable': 'Tally Table',
    'tallyEmptyTitle': 'No Tally Tables',
    'tallyEmptySubtitle': 'Create a new table\nto start tracking',
    'tallyItems': 'items',
    'tallyDays': 'days',
    'tallySearchHint': 'Search items...',
    'tallyAddItemHint': 'Tap the button below to add an item',
    'tallyAddItem': 'Add Item',
    'tallyItemName': 'Item Name',
    'tallyClear': 'Clear',
    'tallySummary': 'Summary',
    'tallyRenameItem': 'Rename',
    'tallyDeleteItem': 'Delete Item',
    'tallyDeleteItemConfirm': 'Are you sure you want to delete "{name}"?',
    'tallyTotalDays': 'Total Days',
    'tallyEmpty': 'Empty',
    'tallyNameHint': 'e.g. January 2026 Attendance',
    'tallyDateRange': 'Date Range',
    'tallyStartDate': 'Start',
    'tallyEndDate': 'End',
    'tallyStatuses': 'Status Labels',
    'tallyAddStatus': 'Add Status',
    'tallyCreate': 'Create Tally',
    'tallyLabel': 'Label',
    'tallyFullName': 'Full Name',
    'tallyFullNameHint': 'e.g. Worked',
    'tallySelectColor': 'Select Color',
    'tallyAtLeastOneStatus': 'You must define at least one status label',
    'tallyTab': 'Tally',
    'tallySwitch': 'Switch Tally',
    'tallyDeleteTable': 'Delete Tally',
    'tallyTableName': 'Tally Name',
    'tallyTableNameHint': 'e.g. January 2026 Attendance',
    'tallyAddStatusHint': 'Add at least one status label (e.g. W-Worked, L-Leave)',
    'tallyCode': 'Code',
    'tallyStatusLabel': 'Description',
    'tallyPickColor': 'Pick Color',
    'tallyNameRequired': 'Tally name cannot be empty',
    'tallyDateError': 'Start date cannot be after end date',
    'tallyStatusRequired': 'You must add at least one status label',
    'tallyCodeRequired': 'Status code cannot be empty',
    'tallyCreateFailed': 'Failed to create tally',
    'tallyItemsLabel': 'Items',
    'tallyItem': 'Item',
    'tallyItemNameHint': 'e.g. Ali, Product A',
    'tallyNoItems': 'No items added yet',
    'tallyItemHeader': 'Name',
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['tr', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
