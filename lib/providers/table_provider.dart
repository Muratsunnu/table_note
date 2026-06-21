import 'package:flutter/foundation.dart';
import 'package:table_note/models/tabel_model.dart';
import '../services/storage_service.dart';

class TableProvider extends ChangeNotifier {
  List<TableModel> _tables = [];
  int _currentTableIndex = 0;
  bool _isLoading = false;
  
  // Filtreleme için state
  String _searchQuery = '';
  List<int> _filteredRowIndices = [];

  // Getters
  List<TableModel> get tables => _tables;
  TableModel? get currentTable => _tables.isNotEmpty ? _tables[_currentTableIndex] : null;
  int get currentTableIndex => _currentTableIndex;
  bool get isLoading => _isLoading;
  bool get hasTables => _tables.isNotEmpty;
  
  // Filtreleme getters
  String get searchQuery => _searchQuery;
  bool get isFiltering => _searchQuery.isNotEmpty;
  List<int> get filteredRowIndices => _filteredRowIndices;
  
  // Filtrelenmiş satırları döndür
  List<List<String>> get filteredRows {
    if (currentTable == null) return [];
    if (!isFiltering) return currentTable!.rows;
    
    return _filteredRowIndices
        .where((index) => index < currentTable!.rows.length)
        .map((index) => currentTable!.rows[index])
        .toList();
  }
  
  // Filtrelenmiş satır sayısı
  int get filteredRowCount => isFiltering ? _filteredRowIndices.length : (currentTable?.rows.length ?? 0);
  int get totalRowCount => currentTable?.rows.length ?? 0;

  TableProvider() {
    _loadTables();
  }

  // Tabloları yükle
  Future<void> _loadTables() async {
    _isLoading = true;
    notifyListeners();
    
    _tables = await StorageService.loadTables();
    
    // Son açılan tablo indexini yükle
    if (_tables.isNotEmpty) {
      final lastIndex = await StorageService.loadLastOpenedTableIndex();
      // Index geçerli mi kontrol et
      if (lastIndex >= 0 && lastIndex < _tables.length) {
        _currentTableIndex = lastIndex;
      } else {
        _currentTableIndex = 0;
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Tabloları kaydet
  Future<void> _saveTables() async {
    await StorageService.saveTables(_tables);
  }

  // Son açılan tablo indexini kaydet
  Future<void> _saveLastOpenedTableIndex() async {
    await StorageService.saveLastOpenedTableIndex(_currentTableIndex);
  }

  // === FİLTRELEME FONKSİYONLARI ===
  
  // Arama sorgusunu ayarla ve filtrele
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applyFilter();
    notifyListeners();
  }
  
  // Aramayı temizle
  void clearSearch() {
    _searchQuery = '';
    _filteredRowIndices.clear();
    notifyListeners();
  }
  
  // Filtreleme uygula
  void _applyFilter() {
    if (currentTable == null || _searchQuery.isEmpty) {
      _filteredRowIndices.clear();
      return;
    }
    
    _filteredRowIndices = [];
    
    for (int rowIndex = 0; rowIndex < currentTable!.rows.length; rowIndex++) {
      final row = currentTable!.rows[rowIndex];
      
      // Satırdaki herhangi bir hücre arama sorgusunu içeriyor mu?
      bool matches = row.any((cell) => 
        cell.toLowerCase().contains(_searchQuery)
      );
      
      if (matches) {
        _filteredRowIndices.add(rowIndex);
      }
    }
  }
  
  // Filtrelenmiş satırların sayısal sütun toplamlarını hesapla
  // NOT: Sabit değer ve sıra numarası sütunları toplamdan hariç tutulur
  Map<String, double> calculateFilteredColumnSums() {
    Map<String, double> sums = {};
    
    if (currentTable == null) return sums;
    
    // Hangi satırları toplayacağız?
    final rowsToSum = isFiltering ? filteredRows : currentTable!.rows;
    
    for (int colIndex = 0; colIndex < currentTable!.columns.length; colIndex++) {
      final column = currentTable!.columns[colIndex];
      
      // Sabit değer sütunlarını toplama dahil etme
      if (column.isConstant) {
        continue;
      }
      
      // Sıra numarası sütunlarını toplama dahil etme
      if (column.isAutoNumber) {
        continue;
      }
      
      // Normal sayısal sütunlar ve formül sütunları toplanabilir
      if (column.isNumeric || column.isFormula) {
        double sum = 0;
        for (var row in rowsToSum) {
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
      clearSearch();
      await _saveTables();
      await _saveLastOpenedTableIndex();
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
      clearSearch();
      _saveLastOpenedTableIndex(); // Son açılan tabloyu kaydet
      notifyListeners();
    }
  }

  // Sayısal sütunları topla (geriye uyumluluk)
  Map<String, double> calculateColumnSums() {
    return calculateFilteredColumnSums();
  }

  // Satır ekle
  Future<bool> addRow(List<String> rowData) async {
    try {
      if (currentTable != null) {
        _tables[_currentTableIndex].rows.add(rowData);
        _applyFilter();
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
        _applyFilter();
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
        _applyFilter();
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
        
        clearSearch();
        await _saveTables();
        await _saveLastOpenedTableIndex();
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
      clearSearch();
      await StorageService.clearAllData();
      notifyListeners();
      return true;
    } catch (e) {
      print('Tüm veriler temizlenirken hata: $e');
      return false;
    }
  }

  // Tablo yapısını güncelle (mevcut projede kullanılan imza)
  Future<bool> updateTableStructure(String newName, List<ColumnModel> newColumns, int originalColumnCount) async {
    try {
      if (currentTable == null) return false;
      
      final table = currentTable!;

      // Tablo adını güncelle
      table.tableName = newName.trim();
      
      // Mevcut sütunların eşleştirilmesi
      Map<int, int> columnMapping = {};
      for (int newIdx = 0; newIdx < newColumns.length && newIdx < originalColumnCount; newIdx++) {
        columnMapping[newIdx] = newIdx;
      }
      
      // Satırları yeni yapıya göre düzenle
      List<List<String>> newRows = [];
      for (var oldRow in table.rows) {
        List<String> newRow = List.filled(newColumns.length, '');
        
        // Mevcut sütunları kopyala
        for (int i = 0; i < originalColumnCount && i < oldRow.length && i < newColumns.length; i++) {
          newRow[i] = oldRow[i];
        }
        
        // Yeni sütunlar için varsayılan değerler
        for (int i = originalColumnCount; i < newColumns.length; i++) {
          final col = newColumns[i];
          if (col.isConstant && col.constantValue != null) {
            newRow[i] = col.constantValue.toString();
          } else if (col.isAutoNumber) {
            newRow[i] = (newRows.length + 1).toString();
          } else {
            newRow[i] = '';
          }
        }
        
        newRows.add(newRow);
      }
      
      // Tabloyu güncelle
      table.columns = newColumns;
      table.rows = newRows;
      
      await _saveTables();
      notifyListeners();
      return true;
    } catch (e) {
      print('Tablo yapısı güncellenirken hata: $e');
      return false;
    }
  }
}