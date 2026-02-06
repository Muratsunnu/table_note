import 'package:flutter/foundation.dart';
import 'package:table_note/models/tabel_model.dart';
import '../services/storage_service.dart';

class TableProvider extends ChangeNotifier {
  List<TableModel> _tables = [];
  int _currentTableIndex = 0;
  bool _isLoading = false;
  
  // Filtreleme için yeni state
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
    
    _isLoading = false;
    notifyListeners();
  }

  // Tabloları kaydet
  Future<void> _saveTables() async {
    await StorageService.saveTables(_tables);
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
      // (birim fiyat, katsayı gibi değerler toplanmamalı)
      if (column.isConstant) {
        continue;
      }
      
      // Sıra numarası sütunlarını toplama dahil etme
      // (1+2+3+4... toplamı anlamsız)
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
      clearSearch(); // Yeni tabloya geçince aramayı temizle
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

  // Tablo yapısını güncelle (sütun adları değiştirme ve yeni sütun ekleme)
  Future<bool> updateTableStructure(
    String newTableName,
    List<ColumnModel> newColumns,
    int originalColumnCount,
  ) async {
    try {
      if (currentTable == null) return false;

      // Tablo adını güncelle
      _tables[_currentTableIndex].tableName = newTableName.trim();

      // Mevcut sütun adlarını güncelle
      for (int i = 0; i < originalColumnCount && i < newColumns.length; i++) {
        _tables[_currentTableIndex].columns[i].name = newColumns[i].name.trim();
      }

      // Yeni sütunları ekle
      if (newColumns.length > originalColumnCount) {
        final newColumnsToAdd = newColumns.sublist(originalColumnCount);
        
        for (var newColumn in newColumnsToAdd) {
          // Sütunu tabloya ekle
          _tables[_currentTableIndex].columns.add(newColumn);
          
          // Mevcut satırlara yeni sütun için varsayılan değer ekle
          final defaultValue = _getDefaultValueForColumn(newColumn, _tables[_currentTableIndex].rows.length);
          
          for (int rowIndex = 0; rowIndex < _tables[_currentTableIndex].rows.length; rowIndex++) {
            String value = '';
            
            if (newColumn.isAutoNumber) {
              value = (rowIndex + 1).toString();
            } else if (newColumn.isConstant && newColumn.constantValue != null) {
              value = _formatNumber(newColumn.constantValue!);
            } else if (newColumn.isDate) {
              value = _getCurrentDateFormatted();
            } else if (newColumn.isTime) {
              value = _getCurrentTimeFormatted();
            }
            // Formül sütunları için değer sonradan hesaplanacak
            
            _tables[_currentTableIndex].rows[rowIndex].add(value);
          }
        }
      }

      await _saveTables();
      notifyListeners();
      return true;
    } catch (e) {
      print('Tablo yapısı güncellenirken hata: $e');
      return false;
    }
  }

  // Sütun tipi için varsayılan değer
  String _getDefaultValueForColumn(ColumnModel column, int rowCount) {
    if (column.isAutoNumber) {
      return (rowCount + 1).toString();
    } else if (column.isConstant && column.constantValue != null) {
      return _formatNumber(column.constantValue!);
    } else if (column.isDate) {
      return _getCurrentDateFormatted();
    } else if (column.isTime) {
      return _getCurrentTimeFormatted();
    }
    return '';
  }

  String _formatNumber(double value) {
    if (value == value.truncate()) {
      return value.truncate().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _getCurrentDateFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }

  String _getCurrentTimeFormatted() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // Aktif tabloyu değiştir
  void changeTable(int index) {
    if (index >= 0 && index < _tables.length) {
      _currentTableIndex = index;
      clearSearch(); // Tablo değişince aramayı temizle
      notifyListeners();
    }
  }

  // Sayısal sütunları topla (tüm satırlar için - eski fonksiyon, geriye uyumluluk)
  Map<String, double> calculateColumnSums() {
    return calculateFilteredColumnSums();
  }

  // Satır ekle
  Future<bool> addRow(List<String> rowData) async {
    try {
      if (currentTable != null) {
        _tables[_currentTableIndex].rows.add(rowData);
        _applyFilter(); // Yeni satır eklenince filtreyi güncelle
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
        _applyFilter(); // Satır güncellenince filtreyi güncelle
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
        
        // Sıra numarası sütunlarını yeniden düzenle
        _recalculateAutoNumbers();
        
        _applyFilter(); // Satır silinince filtreyi güncelle
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

  // Sıra numarası sütunlarını yeniden hesapla (1, 2, 3, 4...)
  void _recalculateAutoNumbers() {
    if (currentTable == null) return;
    
    // AutoNumber tipindeki sütunları bul
    for (int colIndex = 0; colIndex < currentTable!.columns.length; colIndex++) {
      final column = currentTable!.columns[colIndex];
      
      if (column.isAutoNumber) {
        // Her satır için sıra numarasını güncelle
        for (int rowIndex = 0; rowIndex < currentTable!.rows.length; rowIndex++) {
          if (colIndex < currentTable!.rows[rowIndex].length) {
            _tables[_currentTableIndex].rows[rowIndex][colIndex] = (rowIndex + 1).toString();
          }
        }
      }
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
        
        clearSearch(); // Tablo silinince aramayı temizle
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
      clearSearch();
      await StorageService.clearAllData();
      notifyListeners();
      return true;
    } catch (e) {
      print('Tüm veriler temizlenirken hata: $e');
      return false;
    }
  }
}