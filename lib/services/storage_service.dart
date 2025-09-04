import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tabel_model.dart';
import 'dart:convert';


class StorageService {
  static const String _tablesKey = 'tables';

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

  // Tüm verileri temizle
  static Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_tablesKey);
    } catch (e) {
      print('Veriler temizlenirken hata oluştu: $e');
      return false;
    }
  }
}