import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/tally_model.dart';
import 'dart:convert';

class StorageService {
  static const String _tablesKey = 'tables';
  static const String _templatesKey = 'templates';
  static const String _lastOpenedTableIndexKey = 'last_opened_table_index';
  static const String _tallyTablesKey = 'tally_tables';
  static const String _lastOpenedTallyIndexKey = 'last_opened_tally_index';
  static const String _lastTabKey = 'last_active_tab';

  // Tabloları yükle
  static Future<List<TableModel>> loadTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tablesJson = prefs.getString(_tablesKey);
      
      if (tablesJson != null) {
        final List<dynamic> tablesList = json.decode(tablesJson);
        return tablesList.map((table) => TableModel.fromJson(table)).toList();
      }
      
      return [];
    } catch (e) {
      print('Tablolar yüklenirken hata oluştu: $e');
      return [];
    }
  }

  // Tabloları kaydet
  static Future<bool> saveTables(List<TableModel> tables) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tablesJson = json.encode(tables.map((table) => table.toJson()).toList());
      return await prefs.setString(_tablesKey, tablesJson);
    } catch (e) {
      print('Tablolar kaydedilirken hata oluştu: $e');
      return false;
    }
  }

  // Template'ları yükle
  static Future<List<TemplateModel>> loadTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getString(_templatesKey);
      
      if (templatesJson != null) {
        final List<dynamic> templatesList = json.decode(templatesJson);
        return templatesList.map((template) => TemplateModel.fromJson(template)).toList();
      }
      
      return [];
    } catch (e) {
      print('Template\'ler yüklenirken hata oluştu: $e');
      return [];
    }
  }

  // Template'ları kaydet
  static Future<bool> saveTemplates(List<TemplateModel> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = json.encode(templates.map((template) => template.toJson()).toList());
      return await prefs.setString(_templatesKey, templatesJson);
    } catch (e) {
      print('Template\'ler kaydedilirken hata oluştu: $e');
      return false;
    }
  }

  // Son açılan tablo indexini kaydet
  static Future<bool> saveLastOpenedTableIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(_lastOpenedTableIndexKey, index);
    } catch (e) {
      print('Son açılan tablo indexi kaydedilirken hata oluştu: $e');
      return false;
    }
  }

  // Son açılan tablo indexini yükle
  static Future<int> loadLastOpenedTableIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastOpenedTableIndexKey) ?? 0;
    } catch (e) {
      print('Son açılan tablo indexi yüklenirken hata oluştu: $e');
      return 0;
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
      await prefs.remove(_lastTabKey);
      return true;
    } catch (e) {
      print('Veriler temizlenirken hata oluştu: $e');
      return false;
    }
  }

  // ============== ÇETELE TABLOLARI ==============

  static Future<List<TallyTableModel>> loadTallyTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_tallyTablesKey);
      if (data != null) {
        final List<dynamic> list = json.decode(data);
        return list.map((t) => TallyTableModel.fromJson(t)).toList();
      }
      return [];
    } catch (e) {
      print('Çetele tabloları yüklenirken hata: $e');
      return [];
    }
  }

  static Future<bool> saveTallyTables(List<TallyTableModel> tables) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = json.encode(tables.map((t) => t.toJson()).toList());
      return await prefs.setString(_tallyTablesKey, data);
    } catch (e) {
      print('Çetele tabloları kaydedilirken hata: $e');
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
      return true;
    } catch (e) {
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