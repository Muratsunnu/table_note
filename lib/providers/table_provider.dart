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
  Future<bool> createTable(String tableName, List<ColumnModel> columns) async {
    try {
      final newTable = TableModel(
        tableName: tableName.trim(),
        columns: columns,
        rows: [], id: '', name: '', createdAt: DateTime.now(),
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

  // Tablo adını değiştir
  Future<bool> renameTable(int tableIndex, String newName) async {
    try {
      if (tableIndex >= 0 && tableIndex < _tables.length && newName.trim().isNotEmpty) {
        _tables[tableIndex].tableName = newName.trim();
        await _saveTables();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Tablo adı değiştirilirken hata: $e');
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

  // Sayısal sütunları topla
  Map<String, double> calculateColumnSums() {
    Map<String, double> sums = {};
    
    if (currentTable == null) return sums;

    for (int colIndex = 0; colIndex < currentTable!.columns.length; colIndex++) {
      final column = currentTable!.columns[colIndex];
      
      if (column.isNumeric) {
        double sum = 0;
        for (var row in currentTable!.rows) {
          if (colIndex < row.length) {
            final value = double.tryParse(row[colIndex]) ?? 0;
            sum += value;
          }
        }
        sums[column.name] = sum;
      }
    }
    
    return sums;
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