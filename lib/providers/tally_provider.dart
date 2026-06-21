import 'package:flutter/foundation.dart';
import '../models/tally_model.dart';
import '../services/storage_service.dart';

class TallyProvider extends ChangeNotifier {
  List<TallyTableModel> _tables = [];
  int _currentIndex = 0;
  bool _isLoading = false;

  List<TallyTableModel> get tables => _tables;
  TallyTableModel? get currentTable => _tables.isNotEmpty ? _tables[_currentIndex] : null;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  bool get hasTables => _tables.isNotEmpty;

  TallyProvider() {
    _load();
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    _tables = await StorageService.loadTallyTables();
    if (_tables.isNotEmpty) {
      final last = await StorageService.loadLastOpenedTallyIndex();
      _currentIndex = (last >= 0 && last < _tables.length) ? last : 0;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    await StorageService.saveTallyTables(_tables);
  }

  Future<void> _saveIndex() async {
    await StorageService.saveLastOpenedTallyIndex(_currentIndex);
  }

  void changeTable(int index) {
    if (index >= 0 && index < _tables.length) {
      _currentIndex = index;
      _saveIndex();
      notifyListeners();
    }
  }

  Future<bool> createTable(TallyTableModel table) async {
    try {
      _tables.add(table);
      _currentIndex = _tables.length - 1;
      await _save();
      await _saveIndex();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Çetele oluşturma hatası: $e');
      return false;
    }
  }

  /// Mevcut tabloyu güncelle. [codeRemap] eski kod -> yeni kod (null=silindi).
  /// Yalnızca remap edilmiş kodlar dokunulur; haritada olmayan kodlar olduğu gibi kalır.
  Future<bool> updateCurrentTable({
    required String tableName,
    required DateTime startDate,
    required DateTime endDate,
    required List<TallyStatus> newStatuses,
    Map<String, String?> codeRemap = const {},
  }) async {
    if (currentTable == null) return false;
    try {
      final t = currentTable!;
      t.tableName = tableName.trim();
      t.startDate = startDate;
      t.endDate = endDate;
      t.statuses = newStatuses;

      if (codeRemap.isNotEmpty) {
        for (final item in t.items) {
          final updated = <String, String>{};
          item.entries.forEach((dateKey, oldCode) {
            if (codeRemap.containsKey(oldCode)) {
              final newCode = codeRemap[oldCode];
              if (newCode != null) updated[dateKey] = newCode;
              // null => durum silindi, hücre boşaltıldı
            } else {
              updated[dateKey] = oldCode;
            }
          });
          item.entries
            ..clear()
            ..addAll(updated);
        }
      }

      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Çetele güncelleme hatası: $e');
      return false;
    }
  }

  Future<bool> deleteTable(int index) async {
    try {
      if (index >= 0 && index < _tables.length) {
        _tables.removeAt(index);
        if (_currentIndex >= _tables.length) _currentIndex = _tables.length - 1;
        if (_currentIndex < 0) _currentIndex = 0;
        await _save();
        await _saveIndex();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addItem(String name) async {
    if (currentTable == null) return false;
    try {
      currentTable!.items.add(TallyItemModel(name: name.trim()));
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeItem(int itemIndex) async {
    if (currentTable == null) return false;
    try {
      if (itemIndex >= 0 && itemIndex < currentTable!.items.length) {
        currentTable!.items.removeAt(itemIndex);
        await _save();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> renameItem(int itemIndex, String newName) async {
    if (currentTable == null) return false;
    try {
      if (itemIndex >= 0 && itemIndex < currentTable!.items.length) {
        currentTable!.items[itemIndex].name = newName.trim();
        await _save();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setCellStatus(int itemIndex, DateTime date, String? statusCode) async {
    if (currentTable == null) return;
    if (itemIndex < 0 || itemIndex >= currentTable!.items.length) return;
    final key = TallyTableModel.dateKey(date);
    if (statusCode == null || statusCode.isEmpty) {
      currentTable!.items[itemIndex].entries.remove(key);
    } else {
      currentTable!.items[itemIndex].entries[key] = statusCode;
    }
    await _save();
    notifyListeners();
  }

  Future<void> cycleCellStatus(int itemIndex, DateTime date) async {
    if (currentTable == null) return;
    if (itemIndex < 0 || itemIndex >= currentTable!.items.length) return;
    final key = TallyTableModel.dateKey(date);
    final codes = currentTable!.statusCodes;
    if (codes.isEmpty) return;
    final currentCode = currentTable!.items[itemIndex].entries[key];
    String? nextCode;
    if (currentCode == null || currentCode.isEmpty) {
      nextCode = codes.first;
    } else {
      final idx = codes.indexOf(currentCode);
      if (idx == -1 || idx == codes.length - 1) {
        nextCode = null;
      } else {
        nextCode = codes[idx + 1];
      }
    }
    await setCellStatus(itemIndex, date, nextCode);
  }

  Map<String, int> getItemSummary(int itemIndex) {
    if (currentTable == null) return {};
    if (itemIndex < 0 || itemIndex >= currentTable!.items.length) return {};
    return currentTable!.items[itemIndex].getSummary(
      currentTable!.startDate, currentTable!.endDate, currentTable!.statuses,
    );
  }
}
