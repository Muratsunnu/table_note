import 'package:flutter/foundation.dart';
import 'package:table_note/models/tabel_model.dart';
import '../services/storage_service.dart';

class TableProvider extends ChangeNotifier {
  List<TableModel> _tables = [];
  int _currentTableIndex = 0;
  bool _isLoading = false;

  // Getters
  List<TableModel> get tables => _tables;
  TableModel? get currentTable => _tables.isNotEmpty ? _tables[_currentTableIndex] : null;
  int get currentTableIndex => _currentTableIndex;
  bool get isLoading => _isLoading;
  bool get hasTables => _tables.isNotEmpty;

  TableProvider() {
    _loadTables();
  }

  // Tabloları yükle
  Future<void> _loadTables() async {
    _isLoading = true;
    notifyListeners();
    
    _tables = await StorageService.loadTables();
    
    _isLoading = false;
    notifyListeners();
  }

  // Tabloları kaydet
  Future<void> _saveTables() async {
    await StorageService.saveTables(_tables);
  }

  // Yeni tablo oluştur
  Future<bool> createTable(String tableName, List<String> columns) async {
    try {
      final newTable = TableModel(
        tableName: tableName.trim(),
        columns: columns.map((col) => col.trim()).toList(),
        rows: [],
      );
      
      _tables.add(newTable);
      _currentTableIndex = _tables.length - 1;
      await _saveTables();
      notifyListeners();
      return true;
    } catch (e) {
      print('Tablo oluşturulurken hata: $e');
      return false;
    }
  }

  // Aktif tabloyu değiştir
  void changeTable(int index) {
    if (index >= 0 && index < _tables.length) {
      _currentTableIndex = index;
      notifyListeners();
    }
  }

  // Satır ekle
  Future<bool> addRow(List<String> rowData) async {
    try {
      if (currentTable != null) {
        _tables[_currentTableIndex].rows.add(rowData);
        await _saveTables();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Satır eklenirken hata: $e');
      return false;
    }
  }

  // Satır güncelle
  Future<bool> updateRow(int rowIndex, List<String> newRowData) async {
    try {
      if (currentTable != null && rowIndex < currentTable!.rows.length) {
        _tables[_currentTableIndex].rows[rowIndex] = newRowData;
        await _saveTables();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Satır güncellenirken hata: $e');
      return false;
    }
  }

  // Satır sil
  Future<bool> deleteRow(int rowIndex) async {
    try {
      if (currentTable != null && rowIndex < currentTable!.rows.length) {
        _tables[_currentTableIndex].rows.removeAt(rowIndex);
        await _saveTables();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Satır silinirken hata: $e');
      return false;
    }
  }

  // Tablo sil
  Future<bool> deleteTable(int tableIndex) async {
    try {
      if (tableIndex >= 0 && tableIndex < _tables.length) {
        _tables.removeAt(tableIndex);
        
        // Aktif tablo indeksini ayarla
        if (_currentTableIndex >= _tables.length) {
          _currentTableIndex = _tables.length - 1;
        }
        if (_currentTableIndex < 0) _currentTableIndex = 0;
        
        await _saveTables();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Tablo silinirken hata: $e');
      return false;
    }
  }

  // Tüm verileri temizle
  Future<bool> clearAllData() async {
    try {
      _tables.clear();
      _currentTableIndex = 0;
      await StorageService.clearAllData();
      notifyListeners();
      return true;
    } catch (e) {
      print('Tüm veriler temizlenirken hata: $e');
      return false;
    }
  }
}