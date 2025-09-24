import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tabel_model.dart';
import 'dart:convert';

class StorageService {
  static const String _tablesKey = 'tables';
  static const String _templatesKey = 'templates';

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

  // Tüm verileri temizle
  static Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tablesKey);
      await prefs.remove(_templatesKey);
      return true;
    } catch (e) {
      print('Veriler temizlenirken hata oluştu: $e');
      return false;
    }
  }
}
