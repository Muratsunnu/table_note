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
  String get appearance => _t('appearance');
  String get darkTheme => _t('darkTheme');
  String get darkThemeDescription => _t('darkThemeDescription');
  String get menu => _t('menu');
  String get openMenuToCreate => _t('openMenuToCreate');
  String get skip => _t('skip');
  String get continueLabel => _t('continueLabel');
  String get startUsing => _t('startUsing');
  String get onboardingOrganizeTitle => _t('onboardingOrganizeTitle');
  String get onboardingOrganizeDescription =>
      _t('onboardingOrganizeDescription');
  String get onboardingOfflineTitle => _t('onboardingOfflineTitle');
  String get onboardingOfflineDescription => _t('onboardingOfflineDescription');
  String get onboardingPremiumTitle => _t('onboardingPremiumTitle');
  String get onboardingPremiumDescription => _t('onboardingPremiumDescription');
  String get onboardingTrialBadge => _t('onboardingTrialBadge');
  String get premium => _t('premium');
  String get unlockPremium => _t('unlockPremium');
  String get premiumDescription => _t('premiumDescription');
  String get premiumActive => _t('premiumActive');
  String get premiumActiveDescription => _t('premiumActiveDescription');
  String get premiumVoiceFeature => _t('premiumVoiceFeature');
  String get premiumCloudFeature => _t('premiumCloudFeature');
  String get premiumShareFeature => _t('premiumShareFeature');
  String get premiumImportFeature => _t('premiumImportFeature');
  String get premiumUnlimitedFeature => _t('premiumUnlimitedFeature');
  String get premiumTallyFeature => _t('premiumTallyFeature');
  String get plannedAnnualPrice => _t('plannedAnnualPrice');
  String get sevenDayTrial => _t('sevenDayTrial');
  String get billingPreparing => _t('billingPreparing');
  String get startFreeTrial => _t('startFreeTrial');
  String get restorePurchases => _t('restorePurchases');
  String get signInToSubscribe => _t('signInToSubscribe');
  String get purchaseCouldNotBeVerified => _t('purchaseCouldNotBeVerified');
  String get account => _t('account');
  String get noAccountConnected => _t('noAccountConnected');
  String get accountDescription => _t('accountDescription');
  String get accountPreparing => _t('accountPreparing');
  String get onlineServicesUnavailable => _t('onlineServicesUnavailable');
  String get onlineServicesUnavailableDescription =>
      _t('onlineServicesUnavailableDescription');
  String get signIn => _t('signIn');
  String get signOut => _t('signOut');
  String get signInWithGoogle => _t('signInWithGoogle');
  String get pleaseWait => _t('pleaseWait');
  String get ok => _t('ok');
  String get cloudBackup => _t('cloudBackup');
  String get cloudBackupSubtitle => _t('cloudBackupSubtitle');
  String get backupComplete => _t('backupComplete');
  String get restoreTable => _t('restoreTable');
  String get restoreChoiceDescription => _t('restoreChoiceDescription');
  String get newCopy => _t('newCopy');
  String get overwrite => _t('overwrite');
  String get restoredToDevice => _t('restoredToDevice');
  String get shareCode => _t('shareCode');
  String shareCodeValidity(String code) =>
      _t('shareCodeValidity').replaceAll('{code}', code);
  String get addSharedTable => _t('addSharedTable');
  String get premiumRequired => _t('premiumRequired');
  String get cloudPremiumMessage => _t('cloudPremiumMessage');
  String get viewPremium => _t('viewPremium');
  String get connectAccount => _t('connectAccount');
  String get connectAccountMessage => _t('connectAccountMessage');
  String get backupNow => _t('backupNow');
  String get addShareCodeTooltip => _t('addShareCodeTooltip');
  String get noCloudBackup => _t('noCloudBackup');
  String get myBackup => _t('myBackup');
  String get sharedWithMe => _t('sharedWithMe');
  String get voiceFill => _t('voiceFill');
  String get voiceExample => _t('voiceExample');
  String get onDeviceRecognition => _t('onDeviceRecognition');
  String get preparingMicrophone => _t('preparingMicrophone');
  String get tapToSpeak => _t('tapToSpeak');
  String get listening => _t('listening');
  String get stopListening => _t('stopListening');
  String get recognizedSpeech => _t('recognizedSpeech');
  String get recognizedSpeechHint => _t('recognizedSpeechHint');
  String get offlineSpeechUnavailable => _t('offlineSpeechUnavailable');
  String get reviewFields => _t('reviewFields');
  String get confirmAndAdd => _t('confirmAndAdd');

  // ============== TABLE SCREEN ==============
  String get tableNote => _t('tableNote');
  String get tablesTab => _t('tablesTab');
  String get importCsv => _t('importCsv');
  String get moreActions => _t('moreActions');
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
  String formulaRequired(String n) =>
      _t('formulaRequired').replaceAll('{name}', n);
  String defaultValueRequired(String n) =>
      _t('defaultValueRequired').replaceAll('{name}', n);
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
  String get templateQuickSelectionHelp => _t('templateQuickSelectionHelp');
  String get quickSelectionLinesHint => _t('quickSelectionLinesHint');
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
  String noMatchingRecord(String q) =>
      _t('noMatchingRecord').replaceAll('{query}', q);
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
  String deleteTableConfirm(String n) =>
      _t('deleteTableConfirm').replaceAll('{name}', n);
  String nRecordsPermanentDelete(int n) =>
      _t('nRecordsPermanentDelete').replaceAll('{n}', n.toString());

  // ============== SEARCH DIALOG ==============
  String get searchTable => _t('searchTable');
  String get searchTally => _t('searchTally');
  String get typeTallyName => _t('typeTallyName');
  String get typeTableName => _t('typeTableName');
  String get noTablesCreated => _t('noTablesCreated');
  String get createYourFirst => _t('createYourFirst');
  String noMatchingTable(String q) =>
      _t('noMatchingTable').replaceAll('{query}', q);
  String get active => _t('active');
  String totalNTables(int n) =>
      _t('totalNTables').replaceAll('{n}', n.toString());
  String showingNofM(int n, int m) => _t(
    'showingNofM',
  ).replaceAll('{n}', n.toString()).replaceAll('{m}', m.toString());

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
  String deleteTableConfirmFull(String n) =>
      _t('deleteTableConfirmFull').replaceAll('{name}', n);

  // ============== TEMPLATE MANAGEMENT ==============
  String get tableTemplates => _t('tableTemplates');
  String get searchTemplate => _t('searchTemplate');
  String get closeSearch => _t('closeSearch');
  String get typeTemplateName => _t('typeTemplateName');
  String get noTemplatesCreated => _t('noTemplatesCreated');
  String get saveFrequentStructures => _t('saveFrequentStructures');
  String get createNewTemplate => _t('createNewTemplate');
  String showingTemplates(int n, int m) => _t(
    'showingTemplates',
  ).replaceAll('{n}', n.toString()).replaceAll('{m}', m.toString());
  String get deleteTemplate => _t('deleteTemplate');
  String deleteTemplateConfirm(String n) =>
      _t('deleteTemplateConfirm').replaceAll('{name}', n);
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
  String columnNameEmpty(int n) =>
      _t('columnNameEmpty').replaceAll('{n}', n.toString());
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
  String totalNRecords(int n) =>
      _t('totalNRecords').replaceAll('{n}', n.toString());
  String get totalsLabel => _t('totalsLabel');
  String pageNofM(int n, int m) => _t(
    'pageNofM',
  ).replaceAll('{n}', n.toString()).replaceAll('{m}', m.toString());

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
  String get recordNameRequired => _t('recordNameRequired');
  String get tallyClear => _t('tallyClear');
  String get tallySummary => _t('tallySummary');
  String get tallyRenameItem => _t('tallyRenameItem');
  String get tallyDeleteItem => _t('tallyDeleteItem');
  String tallyDeleteItemConfirm(String name) =>
      _t('tallyDeleteItemConfirm').replaceAll('{name}', name);
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
  String get tallyEditTitle => _t('tallyEditTitle');
  String get tallyUpdateFailed => _t('tallyUpdateFailed');
  String get tallyDeleteStatusWarning => _t('tallyDeleteStatusWarning');
  String get duplicateStatusCode => _t('duplicateStatusCode');
  String get goToToday => _t('goToToday');
  String get tallyTools => _t('tallyTools');
  String get overallSummary => _t('overallSummary');
  String get reorderRows => _t('reorderRows');
  String get searchPersonOrItem => _t('searchPersonOrItem');
  String get bulkMark => _t('bulkMark');
  String get forToday => _t('forToday');
  String get chooseDateRange => _t('chooseDateRange');
  String get undoLastAction => _t('undoLastAction');
  // ============== ORTAK TABLO ==============
  String get joinTable => _t('joinTable');
  String get joinCode => _t('joinCode');
  String get joinPassword => _t('joinPassword');
  String get joinPasswordOptional => _t('joinPasswordOptional');
  String get yourName => _t('yourName');
  String get joinAction => _t('joinAction');
  String get saveToCloud => _t('saveToCloud');
  String get syncSending => _t('syncSending');
  String get syncUpToDate => _t('syncUpToDate');
  String get reviewConflicts => _t('reviewConflicts');
  String get conflictTitle => _t('conflictTitle');
  String get conflictExplainer => _t('conflictExplainer');
  String get conflictRowChanged => _t('conflictRowChanged');
  String get conflictRowDeleted => _t('conflictRowDeleted');
  String get conflictRowGone => _t('conflictRowGone');
  String get conflictMine => _t('conflictMine');
  String get conflictTheirs => _t('conflictTheirs');
  String get conflictKeepMine => _t('conflictKeepMine');
  String get conflictKeepTheirs => _t('conflictKeepTheirs');
  String pendingChangeCount(int n) =>
      _t('pendingChangeCount').replaceAll('{n}', n.toString());
  String conflictCount(int n) =>
      _t('conflictCount').replaceAll('{n}', n.toString());
  String get joinTableExplainer => _t('joinTableExplainer');
  String get yourNameHint => _t('yourNameHint');
  String joinedTable(String name) =>
      _t('joinedTable').replaceAll('{name}', name);
  String get sharedTableMembers => _t('sharedTableMembers');
  String get activityLog => _t('activityLog');
  String get activityLogOwnerOnly => _t('activityLogOwnerOnly');
  String get shareExplainer => _t('shareExplainer');
  String get codeHiddenExplainer => _t('codeHiddenExplainer');
  String get startSharing => _t('startSharing');
  String get stopSharing => _t('stopSharing');
  String get newCode => _t('newCode');
  String get joinPasswordHint => _t('joinPasswordHint');
  String get passwordSaved => _t('passwordSaved');
  String get passwordRemoved => _t('passwordRemoved');
  String get noMembersYet => _t('noMembersYet');
  String get noActivityYet => _t('noActivityYet');
  String get activityJoined => _t('activityJoined');
  String get activityRowAdded => _t('activityRowAdded');
  String get activityRowDeleted => _t('activityRowDeleted');
  String get activityActorSelf => _t('activityActorSelf');
  String get activityItemAdded => _t('activityItemAdded');
  String get activityItemDeleted => _t('activityItemDeleted');
  String get activityColumnsChanged => _t('activityColumnsChanged');
  String get sharedStructureLocked => _t('sharedStructureLocked');
  String get sharedStructureLockedTitle => _t('sharedStructureLockedTitle');
  String get copy => _t('copy');
  String get copied => _t('copied');
  String sharedTableError(String code) => _t('err_$code');
  String get redoLastAction => _t('redoLastAction');
  String get done => _t('done');
  String get selectAll => _t('selectAll');
  String get apply => _t('apply');
  String get status => _t('status');
  String get csvImportDescription => _t('csvImportDescription');
  String get selectFile => _t('selectFile');
  String get selectAnotherFile => _t('selectAnotherFile');
  String get fileCouldNotBeRead => _t('fileCouldNotBeRead');
  String get csvEmptyOrTooLarge => _t('csvEmptyOrTooLarge');
  String get csvHeaderMissing => _t('csvHeaderMissing');
  String get csvTooManyRows => _t('csvTooManyRows');
  String get csvInvalid => _t('csvInvalid');
  String get csvImportedTable => _t('csvImportedTable');
  String get cloudOperationFailed => _t('cloudOperationFailed');
  String get accountOperationFailed => _t('accountOperationFailed');
  String get exportFailed => _t('exportFailed');

  // ============== TALLY TEMPLATES ==============
  String get tallyTemplates => _t('tallyTemplates');
  String get tallyTemplateCreate => _t('tallyTemplateCreate');
  String get tallyTemplateEdit => _t('tallyTemplateEdit');
  String get tallyTemplateName => _t('tallyTemplateName');
  String get tallyTemplateNameHint => _t('tallyTemplateNameHint');
  String get tallyTemplateNameRequired => _t('tallyTemplateNameRequired');
  String get tallyTemplateCreateFailed => _t('tallyTemplateCreateFailed');
  String get tallyTemplateUpdateFailed => _t('tallyTemplateUpdateFailed');
  String get tallyTemplateDelete => _t('tallyTemplateDelete');
  String tallyTemplateDeleteConfirm(String name) =>
      _t('tallyTemplateDeleteConfirm').replaceAll('{name}', name);
  String get tallyNoTemplates => _t('tallyNoTemplates');
  String get tallyNoTemplatesHint => _t('tallyNoTemplatesHint');
  String get tallyCreateNewTemplate => _t('tallyCreateNewTemplate');
  String get tallyFromTemplate => _t('tallyFromTemplate');
  String get tallyCreateFromTemplate => _t('tallyCreateFromTemplate');
  String tallyTemplateStatusItemCount(int s, int i) => _t(
    'tallyTemplateStatusItemCount',
  ).replaceAll('{s}', s.toString()).replaceAll('{i}', i.toString());
  String get tallyIncludeItems => _t('tallyIncludeItems');
  String get tallyIncludeItemsHint => _t('tallyIncludeItemsHint');

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
    'appearance': 'Görünüm',
    'darkTheme': 'Koyu Tema',
    'darkThemeDescription': 'Karanlık ortamlarda daha rahat kullanım',
    'menu': 'Menü',
    'openMenuToCreate': 'Yeni tablo veya çetele için menüyü açın',
    'skip': 'Atla',
    'continueLabel': 'Devam Et',
    'startUsing': 'Kullanmaya Başla',
    'onboardingOrganizeTitle': 'Kayıtlarını Düzenle',
    'onboardingOrganizeDescription':
        'Tablolar, çeteleler ve şablonlarla günlük kayıtlarını tek yerde tut.',
    'onboardingOfflineTitle': 'İnternetsiz de Yanında',
    'onboardingOfflineDescription':
        'Temel özellikleri bağlantı olmadan kullan. Verilerin cihazında kalır.',
    'onboardingPremiumTitle': 'Daha Fazlasını Yap',
    'onboardingPremiumDescription':
        'Sesli doldurma, bulut yedekleme, paylaşım ve gelişmiş araçlara eriş.',
    'onboardingTrialBadge': '7 GÜN ÜCRETSİZ',
    'premium': 'Premium',
    'unlockPremium': 'Table Note Premium',
    'premiumDescription':
        'Tüm gelişmiş özellikleri aç ve kayıtlarını güvenle yönet.',
    'premiumActive': 'Premium Aktif',
    'premiumActiveDescription': 'Tüm Premium özelliklere erişebilirsin.',
    'premiumVoiceFeature': 'Konuşarak tablo doldurma',
    'premiumCloudFeature': 'Bulut yedekleme ve geri yükleme',
    'premiumShareFeature': 'Güvenli tablo paylaşımı',
    'premiumImportFeature': 'CSV dosyasından içe aktarma',
    'premiumUnlimitedFeature': 'Sınırsız tablo, çetele ve şablon',
    'premiumTallyFeature': 'Gelişmiş çetele araçları',
    'plannedAnnualPrice': '₺200 / yıl',
    'sevenDayTrial': 'İlk 7 gün ücretsiz, ardından yıllık yenilenir',
    'billingPreparing': 'Abonelik bağlantısı hazırlanıyor',
    'startFreeTrial': '7 Gün Ücretsiz Dene',
    'restorePurchases': 'Satın Almaları Geri Yükle',
    'signInToSubscribe': 'Üyelik için giriş yap',
    'purchaseCouldNotBeVerified':
        'Satın alma doğrulanamadı. İnternet bağlantını kontrol edip tekrar dene.',
    'account': 'Hesap',
    'noAccountConnected': 'Bağlı hesap yok',
    'accountDescription':
        'Bulut yedekleme, paylaşım ve Premium erişimi için hesabını bağla.',
    'accountPreparing': 'Hesap bağlantısı hazırlanıyor',
    'onlineServicesUnavailable': 'Çevrimiçi hizmet kullanılamıyor',
    'onlineServicesUnavailableDescription':
        'Hesap ve bulut özellikleri şu anda kullanılamıyor. Cihazdaki tablolar etkilenmez; çevrimdışı çalışmaya devam edebilirsin.',
    'signIn': 'Giriş Yap',
    'signOut': 'Çıkış Yap',
    'signInWithGoogle': 'Google ile Giriş Yap',
    'pleaseWait': 'Lütfen bekleyin...',
    'ok': 'Tamam',
    'cloudBackup': 'Bulut Yedekleme',
    'cloudBackupSubtitle': 'Elle yedekle, geri yükle ve paylaş',
    'backupComplete': 'Yedekleme tamamlandı.',
    'restoreTable': 'Tabloyu geri yükle',
    'restoreChoiceDescription':
        'Aynı kimlikteki tablo varsa üzerine yazabilir veya yeni bir kopya oluşturabilirsin.',
    'newCopy': 'Yeni kopya',
    'overwrite': 'Üzerine yaz',
    'restoredToDevice': 'Tablo cihaza geri yüklendi.',
    'shareCode': 'Paylaşım kodu',
    'shareCodeValidity':
        '{code}\n\nKod 7 gün geçerli ve bir kez kullanılabilir.',
    'addSharedTable': 'Paylaşılmış tabloyu ekle',
    'premiumRequired': 'Premium gerekli',
    'cloudPremiumMessage': 'Bulut yedekleme ve paylaşım Premium özelliğidir.',
    'viewPremium': 'Premium’u Gör',
    'connectAccount': 'Hesabını bağla',
    'connectAccountMessage':
        'Yedeklerini güvenle saklamak için giriş yapmalısın.',
    'backupNow': 'Şimdi Yedekle',
    'addShareCodeTooltip': 'Paylaşım kodu ekle',
    'noCloudBackup': 'Henüz bulut yedeği yok.',
    'myBackup': 'Benim yedeğim',
    'sharedWithMe': 'Benimle paylaşıldı',
    'voiceFill': 'Konuşarak Doldur',
    'voiceExample': '“Ad defter, adet 3, not mavi kapaklı.”',
    'onDeviceRecognition': 'Cihazda işlenir · İnternet gerekmez',
    'preparingMicrophone': 'Mikrofon hazırlanıyor…',
    'tapToSpeak': 'Konuşmaya başlamak için dokun',
    'listening': 'Seni dinliyorum…',
    'stopListening': 'Dinlemeyi bitir',
    'recognizedSpeech': 'Algılanan konuşma',
    'recognizedSpeechHint': 'Söylediklerin burada görünecek',
    'offlineSpeechUnavailable':
        'Bu cihazda çevrimdışı Türkçe konuşma modeli bulunamadı veya mikrofon izni verilmedi.',
    'reviewFields': 'Alanları kontrol et',
    'confirmAndAdd': 'Onayla ve Ekle',
    'tableNote': 'Table Note',
    'tablesTab': 'Tablolar',
    'importCsv': 'CSV İçe Aktar',
    'moreActions': 'Diğer işlemler',
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
    'tableNameHint': 'Örn: Günlük Kayıtlar',
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
    'templateQuickSelectionHelp':
        'Her satıra bir seçenek yazın. Ekleyebilir, değiştirebilir veya silebilirsiniz. Değişiklikler yalnızca yeni tabloya uygulanır; şablon değişmez.',
    'quickSelectionLinesHint': 'Her satıra bir seçenek',
    'quickSelectionHint': 'Virgülle ayırın (örn: İstanbul, Ankara)',
    'addQuickSelectionList': 'Hızlı Seçim Listesi Ekle',
    'defaultValue': 'Varsayılan Değer',
    'defaultValueHint': 'Örn: 0.2',
    'defaultValueInfo':
        'Bu değer tüm satırlara varsayılan olarak gelir. Satır bazında değiştirilebilir.',
    'formulaAutoCalcInfo': 'Bu sütun diğer sütunlardan otomatik hesaplanır.',
    'formulaHint': 'Örn: {Kg}*{Birim Fiyat}',
    'operationsHint': 'İşlemler: + - * / % (yüzde)',
    'clickToAddColumn': 'Sütun eklemek için tıklayın:',
    'addOperation': 'İşlem ekle:',
    'autoDate': 'Otomatik Tarih',
    'autoDateDesc':
        'Yeni kayıt eklerken bugünün tarihi otomatik gelir.\nİsterseniz değiştirebilirsiniz.',
    'autoTime': 'Otomatik Saat',
    'autoTimeDesc':
        'Yeni kayıt eklerken şu anki saat otomatik gelir.\nİsterseniz değiştirebilirsiniz.',
    'autoNumberTitle': 'Otomatik Sıra Numarası',
    'autoNumberDesc':
        'Her yeni kayıt için otomatik artan numara atanır.\n1, 2, 3, 4... şeklinde devam eder.',
    'example': 'Örnek: {val}',
    'columnTypes': 'Sütun Tipleri',
    'normalColumn': 'Normal Sütun',
    'normalColumnDesc':
        'Manuel veri girişi yapılır. Hızlı seçim listesi eklenebilir.',
    'constantColumnTitle': 'Sabit Değer Sütunu',
    'constantColumnDesc':
        'Belirlediğiniz varsayılan değer tüm satırlara otomatik gelir. İsterseniz satır bazında değiştirebilirsiniz.',
    'formulaColumnTitle': 'Formül Sütunu',
    'formulaColumnDesc':
        "Diğer sütunlardan otomatik hesaplanır. Desteklenen işlemler:\n• + (toplama)\n• - (çıkarma)\n• * (çarpma)\n• / (bölme)\n• % (yüzde: {Fiyat}%18 = Fiyatın %18'i)",
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
    'deleteTableConfirm':
        '"{name}" tablosunu silmek istediğinizden emin misiniz?',
    'nRecordsPermanentDelete': '{n} kayıt kalıcı olarak silinecek.',
    'searchTable': 'Tablo Ara',
    'searchTally': 'Çetele Ara',
    'typeTallyName': 'Çetele adı yazın...',
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
    'deleteTableConfirmFull':
        '{name} tablosunu silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
    'tableTemplates': 'Tablo Şablonları',
    'searchTemplate': 'Şablon Ara',
    'closeSearch': 'Aramayı Kapat',
    'typeTemplateName': 'Şablon adı yazın...',
    'noTemplatesCreated': 'Henüz şablon oluşturmadınız',
    'saveFrequentStructures':
        'Sık kullandığınız tablo yapılarını şablon olarak kaydedin',
    'createNewTemplate': 'Yeni Şablon Oluştur',
    'showingTemplates': '{n} / {m} şablon gösteriliyor',
    'deleteTemplate': 'Şablonu Sil',
    'deleteTemplateConfirm':
        '{name} şablonunu silmek istediğinizden emin misiniz?',
    'columnsLabel': 'Sütunlar:',
    'createNewTemplateTitle': 'Yeni Şablon Oluştur',
    'templateName': 'Şablon Adı',
    'templateNameHint': 'Örn: Günlük Kayıt Şablonu',
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
    'autoNumberDescShort':
        'Her yeni kayıt için otomatik artan numara (1, 2, 3...) atanır.',
    'dateAutoDescShort':
        'Kayıt eklerken bugünün tarihi otomatik gelir, değiştirilebilir.',
    'timeAutoDescShort':
        'Kayıt eklerken şu anki saat otomatik gelir, değiştirilebilir.',
    'quickSelectionListOptional': 'Hızlı Seçim Listesi (opsiyonel)',
    'quickSelectionHintShort': 'Virgülle ayırın: Ankara, İstanbul, İzmir',
    'quickSelectionAdd': 'Hızlı Seçim Ekle',
    'addColumnLabel': 'Sütun ekle:',
    'tallyTable': 'Çetele Tablosu',
    'tallyEmptyTitle': 'Çetele Tablosu Yok',
    'tallyEmptySubtitle': 'Yeni tablo oluşturarak\nçetele tutmaya başlayın',
    'tallyItems': 'kayıt',
    'tallyDays': 'gün',
    'tallySearchHint': 'Kayıt ara...',
    'tallyAddItemHint': 'Kayıt eklemek için aşağıdaki butona dokunun',
    'tallyAddItem': 'Kayıt Ekle',
    'tallyItemName': 'Kayıt Adı',
    'recordNameRequired': 'Kayıt adı boş olamaz',
    'tallyClear': 'Temizle',
    'tallySummary': 'Özet',
    'tallyRenameItem': 'Kaydı Yeniden Adlandır',
    'tallyDeleteItem': 'Kaydı Sil',
    'tallyDeleteItemConfirm':
        '"{name}" kaydını silmek istediğinizden emin misiniz?',
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
    'tallyAddStatusHint':
        'En az bir durum etiketi ekleyin (örn: Ç-Çalıştı, İ-İzinli)',
    'tallyCode': 'Kod',
    'tallyStatusLabel': 'Açıklama',
    'tallyPickColor': 'Renk Seçin',
    'tallyNameRequired': 'Çetele adı boş olamaz',
    'tallyDateError': 'Başlangıç tarihi bitiş tarihinden sonra olamaz',
    'tallyStatusRequired': 'En az bir durum etiketi eklemelisiniz',
    'tallyCodeRequired': 'Durum kodu boş olamaz',
    'tallyCreateFailed': 'Çetele oluşturulamadı',
    'tallyItemsLabel': 'Kayıtlar',
    'tallyItem': 'Kayıt',
    'tallyItemNameHint': 'Örn: Ali, Ürün A',
    'tallyNoItems': 'Henüz kayıt eklenmemiş',
    'tallyItemHeader': 'Kayıt',
    'tallyEditTitle': 'Çeteleyi Düzenle',
    'tallyUpdateFailed': 'Çetele güncellenemedi',
    'tallyDeleteStatusWarning':
        'Sildiğiniz durumların hücrelerdeki verileri de silinecek',
    'duplicateStatusCode': 'Aynı durum kodu birden fazla kullanılamaz.',
    'goToToday': 'Bugüne git',
    'tallyTools': 'Çetele araçları',
    'overallSummary': 'Genel özet',
    'reorderRows': 'Satırları sırala',
    'searchPersonOrItem': 'Kayıt ara',
    'bulkMark': 'Toplu işaretle',
    'forToday': 'Bugün için',
    'chooseDateRange': 'Veya tarih aralığı seç',
    'undoLastAction': 'Son işlemi geri al',
    'joinTable': 'Tabloya katıl',
    'joinCode': 'Katılım kodu',
    'joinPassword': 'Şifre',
    'joinPasswordOptional': 'Şifre (varsa)',
    'yourName': 'Adın',
    'joinAction': 'Katıl',
    'saveToCloud': 'Buluta kaydet',
    'syncSending': 'Gönderiliyor…',
    'syncUpToDate': 'Bulutla eşit',
    'reviewConflicts': 'İncele',
    'conflictTitle': 'Çakışan satırlar',
    'conflictExplainer':
        'Bu satırlar sen düzenlerken başkası tarafından da değiştirildi. Her biri için hangisinin kalacağını seç.',
    'conflictRowChanged': 'Bu satırı başkası da değiştirdi',
    'conflictRowDeleted': 'Bu satırı başkası sildi',
    'conflictRowGone': '(satır yok)',
    'conflictMine': 'Seninki',
    'conflictTheirs': 'Kayıttaki',
    'conflictKeepMine': 'Benimki kalsın',
    'conflictKeepTheirs': 'Kayıttaki kalsın',
    'pendingChangeCount': '{n} değişiklik bekliyor',
    'conflictCount': '{n} satır çakıştı',
    'joinTableExplainer':
        'Sana verilen kodu gir. Hesap açmana gerek yok; sadece bu tabloda '
        'görünecek adını yaz.',
    'yourNameHint': 'Tabloyu paylaşan kişi değişiklikleri bu adla görür.',
    'joinedTable': '{name} tablosuna katıldın.',
    'sharedTableMembers': 'Katılanlar',
    'activityLog': 'Değişiklik geçmişi',
    'activityLogOwnerOnly': 'Bu geçmişi yalnızca tabloyu paylaşan kişi görür.',
    'shareExplainer':
        'Kod üret, karşındakine söyle. Hesap açmasına gerek yok; sadece adını yazıp katılır.',
    'codeHiddenExplainer':
        'Bu tablo paylaşımda. Kod güvenlik gereği saklanmıyor; hatırlamıyorsan yenisini üret.',
    'startSharing': 'Paylaşımı başlat',
    'stopSharing': 'Paylaşımı kapat',
    'newCode': 'Yeni kod üret',
    'joinPasswordHint': 'Boş bırakırsan şifre kaldırılır. En az 4 karakter.',
    'passwordSaved': 'Şifre kaydedildi.',
    'passwordRemoved': 'Şifre kaldırıldı.',
    'noMembersYet': 'Henüz kimse katılmadı.',
    'noActivityYet': 'Henüz değişiklik yok.',
    'activityJoined': 'tabloya katıldı',
    'activityRowAdded': 'satır ekledi',
    'activityRowDeleted': 'satır sildi',
    'activityActorSelf': 'Sen',
    'activityItemAdded': 'öğe ekledi',
    'activityItemDeleted': 'öğe sildi',
    'activityColumnsChanged': 'yapıyı değiştirdi',
    'sharedStructureLockedTitle': 'Yapı kilitli',
    'sharedStructureLocked':
        'Yapıyı yalnızca paylaşan kişi değiştirebilir. Kayıtları ve '
        'işaretleri düzenlemeye devam edebilirsin.',
    'copy': 'Kopyala',
    'copied': 'Kopyalandı',
    'err_authentication_required': 'Bağlantı kurulamadı, tekrar dene.',
    'err_invalid_table_code': 'Kod bulunamadı. Kodu kontrol et.',
    'err_invalid_table_password': 'Şifre yanlış.',
    'err_owner_premium_required':
        'Tabloyu paylaşan kişinin aboneliği aktif değil.',
    'err_invalid_display_name': 'Ad 2-32 karakter olmalı.',
    'err_display_name_taken':
        'Bu ad bu tabloda kullanılıyor. Başka bir ad dene.',
    'err_too_many_attempts':
        'Çok fazla deneme yapıldı. Biraz sonra tekrar dene.',
    'err_table_not_found': 'Tablo bulunamadı.',
    'err_password_too_short': 'Şifre en az 4 karakter olmalı.',
    'err_shared_table_needs_upgrade':
        'Tablo buluttaki eski biçimde. Tabloyu paylaşan kişinin bir kez kaydetmesi gerekiyor.',
    'err_shared_table_locked_by_other':
        'Şu anda başkası tablonun yapısını değiştiriyor. Birazdan tekrar dene.',
    'err_shared_table_edit_access_required': 'Bu tabloda düzenleme yetkin yok.',
    'err_shared_table_revision_conflict':
        'Tablo sen bakarken değişti. Yenileyip tekrar dene.',
    'err_unknown': 'Bir şeyler ters gitti, tekrar dene.',
    'redoLastAction': 'Geri alınanı yinele',
    'done': 'Bitti',
    'selectAll': 'Tümünü seç',
    'apply': 'Uygula',
    'status': 'Durum',
    'csvImportDescription':
        'İlk satır sütun adları kabul edilir. İçe aktarmadan önce bir önizleme gösterilir.',
    'selectFile': 'Dosya Seç',
    'selectAnotherFile': 'Başka Dosya',
    'fileCouldNotBeRead': 'Dosya okunamadı.',
    'csvEmptyOrTooLarge': 'CSV dosyası boş veya 10 MB sınırını aşıyor.',
    'csvHeaderMissing': 'CSV başlık satırı bulunamadı.',
    'csvTooManyRows': 'CSV en fazla 10.000 kayıt içerebilir.',
    'csvInvalid': 'CSV dosyası geçerli bir biçimde değil.',
    'csvImportedTable': 'CSV İçe Aktarma',
    'cloudOperationFailed':
        'Bulut işlemi tamamlanamadı. Bağlantını kontrol edip tekrar dene.',
    'accountOperationFailed':
        'Hesap işlemi tamamlanamadı. Bağlantını kontrol edip tekrar dene.',
    'exportFailed': 'Dosya oluşturulamadı. Lütfen tekrar dene.',
    'tallyTemplates': 'Çetele Şablonları',
    'tallyTemplateCreate': 'Şablon Oluştur',
    'tallyTemplateEdit': 'Şablonu Düzenle',
    'tallyTemplateName': 'Şablon Adı',
    'tallyTemplateNameHint': 'Örn: Aylık Puantaj Şablonu',
    'tallyTemplateNameRequired': 'Şablon adı boş olamaz',
    'tallyTemplateCreateFailed': 'Şablon oluşturulamadı',
    'tallyTemplateUpdateFailed': 'Şablon güncellenemedi',
    'tallyTemplateDelete': 'Şablonu Sil',
    'tallyTemplateDeleteConfirm':
        '"{name}" şablonunu silmek istediğinizden emin misiniz?',
    'tallyNoTemplates': 'Henüz çetele şablonu yok',
    'tallyNoTemplatesHint':
        'Sık kullandığınız durum ve kayıtları şablon olarak kaydedin',
    'tallyCreateNewTemplate': 'Yeni Şablon Oluştur',
    'tallyFromTemplate': 'Şablondan Oluştur',
    'tallyCreateFromTemplate': 'Şablondan Çetele Oluştur',
    'tallyTemplateStatusItemCount': '{s} durum • {i} kayıt',
    'tallyIncludeItems': 'Kayıtları da yükle',
    'tallyIncludeItemsHint': 'Şablondaki kayıt adları yeni çeteleye eklenir',
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
    'appearance': 'Appearance',
    'darkTheme': 'Dark Theme',
    'darkThemeDescription': 'More comfortable in low-light environments',
    'menu': 'Menu',
    'openMenuToCreate': 'Open the menu to create a table or tally',
    'skip': 'Skip',
    'continueLabel': 'Continue',
    'startUsing': 'Start Using',
    'onboardingOrganizeTitle': 'Organize Your Records',
    'onboardingOrganizeDescription':
        'Keep daily records together with tables, tallies, and templates.',
    'onboardingOfflineTitle': 'Ready Offline',
    'onboardingOfflineDescription':
        'Use core features without a connection. Your data stays on your device.',
    'onboardingPremiumTitle': 'Do More',
    'onboardingPremiumDescription':
        'Access voice entry, cloud backup, sharing, and advanced tools.',
    'onboardingTrialBadge': '7 DAYS FREE',
    'premium': 'Premium',
    'unlockPremium': 'Table Note Premium',
    'premiumDescription':
        'Unlock every advanced feature and manage your records securely.',
    'premiumActive': 'Premium Active',
    'premiumActiveDescription': 'You have access to all Premium features.',
    'premiumVoiceFeature': 'Fill tables by speaking',
    'premiumCloudFeature': 'Cloud backup and restore',
    'premiumShareFeature': 'Secure table sharing',
    'premiumImportFeature': 'Import from CSV files',
    'premiumUnlimitedFeature': 'Unlimited tables, tallies, and templates',
    'premiumTallyFeature': 'Advanced tally tools',
    'plannedAnnualPrice': '₺200 / year',
    'sevenDayTrial': 'First 7 days free, then renews yearly',
    'billingPreparing': 'Subscription connection is being prepared',
    'startFreeTrial': 'Try 7 Days Free',
    'restorePurchases': 'Restore Purchases',
    'signInToSubscribe': 'Sign in to subscribe',
    'purchaseCouldNotBeVerified':
        'The purchase could not be verified. Check your connection and try again.',
    'account': 'Account',
    'noAccountConnected': 'No account connected',
    'accountDescription':
        'Connect your account for cloud backup, sharing, and Premium access.',
    'accountPreparing': 'Account connection is being prepared',
    'onlineServicesUnavailable': 'Online service unavailable',
    'onlineServicesUnavailableDescription':
        'Account and cloud features are currently unavailable. Your on-device tables are safe and you can continue working offline.',
    'signIn': 'Sign In',
    'signOut': 'Sign Out',
    'signInWithGoogle': 'Sign in with Google',
    'pleaseWait': 'Please wait...',
    'ok': 'OK',
    'cloudBackup': 'Cloud Backup',
    'cloudBackupSubtitle': 'Back up, restore, and share manually',
    'backupComplete': 'Backup completed.',
    'restoreTable': 'Restore table',
    'restoreChoiceDescription':
        'If the same table already exists, you can overwrite it or create a new copy.',
    'newCopy': 'New copy',
    'overwrite': 'Overwrite',
    'restoredToDevice': 'The table was restored to this device.',
    'shareCode': 'Share code',
    'shareCodeValidity':
        '{code}\n\nThe code is valid for 7 days and can be used once.',
    'addSharedTable': 'Add shared table',
    'premiumRequired': 'Premium required',
    'cloudPremiumMessage': 'Cloud backup and sharing are Premium features.',
    'viewPremium': 'View Premium',
    'connectAccount': 'Connect your account',
    'connectAccountMessage': 'Sign in to keep your backups secure.',
    'backupNow': 'Back Up Now',
    'addShareCodeTooltip': 'Add share code',
    'noCloudBackup': 'No cloud backups yet.',
    'myBackup': 'My backup',
    'sharedWithMe': 'Shared with me',
    'voiceFill': 'Fill by Voice',
    'voiceExample': '“Name notebook, quantity 3, note blue cover.”',
    'onDeviceRecognition': 'Processed on device · No internet required',
    'preparingMicrophone': 'Preparing microphone…',
    'tapToSpeak': 'Tap to start speaking',
    'listening': 'Listening…',
    'stopListening': 'Stop listening',
    'recognizedSpeech': 'Recognized speech',
    'recognizedSpeechHint': 'Your words will appear here',
    'offlineSpeechUnavailable':
        'Offline speech recognition is unavailable on this device or microphone permission was denied.',
    'reviewFields': 'Review the fields',
    'confirmAndAdd': 'Confirm and Add',
    'tableNote': 'Table Note',
    'tablesTab': 'Tables',
    'importCsv': 'Import CSV',
    'moreActions': 'More actions',
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
    'tableNameHint': 'e.g. Daily Records',
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
    'templateQuickSelectionHelp':
        'Enter one option per line. Add, edit or remove options. Changes apply only to the new table; the template stays unchanged.',
    'quickSelectionLinesHint': 'One option per line',
    'quickSelectionHint': 'Separate with commas (e.g. New York, London)',
    'addQuickSelectionList': 'Add Quick Selection List',
    'defaultValue': 'Default Value',
    'defaultValueHint': 'e.g. 0.2',
    'defaultValueInfo':
        'This value is applied to all rows by default. Can be changed per row.',
    'formulaAutoCalcInfo':
        'This column is automatically calculated from other columns.',
    'formulaHint': 'e.g. {Kg}*{Unit Price}',
    'operationsHint': 'Operations: + - * / % (percent)',
    'clickToAddColumn': 'Click to add column:',
    'addOperation': 'Add operation:',
    'autoDate': 'Auto Date',
    'autoDateDesc':
        "Today's date auto-fills when adding a new record.\nYou can change it if needed.",
    'autoTime': 'Auto Time',
    'autoTimeDesc':
        'Current time auto-fills when adding a new record.\nYou can change it if needed.',
    'autoNumberTitle': 'Auto Number',
    'autoNumberDesc':
        'An auto-incrementing number is assigned to each new record.\nContinues as 1, 2, 3, 4...',
    'example': 'Example: {val}',
    'columnTypes': 'Column Types',
    'normalColumn': 'Normal Column',
    'normalColumnDesc': 'Manual data entry. Quick selection list can be added.',
    'constantColumnTitle': 'Constant Value Column',
    'constantColumnDesc':
        'Your default value is automatically applied to all rows. Can be changed per row.',
    'formulaColumnTitle': 'Formula Column',
    'formulaColumnDesc':
        "Automatically calculated from other columns. Supported operations:\n• + (addition)\n• - (subtraction)\n• * (multiplication)\n• / (division)\n• % (percent: {Price}%18 = 18% of Price)",
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
    'searchTally': 'Search Tally',
    'typeTallyName': 'Type tally name...',
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
    'fileSaveFailed':
        'Could not save file. Storage permission may be required.',
    'tableData': 'Table Data',
    'selectTable': 'Select Table',
    'deleteTableConfirmFull':
        'Are you sure you want to delete {name}? This action cannot be undone.',
    'tableTemplates': 'Table Templates',
    'searchTemplate': 'Search Template',
    'closeSearch': 'Close Search',
    'typeTemplateName': 'Type template name...',
    'noTemplatesCreated': 'No templates created yet',
    'saveFrequentStructures':
        'Save your frequently used table structures as templates',
    'createNewTemplate': 'Create New Template',
    'showingTemplates': '{n} / {m} templates shown',
    'deleteTemplate': 'Delete Template',
    'deleteTemplateConfirm': 'Are you sure you want to delete {name} template?',
    'columnsLabel': 'Columns:',
    'createNewTemplateTitle': 'Create New Template',
    'templateName': 'Template Name',
    'templateNameHint': 'e.g. Daily Record Template',
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
    'autoNumberDescShort':
        'Auto-incrementing number (1, 2, 3...) for each new record.',
    'dateAutoDescShort': "Today's date auto-fills when adding, can be changed.",
    'timeAutoDescShort': 'Current time auto-fills when adding, can be changed.',
    'quickSelectionListOptional': 'Quick Selection List (optional)',
    'quickSelectionHintShort': 'Separate with commas: NYC, London, Berlin',
    'quickSelectionAdd': 'Add Quick Selection',
    'addColumnLabel': 'Add column:',
    'tallyTable': 'Tally Table',
    'tallyEmptyTitle': 'No Tally Tables',
    'tallyEmptySubtitle': 'Create a new table\nto start tracking',
    'tallyItems': 'records',
    'tallyDays': 'days',
    'tallySearchHint': 'Search records...',
    'tallyAddItemHint': 'Tap the button below to add a record',
    'tallyAddItem': 'Add Record',
    'tallyItemName': 'Record Name',
    'recordNameRequired': 'Record name cannot be empty',
    'tallyClear': 'Clear',
    'tallySummary': 'Summary',
    'tallyRenameItem': 'Rename Record',
    'tallyDeleteItem': 'Delete Record',
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
    'tallyAddStatusHint':
        'Add at least one status label (e.g. W-Worked, L-Leave)',
    'tallyCode': 'Code',
    'tallyStatusLabel': 'Description',
    'tallyPickColor': 'Pick Color',
    'tallyNameRequired': 'Tally name cannot be empty',
    'tallyDateError': 'Start date cannot be after end date',
    'tallyStatusRequired': 'You must add at least one status label',
    'tallyCodeRequired': 'Status code cannot be empty',
    'tallyCreateFailed': 'Failed to create tally',
    'tallyItemsLabel': 'Records',
    'tallyItem': 'Record',
    'tallyItemNameHint': 'e.g. Ali, Product A',
    'tallyNoItems': 'No records added yet',
    'tallyItemHeader': 'Record',
    'tallyEditTitle': 'Edit Tally',
    'tallyUpdateFailed': 'Failed to update tally',
    'tallyDeleteStatusWarning':
        'Data in cells using deleted statuses will be removed',
    'duplicateStatusCode': 'Each status code can only be used once.',
    'goToToday': 'Go to today',
    'tallyTools': 'Tally tools',
    'overallSummary': 'Overall summary',
    'reorderRows': 'Reorder rows',
    'searchPersonOrItem': 'Search records',
    'bulkMark': 'Bulk mark',
    'forToday': 'For today',
    'chooseDateRange': 'Or choose a date range',
    'undoLastAction': 'Undo last action',
    'joinTable': 'Join a table',
    'joinCode': 'Join code',
    'joinPassword': 'Password',
    'joinPasswordOptional': 'Password (if any)',
    'yourName': 'Your name',
    'joinAction': 'Join',
    'saveToCloud': 'Save to cloud',
    'syncSending': 'Sending…',
    'syncUpToDate': 'Up to date',
    'reviewConflicts': 'Review',
    'conflictTitle': 'Conflicting rows',
    'conflictExplainer':
        'Someone else changed these rows while you were editing them. Choose which version to keep for each.',
    'conflictRowChanged': 'Someone else changed this row too',
    'conflictRowDeleted': 'Someone else deleted this row',
    'conflictRowGone': '(row is gone)',
    'conflictMine': 'Yours',
    'conflictTheirs': 'On record',
    'conflictKeepMine': 'Keep mine',
    'conflictKeepTheirs': 'Keep theirs',
    'pendingChangeCount': '{n} changes waiting',
    'conflictCount': '{n} rows conflicted',
    'joinTableExplainer':
        'Enter the code you were given. No account needed — just the name '
        'you will appear under in this table.',
    'yourNameHint':
        'The person sharing the table sees your changes under this name.',
    'joinedTable': 'You joined {name}.',
    'sharedTableMembers': 'Members',
    'activityLog': 'Change history',
    'activityLogOwnerOnly':
        'Only the person who shared the table sees this history.',
    'shareExplainer':
        'Generate a code and tell the other person. They need no account, just a name.',
    'codeHiddenExplainer':
        'This table is shared. The code is not kept for security; generate a new one if you forgot it.',
    'startSharing': 'Start sharing',
    'stopSharing': 'Stop sharing',
    'newCode': 'Generate a new code',
    'joinPasswordHint':
        'Leave empty to remove the password. At least 4 characters.',
    'passwordSaved': 'Password saved.',
    'passwordRemoved': 'Password removed.',
    'noMembersYet': 'Nobody has joined yet.',
    'noActivityYet': 'No changes yet.',
    'activityJoined': 'joined the table',
    'activityRowAdded': 'added a row',
    'activityRowDeleted': 'deleted a row',
    'activityActorSelf': 'You',
    'activityItemAdded': 'added an item',
    'activityItemDeleted': 'deleted an item',
    'activityColumnsChanged': 'changed the structure',
    'sharedStructureLockedTitle': 'Structure locked',
    'sharedStructureLocked':
        'Only the person who shared this can change its structure. You can '
        'still edit records and marks.',
    'copy': 'Copy',
    'copied': 'Copied',
    'err_authentication_required': 'Could not connect. Try again.',
    'err_invalid_table_code': 'No table for that code. Check the code.',
    'err_invalid_table_password': 'Wrong password.',
    'err_owner_premium_required':
        'The person sharing this table has no active subscription.',
    'err_invalid_display_name': 'A name must be 2-32 characters.',
    'err_display_name_taken':
        'That name is taken in this table. Try another one.',
    'err_too_many_attempts': 'Too many attempts. Try again in a little while.',
    'err_table_not_found': 'Table not found.',
    'err_password_too_short': 'A password must be at least 4 characters.',
    'err_shared_table_needs_upgrade':
        'The cloud copy is in an older format. The person sharing it needs to save once.',
    'err_shared_table_locked_by_other':
        'Someone is changing the table structure right now. Try again shortly.',
    'err_shared_table_edit_access_required':
        'You do not have edit access to this table.',
    'err_shared_table_revision_conflict':
        'The table changed while you were looking. Refresh and try again.',
    'err_unknown': 'Something went wrong. Try again.',
    'redoLastAction': 'Redo last action',
    'done': 'Done',
    'selectAll': 'Select all',
    'apply': 'Apply',
    'status': 'Status',
    'csvImportDescription':
        'The first row is treated as column names. A preview is shown before importing.',
    'selectFile': 'Select File',
    'selectAnotherFile': 'Choose Another File',
    'fileCouldNotBeRead': 'The file could not be read.',
    'csvEmptyOrTooLarge': 'The CSV file is empty or exceeds the 10 MB limit.',
    'csvHeaderMissing': 'The CSV header row could not be found.',
    'csvTooManyRows': 'A CSV file can contain at most 10,000 records.',
    'csvInvalid': 'The CSV file is not in a valid format.',
    'csvImportedTable': 'CSV Import',
    'cloudOperationFailed':
        'The cloud operation could not be completed. Check your connection and try again.',
    'accountOperationFailed':
        'The account operation could not be completed. Check your connection and try again.',
    'exportFailed': 'The file could not be created. Please try again.',
    'tallyTemplates': 'Tally Templates',
    'tallyTemplateCreate': 'Create Template',
    'tallyTemplateEdit': 'Edit Template',
    'tallyTemplateName': 'Template Name',
    'tallyTemplateNameHint': 'e.g. Monthly Attendance Template',
    'tallyTemplateNameRequired': 'Template name cannot be empty',
    'tallyTemplateCreateFailed': 'Failed to create template',
    'tallyTemplateUpdateFailed': 'Failed to update template',
    'tallyTemplateDelete': 'Delete Template',
    'tallyTemplateDeleteConfirm':
        'Are you sure you want to delete "{name}" template?',
    'tallyNoTemplates': 'No tally templates yet',
    'tallyNoTemplatesHint':
        'Save your frequently used statuses and records as templates',
    'tallyCreateNewTemplate': 'Create New Template',
    'tallyFromTemplate': 'From Template',
    'tallyCreateFromTemplate': 'Create Tally from Template',
    'tallyTemplateStatusItemCount': '{s} statuses • {i} records',
    'tallyIncludeItems': 'Include records',
    'tallyIncludeItemsHint':
        'Record names from the template will be added to the new tally',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['tr', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
