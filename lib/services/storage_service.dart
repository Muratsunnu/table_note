import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/shared_row_operation.dart';
import 'package:table_note/models/shared_tally_operation.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/table_sort_preference.dart';
import 'package:table_note/models/tally_sort_preference.dart';
import 'package:table_note/models/tally_model.dart';

class StorageService {
  /// 3 added a stable identity to every table row. A v2 save is rewritten
  /// once on load so those identities stop changing between launches.
  static const int _schemaVersion = 3;
  static const String _tablesKey = 'tables';
  static const String _templatesKey = 'templates';
  static const String _lastOpenedTableIndexKey = 'last_opened_table_index';
  static const String _tallyTablesKey = 'tally_tables';
  static const String _lastOpenedTallyIndexKey = 'last_opened_tally_index';
  static const String _tallyTemplatesKey = 'tally_templates';
  static const String _lastTabKey = 'last_active_tab';
  static const String _tableSortsKey = 'table_sorts_v1';
  static const String _tallySortsKey = 'tally_sorts_v1';
  static const String _sharedDisplayNameKey = 'shared_display_name';
  static const String _pendingRowChangesKey = 'pending_row_changes_v1';
  static const String _sharedTableRolesKey = 'shared_table_roles_v1';
  static const String _pendingTallyChangesKey = 'pending_tally_changes_v1';
  static const String _sharedTallyRolesKey = 'shared_tally_roles_v1';
  static const String _sharedVersionsKey = 'shared_known_versions_v1';
  static const String _legacyPlanKey = 'plan_legacy_unlimited_v1';
  static const String _legacyBackupSuffix = '_legacy_v1_backup';

  /// Kayitli olabilecek roller. Tanimadigimiz bir deger okunursa atilir;
  /// 'viewer' buraya eklenmeseydi goruntuleyen kisinin tablosu uygulama
  /// yeniden acildiginda ortak olmaktan cikar, siradan bir tablo gibi
  /// duzenlenebilir hale gelirdi.
  static const _sharedRoles = {'owner', 'editor', 'viewer'};

  /// Hangi tablonun ortak oldugu ve bu cihazin oradaki rolu: 'owner' tabloyu
  /// paylasan kisi; 'editor' ve 'viewer' koda katilan kisi (duzenleyebilen
  /// ve yalnizca goruntuleyen). Sahip ve duzenleyenin degisiklikleri kisa bir
  /// gecikmeyle kendiliginden gider; goruntuleyen hic gondermez.
  static Future<Map<String, String>> loadSharedTableRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sharedTableRolesKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (_sharedRoles.contains(entry.value))
            entry.key.toString(): entry.value.toString(),
      };
    } catch (e) {
      debugPrint('Ortak tablo rolleri okunamadi: $e');
      return {};
    }
  }

  /// Bu cihaz, ucretsiz sinirlar gelmeden onceki surumu kullanmis mi?
  ///
  /// Karar bir kez verilir ve saklanir: sinirlarin geldigi surum ilk
  /// acildiginda cihazda onceden kalma tablo, cetele ya da sablon varsa
  /// kullanici eskidir ve sinirsiz kalir. Hicbir sey yoksa yeni kurulumdur.
  ///
  /// Uygulama acilirken, saglayicilar veriyi okuyup yazmaya baslamadan once
  /// cagrilmalidir; yoksa yeni kullanicinin ilk tablosu "onceden kalma veri"
  /// sayilabilirdi.
  static Future<bool> resolveLegacyUnlimited() async {
    final prefs = await SharedPreferences.getInstance();
    final decided = prefs.getBool(_legacyPlanKey);
    if (decided != null) return decided;
    final legacy = [
      _tablesKey,
      _tallyTablesKey,
      _templatesKey,
      _tallyTemplatesKey,
    ].any((key) => _hasStoredItems(prefs.getString(key)));
    await prefs.setBool(_legacyPlanKey, legacy);
    return legacy;
  }

  static bool _hasStoredItems(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = json.decode(raw);
      if (decoded is List) return decoded.isNotEmpty;
      if (decoded is Map) {
        return decoded.values.any((value) => value is List && value.isNotEmpty);
      }
      return false;
    } catch (_) {
      // Okunamayan bir kayit da kayittir; supheli durumda kullanicinin
      // elinden bir sey alinmaz.
      return true;
    }
  }

  /// Ortak tablolarin bu cihazda duran halinin sunucudaki hangi surume
  /// karsilik geldigi. Uygulama her acildiginda tablonun tamamini yeniden
  /// indirmemek icin saklanir: surum ayniysa indirilecek bir sey yoktur.
  static Future<Map<String, Map<String, dynamic>>> loadSharedVersions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sharedVersionsKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map && entry.value['revision'] is int)
            entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
      };
    } catch (e) {
      debugPrint('Ortak tablo surumleri okunamadi: $e');
      return {};
    }
  }

  static Future<bool> saveSharedVersions(
    Map<String, Map<String, dynamic>> versions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (versions.isEmpty) return prefs.remove(_sharedVersionsKey);
    return prefs.setString(_sharedVersionsKey, json.encode(versions));
  }

  static Future<bool> saveSharedTableRoles(Map<String, String> roles) async {
    final prefs = await SharedPreferences.getInstance();
    if (roles.isEmpty) return prefs.remove(_sharedTableRolesKey);
    return prefs.setString(_sharedTableRolesKey, json.encode(roles));
  }

  /// Cetelelerin ortak calisma rolleri. Tablolarinkiyle ayni bicim ama ayri
  /// anahtar: tek harita paylasilsaydi iki saglayici birbirinin kaydini
  /// ezerdi, cunku her biri kendi haritasinin tamamini yaziyor.
  static Future<Map<String, String>> loadSharedTallyRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sharedTallyRolesKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (_sharedRoles.contains(entry.value))
            entry.key.toString(): entry.value.toString(),
      };
    } catch (e) {
      debugPrint('Ortak cetele rolleri okunamadi: $e');
      return {};
    }
  }

  static Future<bool> saveSharedTallyRoles(Map<String, String> roles) async {
    final prefs = await SharedPreferences.getInstance();
    if (roles.isEmpty) return prefs.remove(_sharedTallyRolesKey);
    return prefs.setString(_sharedTallyRolesKey, json.encode(roles));
  }

  /// Buluta gonderilmeyi bekleyen cetele degisiklikleri, cetele kimligine gore.
  static Future<Map<String, PendingTallyChanges>>
  loadPendingTallyChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingTallyChangesKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          entry.key.toString(): PendingTallyChanges.fromJson(entry.value),
      };
    } catch (e) {
      debugPrint('Bekleyen cetele degisiklikleri okunamadi: $e');
      return {};
    }
  }

  static Future<bool> savePendingTallyChanges(
    Map<String, PendingTallyChanges> pending,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        for (final entry in pending.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.toJson(),
      };
      if (payload.isEmpty) {
        return prefs.remove(_pendingTallyChangesKey);
      }
      return prefs.setString(_pendingTallyChangesKey, json.encode(payload));
    } catch (e) {
      debugPrint('Bekleyen cetele degisiklikleri kaydedilemedi: $e');
      return false;
    }
  }

  /// Buluta gonderilmeyi bekleyen satir degisiklikleri, tablo kimligine gore.
  /// Cevrimdisi yapilan duzenleme uygulama kapanip acilinca da beklemeye
  /// devam eder.
  static Future<Map<String, PendingRowChanges>> loadPendingRowChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingRowChangesKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          entry.key.toString(): PendingRowChanges.fromJson(entry.value),
      };
    } catch (e) {
      debugPrint('Bekleyen degisiklikler okunamadi: $e');
      return {};
    }
  }

  static Future<bool> savePendingRowChanges(
    Map<String, PendingRowChanges> pending,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        for (final entry in pending.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.toJson(),
      };
      if (payload.isEmpty) {
        return prefs.remove(_pendingRowChangesKey);
      }
      return prefs.setString(_pendingRowChangesKey, json.encode(payload));
    } catch (e) {
      debugPrint('Bekleyen degisiklikler kaydedilemedi: $e');
      return false;
    }
  }

  /// Katilirken girilen ad. Bir kez yazildiktan sonra sonraki tablolarda
  /// hazir gelir; kullanici yine de onaylar, cunku ad o tabloda dolu olabilir.
  static Future<String?> loadSharedDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_sharedDisplayNameKey)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  static Future<void> saveSharedDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_sharedDisplayNameKey);
    } else {
      await prefs.setString(_sharedDisplayNameKey, trimmed);
    }
  }

  static Future<void> _preserveLegacyPayload(
    SharedPreferences prefs,
    String key,
    String raw,
  ) async {
    final backupKey = '$key$_legacyBackupSuffix';
    if (!prefs.containsKey(backupKey)) {
      await prefs.setString(backupKey, raw);
    }
  }

  static _DecodedCollection<T> _decodeCollection<T>(
    String raw,
    T Function(Map<String, dynamic>) decoder,
  ) {
    final decoded = json.decode(raw);
    late final List<dynamic> data;
    late final bool isLegacy;
    var isOutdated = false;

    if (decoded is List) {
      data = decoded;
      isLegacy = true;
    } else if (decoded is Map<String, dynamic>) {
      final version = decoded['schemaVersion'];
      if (version is int && version > _schemaVersion) {
        throw const FormatException('Desteklenmeyen veri sürümü');
      }
      isOutdated = version is! int || version < _schemaVersion;
      final envelopeData = decoded['data'];
      if (envelopeData is! List) {
        throw const FormatException('Geçersiz veri zarfı');
      }
      data = envelopeData;
      isLegacy = false;
    } else {
      throw const FormatException('Geçersiz kayıt biçimi');
    }

    return _DecodedCollection(
      data
          .map((item) => decoder(Map<String, dynamic>.from(item as Map)))
          .toList(),
      isLegacy: isLegacy,
      isOutdated: isOutdated,
    );
  }

  static Future<bool> _saveCollection<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) encoder,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final envelope = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'data': items.map(encoder).toList(),
    };
    return prefs.setString(key, json.encode(envelope));
  }

  // Tabloları yükle
  static Future<List<TableModel>> loadTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tablesJson = prefs.getString(_tablesKey);

      if (tablesJson == null) return [];

      final decoded = _decodeCollection(tablesJson, TableModel.fromJson);
      if (decoded.isLegacy || decoded.isOutdated) {
        // Row identities were just minted for this payload; write them back
        // now, or they would be different again on the next launch.
        await _preserveLegacyPayload(prefs, _tablesKey, tablesJson);
        await saveTables(decoded.items);
      }
      return decoded.items;
    } catch (e) {
      debugPrint('Tablolar yüklenirken hata oluştu: $e');
      return [];
    }
  }

  // Tabloları kaydet
  static Future<bool> saveTables(List<TableModel> tables) async {
    try {
      return await _saveCollection<TableModel>(
        _tablesKey,
        tables,
        (table) => table.toJson(),
      );
    } catch (e) {
      debugPrint('Tablolar kaydedilirken hata oluştu: $e');
      return false;
    }
  }

  // Template'ları yükle
  static Future<List<TemplateModel>> loadTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getString(_templatesKey);

      if (templatesJson == null) return [];

      final decoded = _decodeCollection(templatesJson, TemplateModel.fromJson);
      if (decoded.isLegacy) {
        await _preserveLegacyPayload(prefs, _templatesKey, templatesJson);
        await saveTemplates(decoded.items);
      }
      return decoded.items;
    } catch (e) {
      debugPrint('Template\'ler yüklenirken hata oluştu: $e');
      return [];
    }
  }

  // Template'ları kaydet
  static Future<bool> saveTemplates(List<TemplateModel> templates) async {
    try {
      return await _saveCollection<TemplateModel>(
        _templatesKey,
        templates,
        (template) => template.toJson(),
      );
    } catch (e) {
      debugPrint('Template\'ler kaydedilirken hata oluştu: $e');
      return false;
    }
  }

  // Son açılan tablo indexini kaydet
  static Future<bool> saveLastOpenedTableIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(_lastOpenedTableIndexKey, index);
    } catch (e) {
      debugPrint('Son açılan tablo indexi kaydedilirken hata oluştu: $e');
      return false;
    }
  }

  // Son açılan tablo indexini yükle
  static Future<int> loadLastOpenedTableIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastOpenedTableIndexKey) ?? 0;
    } catch (e) {
      debugPrint('Son açılan tablo indexi yüklenirken hata oluştu: $e');
      return 0;
    }
  }

  // Tablo sıralama tercihlerini kaydet (tablo kimliğine göre)
  static Future<bool> saveTableSorts(
    Map<String, TableSortPreference> sorts,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        _tableSortsKey,
        jsonEncode({
          for (final entry in sorts.entries) entry.key: entry.value.toJson(),
        }),
      );
    } catch (e) {
      debugPrint('Sıralama tercihleri kaydedilirken hata oluştu: $e');
      return false;
    }
  }

  // Tablo sıralama tercihlerini yükle; bozuk kayıtlar yok sayılır
  static Future<Map<String, TableSortPreference>> loadTableSorts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tableSortsKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final sorts = <String, TableSortPreference>{};
      decoded.forEach((key, value) {
        final preference = TableSortPreference.fromJson(value);
        if (key is String && preference != null) sorts[key] = preference;
      });
      return sorts;
    } catch (e) {
      debugPrint('Sıralama tercihleri yüklenirken hata oluştu: $e');
      return {};
    }
  }

  // Çetele sıralama tercihlerini kaydet (çetele kimliğine göre)
  static Future<bool> saveTallySorts(
    Map<String, TallySortPreference> sorts,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        _tallySortsKey,
        jsonEncode({
          for (final entry in sorts.entries) entry.key: entry.value.toJson(),
        }),
      );
    } catch (e) {
      debugPrint('Çetele sıralama tercihleri kaydedilirken hata oluştu: $e');
      return false;
    }
  }

  // Çetele sıralama tercihlerini yükle; bozuk kayıtlar yok sayılır
  static Future<Map<String, TallySortPreference>> loadTallySorts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tallySortsKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final sorts = <String, TallySortPreference>{};
      decoded.forEach((key, value) {
        final preference = TallySortPreference.fromJson(value);
        if (key is String && preference != null) sorts[key] = preference;
      });
      return sorts;
    } catch (e) {
      debugPrint('Çetele sıralama tercihleri yüklenirken hata oluştu: $e');
      return {};
    }
  }

  // Tüm verileri temizle
  static Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tablesKey);
      await prefs.remove(_templatesKey);
      await prefs.remove(_lastOpenedTableIndexKey);
      await prefs.remove(_tallyTablesKey);
      await prefs.remove(_lastOpenedTallyIndexKey);
      await prefs.remove(_tallyTemplatesKey);
      await prefs.remove(_lastTabKey);
      await prefs.remove(_tableSortsKey);
      await prefs.remove(_tallySortsKey);
      await prefs.remove('$_tablesKey$_legacyBackupSuffix');
      await prefs.remove('$_templatesKey$_legacyBackupSuffix');
      await prefs.remove('$_tallyTablesKey$_legacyBackupSuffix');
      await prefs.remove('$_tallyTemplatesKey$_legacyBackupSuffix');
      return true;
    } catch (e) {
      debugPrint('Veriler temizlenirken hata oluştu: $e');
      return false;
    }
  }

  // ============== ÇETELE TABLOLARI ==============

  static Future<List<TallyTableModel>> loadTallyTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_tallyTablesKey);
      if (data == null) return [];

      final decoded = _decodeCollection(data, TallyTableModel.fromJson);
      if (decoded.isLegacy) {
        await _preserveLegacyPayload(prefs, _tallyTablesKey, data);
        await saveTallyTables(decoded.items);
      }
      return decoded.items;
    } catch (e) {
      debugPrint('Çetele tabloları yüklenirken hata: $e');
      return [];
    }
  }

  static Future<bool> saveTallyTables(List<TallyTableModel> tables) async {
    try {
      return await _saveCollection<TallyTableModel>(
        _tallyTablesKey,
        tables,
        (table) => table.toJson(),
      );
    } catch (e) {
      debugPrint('Çetele tabloları kaydedilirken hata: $e');
      return false;
    }
  }

  static Future<int> loadLastOpenedTallyIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastOpenedTallyIndexKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<bool> saveLastOpenedTallyIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(_lastOpenedTallyIndexKey, index);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> clearTallyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tallyTablesKey);
      await prefs.remove(_lastOpenedTallyIndexKey);
      await prefs.remove(_tallyTemplatesKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============== ÇETELE ŞABLONLARI ==============

  static Future<List<TallyTemplateModel>> loadTallyTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_tallyTemplatesKey);
      if (data == null) return [];

      final decoded = _decodeCollection(data, TallyTemplateModel.fromJson);
      if (decoded.isLegacy) {
        await _preserveLegacyPayload(prefs, _tallyTemplatesKey, data);
        await saveTallyTemplates(decoded.items);
      }
      return decoded.items;
    } catch (e) {
      debugPrint('Çetele şablonları yüklenirken hata: $e');
      return [];
    }
  }

  static Future<bool> saveTallyTemplates(
    List<TallyTemplateModel> templates,
  ) async {
    try {
      return await _saveCollection<TallyTemplateModel>(
        _tallyTemplatesKey,
        templates,
        (template) => template.toJson(),
      );
    } catch (e) {
      debugPrint('Çetele şablonları kaydedilirken hata: $e');
      return false;
    }
  }

  // ============== SON AKTİF TAB ==============

  static Future<bool> saveLastActiveTab(int tabIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(_lastTabKey, tabIndex);
    } catch (e) {
      return false;
    }
  }

  static Future<int> loadLastActiveTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastTabKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}

class _DecodedCollection<T> {
  final List<T> items;
  final bool isLegacy;

  /// The payload was written by an older schema, so whatever the decoder
  /// filled in for it has to be written back before it is used again.
  final bool isOutdated;

  const _DecodedCollection(
    this.items, {
    required this.isLegacy,
    this.isOutdated = false,
  });
}
