import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/shared_tally_operation.dart';
import '../models/tally_model.dart';
import '../models/tally_sort_preference.dart';
import '../services/storage_service.dart';
import '../config/plan_limits.dart';
import '../utils/row_sorter.dart';

class TallyProvider extends ChangeNotifier {
  /// How many edits undo and redo can reach back through.
  static const int _historyLimit = 30;

  List<TallyTableModel> _tables = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  String _itemSearchQuery = '';
  final List<List<_TallyCellChange>> _undoStack = [];

  /// Filled only by undo, and emptied by the next real edit: redo can only
  /// replay something that was just taken back, never an abandoned branch.
  final List<List<_TallyCellChange>> _redoStack = [];

  // Sıralama yalnızca görünümü etkiler; çetele kimliğine göre kalıcı tutulur.
  final Map<String, TallySortPreference> _sorts = {};

  /// Hangi çetele ortak ve bu cihaz orada sahip mi katılan mı.
  final Map<String, String> _sharedRoles = {};

  /// Buluta gönderilmeyi bekleyen değişiklikler, çetele kimliğine göre.
  final Map<String, PendingTallyChanges> _pending = {};

  List<TallyTableModel> get tables => _tables;
  TallyTableModel? get currentTable =>
      _tables.isNotEmpty ? _tables[_currentIndex] : null;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  bool get hasTables => _tables.isNotEmpty;
  String get itemSearchQuery => _itemSearchQuery;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Görünen öğelerin özgün indeksleri: önce arama, sonra sıralama.
  List<int> get filteredItemIndices {
    final table = currentTable;
    if (table == null) return const [];
    final indices = _itemSearchQuery.isEmpty
        ? List<int>.generate(table.items.length, (index) => index)
        : [
            for (var index = 0; index < table.items.length; index++)
              if (table.items[index].name.toLowerCase().contains(
                _itemSearchQuery,
              ))
                index,
          ];
    return _applySort(table, indices);
  }

  /// Tüm öğeler, aramadan bağımsız, ekrandaki sıralamayla.
  List<int> get sortedItemIndices {
    final table = currentTable;
    if (table == null) return const [];
    return _applySort(
      table,
      List<int>.generate(table.items.length, (index) => index),
    );
  }

  // === SIRALAMA ===

  /// Geçerli çetelenin sıralaması; silinmiş bir duruma bağlıysa null.
  TallySortPreference? get currentSort {
    final table = currentTable;
    return table == null ? null : _sortFor(table);
  }

  /// The sort of any tally, current or not; null when it points at a status
  /// that has since been deleted.
  TallySortPreference? _sortFor(TallyTableModel table) {
    final sort = _sorts[table.id];
    if (sort == null) return null;
    if (!sort.isByName &&
        !table.statuses.any((status) => status.code == sort.statusCode)) {
      return null;
    }
    return sort;
  }

  /// Any tally's on-screen item order; null when it is unsorted.
  List<int>? sortedOrderFor(TallyTableModel table) {
    if (_sortFor(table) == null) return null;
    return _applySort(
      table,
      List<int>.generate(table.items.length, (index) => index),
    );
  }

  bool get isSorted => currentSort != null;

  void setSort(TallySortPreference? preference) {
    final table = currentTable;
    if (table == null) return;
    if (preference == null) {
      if (_sorts.remove(table.id) == null) return;
    } else {
      _sorts[table.id] = preference;
    }
    notifyListeners();
    _saveSorts();
  }

  /// Ad başlığına dokunmak: artan → azalan → kapalı, tablolardaki gibi.
  void toggleNameSort() {
    final sort = currentSort;
    if (sort == null || !sort.isByName) {
      setSort(const TallySortPreference.byName(ascending: true));
    } else if (sort.ascending) {
      setSort(const TallySortPreference.byName(ascending: false));
    } else {
      setSort(null);
    }
  }

  List<int> _applySort(TallyTableModel table, List<int> indices) {
    final sort = _sortFor(table);
    if (sort == null || indices.length < 2) return indices;
    final items = table.items;
    final sorted = List<int>.from(indices);
    final int Function(int, int) compare;
    if (sort.isByName) {
      compare = (a, b) =>
          RowSorter.compareText(items[a].name.trim(), items[b].name.trim());
    } else {
      // Sayım toplamlarla aynı kuralı izler: yalnızca tarih aralığı içi.
      final start = TallyTableModel.dateKey(table.startDate);
      final end = TallyTableModel.dateKey(table.endDate);
      final counts = {
        for (final index in sorted)
          index: items[index].entries.entries
              .where(
                (entry) =>
                    entry.value == sort.statusCode &&
                    entry.key.compareTo(start) >= 0 &&
                    entry.key.compareTo(end) <= 0,
              )
              .length,
      };
      compare = (a, b) => counts[a]!.compareTo(counts[b]!);
    }
    sorted.sort((a, b) {
      final result = compare(a, b);
      if (result != 0) return sort.ascending ? result : -result;
      // Eşitlikte elle belirlenen sıra korunur.
      return a.compareTo(b);
    });
    return sorted;
  }

  /// Silinmiş çetelelerin tercihleri de burada ayıklanır.
  Future<void> _saveSorts() async {
    final ids = _tables.map((table) => table.id).toSet();
    _sorts.removeWhere((id, _) => !ids.contains(id));
    await StorageService.saveTallySorts(Map.of(_sorts));
  }

  TallyProvider() {
    _load();
  }

  Future<void> reloadFromStorage() => _load();

  Future<bool> importCloudTable(
    TallyTableModel table, {
    required bool overwrite,
  }) async {
    try {
      final index = _tables.indexWhere((item) => item.id == table.id);
      if (index >= 0 && overwrite) {
        _tables[index] = table;
        _currentIndex = index;
      } else {
        final imported = index >= 0
            ? TallyTableModel(
                tableName: table.tableName,
                startDate: table.startDate,
                endDate: table.endDate,
                statuses: table.statuses
                    .map((status) => status.copyWith())
                    .toList(),
                items: table.items
                    .map(
                      (item) => TallyItemModel(
                        name: item.name,
                        entries: Map<String, String>.from(item.entries),
                      ),
                    )
                    .toList(),
              )
            : table;
        _tables.add(imported);
        _currentIndex = _tables.length - 1;
      }
      await _save();
      await _saveIndex();
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Bulut çetelesi içe aktarılamadı: $error');
      return false;
    }
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    _tables = await StorageService.loadTallyTables();
    _sorts
      ..clear()
      ..addAll(await StorageService.loadTallySorts());
    _sharedRoles
      ..clear()
      ..addAll(await StorageService.loadSharedTallyRoles());
    _pending
      ..clear()
      ..addAll(await StorageService.loadPendingTallyChanges());
    if (_tables.isNotEmpty) {
      final last = await StorageService.loadLastOpenedTallyIndex();
      _currentIndex = (last >= 0 && last < _tables.length) ? last : 0;
    }
    _isLoading = false;
    notifyListeners();
  }

  // === ORTAK ÇETELE ===

  String? sharedRole(String tallyId) => _sharedRoles[tallyId];
  bool isSharedTally(String tallyId) => _sharedRoles.containsKey(tallyId);
  bool isSharedOwner(String tallyId) => _sharedRoles[tallyId] == 'owner';

  /// Bu çetelede buluta gönderilmeyi bekleyen öğe sayısı.
  int pendingChangeCount(String tallyId) => _pending[tallyId]?.length ?? 0;

  PendingTallyChanges? pendingChanges(String tallyId) => _pending[tallyId];

  Future<void> setSharedRole(String tallyId, String? role) async {
    if (role == null) {
      if (_sharedRoles.remove(tallyId) == null) return;
      // Artık ortak değilse bekleyen değişikliklerin gideceği yer yok.
      _pending.remove(tallyId);
      await StorageService.savePendingTallyChanges(Map.of(_pending));
    } else {
      if (_sharedRoles[tallyId] == role) return;
      _sharedRoles[tallyId] = role;
    }
    await StorageService.saveSharedTallyRoles(Map.of(_sharedRoles));
    notifyListeners();
  }

  /// Sunucunun uyguladığını bildirdiği öğeleri kuyruktan düşürür.
  Future<void> markChangesApplied(
    String tallyId,
    Iterable<String> itemIds,
  ) async {
    final pending = _pending[tallyId];
    if (pending == null) return;
    pending.clearApplied(itemIds);
    if (pending.isEmpty) _pending.remove(tallyId);
    await StorageService.savePendingTallyChanges(Map.of(_pending));
    notifyListeners();
  }

  /// Çakışmada kayıttaki hâli kabul etmek: yerel öğe sunucudakiyle
  /// değiştirilir. [serverItem] null ise öğe sunucuda silinmiş demektir.
  Future<void> applyServerItem(
    String tallyId,
    String itemId,
    TallyItemModel? serverItem,
  ) async {
    final tableIndex = _tables.indexWhere((item) => item.id == tallyId);
    if (tableIndex < 0) return;
    final table = _tables[tableIndex];
    final index = table.items.indexWhere((item) => item.id == itemId);
    if (serverItem == null) {
      if (index < 0) return;
      table.items.removeAt(index);
    } else if (index < 0) {
      // Öğe yerelde yok ama sunucuda var: geri getir.
      table.items.add(serverItem);
    } else {
      table.items[index]
        ..name = serverItem.name
        ..entries = Map<String, String>.from(serverItem.entries);
    }
    table.touch();
    await _save();
    notifyListeners();
  }

  /// "Benimki kalsın": bekleyen işlemin temeli sunucunun şimdiki hâliyle
  /// değiştirilir, böylece bir sonraki gönderimde geçer.
  void rebaseChange(String tallyId, String itemId, TallyItemModel? serverItem) {
    _pending[tallyId]?.rebase(
      itemId,
      serverItem == null ? null : Map<String, String?>.from(serverItem.entries),
      serverItem?.name,
    );
    unawaited(StorageService.savePendingTallyChanges(Map.of(_pending)));
    notifyListeners();
  }

  /// Ortak olmayan çetelede hiçbir şey yazılmaz; kuyruk yalnızca paylaşılan
  /// çeteleler için tutulur.
  PendingTallyChanges? _queueFor(TallyTableModel table) {
    if (!_sharedRoles.containsKey(table.id)) return null;
    return _pending.putIfAbsent(table.id, PendingTallyChanges.new);
  }

  void _persistQueue(TallyTableModel table) {
    final pending = _pending[table.id];
    if (pending != null && pending.isEmpty) _pending.remove(table.id);
    // Çevrimdışı yapılan düzenleme uygulama kapansa da beklemeye devam eder.
    unawaited(StorageService.savePendingTallyChanges(Map.of(_pending)));
  }

  void _recordMark(
    TallyTableModel table,
    String itemId,
    String dayKey, {
    required String? value,
    required String? base,
  }) {
    final queue = _queueFor(table);
    if (queue == null) return;
    queue.recordMark(itemId, dayKey, value: value, base: base);
    _persistQueue(table);
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
      _undoStack.clear();
      _redoStack.clear();
      _itemSearchQuery = '';
      _saveIndex();
      notifyListeners();
    }
  }

  void setItemSearchQuery(String query) {
    _itemSearchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  Future<bool> createTable(
    TallyTableModel table, {
    bool isPremium = false,
  }) async {
    try {
      if (!isPremium && _tables.length >= PlanLimits.freeTallies) return false;
      if (!await StorageService.saveTallyTables([..._tables, table]))
        return false;
      _tables.add(table);
      _currentIndex = _tables.length - 1;
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
    final normalizedCodes = newStatuses
        .map((status) => status.code.trim().toLowerCase())
        .toList();
    if (normalizedCodes.toSet().length != normalizedCodes.length) return false;
    try {
      final t = currentTable!;
      t.tableName = tableName.trim();
      t.startDate = startDate;
      t.endDate = endDate;
      t.statuses = newStatuses;
      t.touch();

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
      final item = TallyItemModel(name: name.trim());
      currentTable!.items.add(item);
      final queue = _queueFor(currentTable!);
      if (queue != null) {
        queue.recordCreate(item.id, item.name);
        _persistQueue(currentTable!);
      }
      currentTable!.touch();
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
        final removed = currentTable!.items.removeAt(itemIndex);
        final queue = _queueFor(currentTable!);
        if (queue != null) {
          queue.recordDelete(removed.id);
          _persistQueue(currentTable!);
        }
        currentTable!.touch();
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
        final item = currentTable!.items[itemIndex];
        final previous = item.name;
        item.name = newName.trim();
        final queue = _queueFor(currentTable!);
        if (queue != null) {
          queue.recordRename(item.id, item.name, base: previous);
          _persistQueue(currentTable!);
        }
        currentTable!.touch();
        await _save();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setCellStatus(
    int itemIndex,
    DateTime date,
    String? statusCode,
  ) async {
    if (currentTable == null) return;
    if (itemIndex < 0 || itemIndex >= currentTable!.items.length) return;
    final key = TallyTableModel.dateKey(date);
    final oldValue = currentTable!.items[itemIndex].entries[key];
    if (oldValue == statusCode ||
        (oldValue == null && (statusCode == null || statusCode.isEmpty))) {
      return;
    }
    _recordEdit([_TallyCellChange(itemIndex, key, oldValue)]);
    await _applyCellStatus(itemIndex, key, statusCode);
  }

  Future<void> _applyCellStatus(
    int itemIndex,
    String key,
    String? statusCode,
  ) async {
    final table = currentTable!;
    final item = table.items[itemIndex];
    final base = item.entries[key];
    if (statusCode == null || statusCode.isEmpty) {
      item.entries.remove(key);
    } else {
      item.entries[key] = statusCode;
    }
    _recordMark(table, item.id, key, value: item.entries[key], base: base);
    table.touch();
    await _save();
    notifyListeners();
  }

  Future<void> setBulkStatus({
    required List<int> itemIndices,
    required DateTime startDate,
    required DateTime endDate,
    required String? statusCode,
  }) async {
    final table = currentTable;
    if (table == null || startDate.isAfter(endDate)) return;
    final changes = <_TallyCellChange>[];
    var day = startDate.isBefore(table.startDate) ? table.startDate : startDate;
    final lastDay = endDate.isAfter(table.endDate) ? table.endDate : endDate;
    for (final itemIndex in itemIndices.toSet()) {
      if (itemIndex < 0 || itemIndex >= table.items.length) continue;
      var current = day;
      while (!current.isAfter(lastDay)) {
        final key = TallyTableModel.dateKey(current);
        final oldValue = table.items[itemIndex].entries[key];
        if (oldValue != statusCode) {
          changes.add(_TallyCellChange(itemIndex, key, oldValue));
          final item = table.items[itemIndex];
          if (statusCode == null || statusCode.isEmpty) {
            item.entries.remove(key);
          } else {
            item.entries[key] = statusCode;
          }
          _recordMark(
            table,
            item.id,
            key,
            value: item.entries[key],
            base: oldValue,
          );
        }
        current = current.add(const Duration(days: 1));
      }
    }
    if (changes.isEmpty) return;
    _recordEdit(changes);
    table.touch();
    await _save();
    notifyListeners();
  }

  /// A fresh edit makes the redone-away future unreachable, as in any editor.
  void _recordEdit(List<_TallyCellChange> changes) {
    _undoStack.add(changes);
    _trimHistory(_undoStack);
    _redoStack.clear();
  }

  Future<void> undoLastEdit() async {
    await _stepHistory(from: _undoStack, to: _redoStack);
  }

  Future<void> redoLastEdit() async {
    await _stepHistory(from: _redoStack, to: _undoStack);
  }

  /// Undo and redo are the same move in opposite directions: restore a batch
  /// of previous values and push what they replaced onto the other stack.
  Future<void> _stepHistory({
    required List<List<_TallyCellChange>> from,
    required List<List<_TallyCellChange>> to,
  }) async {
    final table = currentTable;
    if (table == null || from.isEmpty) return;
    final changes = from.removeLast();
    final inverse = <_TallyCellChange>[];
    for (final change in changes) {
      // An item deleted since the edit drops out; the rest still apply.
      if (change.itemIndex >= table.items.length) continue;
      final entries = table.items[change.itemIndex].entries;
      inverse.add(
        _TallyCellChange(
          change.itemIndex,
          change.dateKey,
          entries[change.dateKey],
        ),
      );
      final base = entries[change.dateKey];
      if (change.oldValue == null) {
        entries.remove(change.dateKey);
      } else {
        entries[change.dateKey] = change.oldValue!;
      }
      // Geri alma da sıradan bir değişiklik: karşı taraf o arada senin
      // işaretini görmüş olabilir, yani buluta gitmesi gerekir.
      _recordMark(
        table,
        table.items[change.itemIndex].id,
        change.dateKey,
        value: entries[change.dateKey],
        base: base,
      );
    }
    if (inverse.isEmpty) {
      notifyListeners();
      return;
    }
    to.add(inverse);
    _trimHistory(to);
    table.touch();
    await _save();
    notifyListeners();
  }

  static void _trimHistory(List<List<_TallyCellChange>> stack) {
    if (stack.length > _historyLimit) stack.removeAt(0);
  }

  Future<void> reorderItem(int oldIndex, int newIndex) async {
    final table = currentTable;
    if (table == null || oldIndex < 0 || oldIndex >= table.items.length) return;
    if (newIndex > oldIndex) newIndex--;
    final item = table.items.removeAt(oldIndex);
    table.items.insert(newIndex.clamp(0, table.items.length), item);
    table.touch();
    // Elle sıralayan kullanıcı yeni sırasını görmeli; otomatik sıralama kalkar.
    final hadSort = _sorts.remove(table.id) != null;
    await _save();
    notifyListeners();
    if (hadSort) await _saveSorts();
  }

  Map<String, int> getOverallSummary() {
    final table = currentTable;
    if (table == null) return {};
    final summary = {for (final status in table.statuses) status.code: 0};
    for (final item in table.items) {
      for (final entry in item.entries.entries) {
        if (summary.containsKey(entry.value)) {
          summary[entry.value] = summary[entry.value]! + 1;
        }
      }
    }
    return summary;
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
      currentTable!.startDate,
      currentTable!.endDate,
      currentTable!.statuses,
    );
  }
}

class _TallyCellChange {
  final int itemIndex;
  final String dateKey;
  final String? oldValue;

  const _TallyCellChange(this.itemIndex, this.dateKey, this.oldValue);
}
