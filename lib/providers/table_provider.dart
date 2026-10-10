import '../utils/column_balance.dart';
import '../utils/table_search.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:table_note/models/shared_row_operation.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/table_sort_preference.dart';
import '../services/storage_service.dart';
import '../config/plan_limits.dart';
import '../utils/number_display.dart';
import '../utils/row_sorter.dart';

class TableProvider extends ChangeNotifier {
  List<TableModel> _tables = [];
  int _currentTableIndex = 0;
  bool _isLoading = false;
  bool _isCommittingForm = false;

  // Filtreleme için state
  String _searchQuery = '';

  /// [_searchQuery]'nin açık tablonun sütunlarına göre çözülmüş hali.
  TableSearch _search = TableSearch.none;
  List<int> _filteredRowIndices = [];

  // Sıralama yalnızca görünümü etkiler; tablo kimliğine göre kalıcı tutulur.
  final Map<String, TableSortPreference> _sorts = {};

  // Ortak tablolar: kimlik -> 'owner' | 'editor' | 'viewer'.
  final Map<String, String> _sharedRoles = {};

  // Buluta gönderilmeyi bekleyen satır değişiklikleri, tablo kimliğine göre.
  final Map<String, PendingRowChanges> _pending = {};

  // Getters
  List<TableModel> get tables => _tables;
  TableModel? get currentTable =>
      _tables.isNotEmpty ? _tables[_currentTableIndex] : null;
  int get currentTableIndex => _currentTableIndex;
  bool get isLoading => _isLoading;
  bool get hasTables => _tables.isNotEmpty;

  // Filtreleme getters
  String get searchQuery => _searchQuery;

  /// Aranacak bir söz var mı. "yükleme:" yazılıp henüz söz girilmemişken
  /// arama kutusu dolu ama süzülecek bir şey yoktur.
  bool get isFiltering => !_search.isEmpty;

  /// Aramanın sınırlandığı sütun; her sütunda aranıyorsa null.
  int? get searchColumnIndex => _search.columnIndex;

  /// Aramanın ekranda yazılacak hali: sütuna sınırlıysa sütunun adıyla.
  String get searchLabel {
    final column = _search.columnIndex;
    final table = currentTable;
    if (column == null || table == null || column >= table.columns.length) {
      return _search.term;
    }
    return '${table.columns[column].name}: ${_search.term}';
  }

  /// Bu sütundaki hücrelerde vurgulanacak söz. Arama başka bir sütuna
  /// sınırlıysa boştur: aranmayan sütunda eşleşme gösterilmez.
  String searchTermFor(int columnIndex) =>
      _search.covers(columnIndex) ? _search.term : '';
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

  // === SIRALAMA ===

  int? get sortColumnIndex {
    final table = currentTable;
    if (table == null) return null;
    return _sorts[table.id]?.resolve(table.columns);
  }

  bool get sortAscending => _sorts[currentTable?.id]?.ascending ?? true;
  bool get isSorted => sortColumnIndex != null;

  /// Görünen satırların özgün indeksleri: önce arama filtresi, sonra sıralama.
  List<int> get visibleRowIndices {
    final table = currentTable;
    if (table == null) return const [];
    if (!isFiltering) return sortedRowIndices;
    return _sortIndices(
      table,
      _filteredRowIndices.where((i) => i < table.rows.length).toList(),
    );
  }

  /// Tüm satırlar, aramadan bağımsız, ekrandaki sıralamayla.
  List<int> get sortedRowIndices {
    final table = currentTable;
    if (table == null) return const [];
    return _sortIndices(table, List<int>.generate(table.rows.length, (i) => i));
  }

  List<int> _sortIndices(TableModel table, List<int> indices) =>
      _sortFor(table, indices) ?? indices;

  /// Null when this table has no usable sort, so callers can keep their own
  /// default order instead of pretending the rows were sorted.
  List<int>? _sortFor(TableModel table, List<int> indices) {
    final sort = _sorts[table.id];
    final column = sort?.resolve(table.columns);
    if (sort == null || column == null) return null;
    return RowSorter.sort(
      indices: indices,
      rows: table.rows,
      column: table.columns[column],
      columnIndex: column,
      ascending: sort.ascending,
    );
  }

  /// Any table's on-screen row order, not just the open one. The home screen
  /// widget uses it so it never contradicts what the app shows.
  List<int>? sortedOrderFor(TableModel table) =>
      _sortFor(table, List<int>.generate(table.rows.length, (i) => i));

  /// Görünen satırlar, [visibleRowIndices] ile birebir aynı sırada.
  List<List<String>> get visibleRows {
    final table = currentTable;
    if (table == null) return const [];
    return visibleRowIndices.map((index) => table.rows[index]).toList();
  }

  // === ORTAK TABLO ===

  /// Tablo ortak mı, öyleyse bu cihaz sahip mi katılan mı.
  String? sharedRole(String tableId) => _sharedRoles[tableId];
  bool isSharedTable(String tableId) => _sharedRoles.containsKey(tableId);
  bool isSharedOwner(String tableId) => _sharedRoles[tableId] == 'owner';

  /// Kodla katılmış ve yalnızca görüntüleme yetkisi olan tablo.
  bool isSharedViewer(String tableId) => _sharedRoles[tableId] == 'viewer';

  /// Açık tabloda kayıt eklenip değiştirilebilir mi. Arayüz düğmeleri buna
  /// göre çizer; aşağıdaki metotlar da aynı kurala bakar, böylece arayüzde
  /// unutulan bir yol tabloyu yine de değiştiremez.
  bool get canEditCurrent {
    final table = currentTable;
    return table == null || !isSharedViewer(table.id);
  }

  /// Bu cihaz kodla katıldığı bir tabloyu tutuyor mu? Hesap ekranı, giriş
  /// yapınca bu erişimin kapanacağını yalnızca gerçekten öyleyse söyler.
  bool get hasJoinedTables =>
      _sharedRoles.values.any((role) => role != 'owner');

  /// Kullanıcının kendi tabloları; ücretsiz sınıra yalnızca bunlar sayılır.
  /// Kodla katılınan tablo başkasınındır: davet edilen kişi sınıra takılıp
  /// giremezse bunun bedelini davet eden öder.
  int get ownedTableCount => _tables.where((table) {
    final role = _sharedRoles[table.id];
    return role == null || role == 'owner';
  }).length;

  /// Ücretsiz kullanımda yeni bir tablo oluşturulabilir mi.
  bool get canCreateFreeTable => ownedTableCount < PlanLimits.freeTables;

  /// Bu tabloda buluta gönderilmeyi bekleyen satır sayısı.
  int pendingChangeCount(String tableId) => _pending[tableId]?.length ?? 0;

  PendingRowChanges? pendingChanges(String tableId) => _pending[tableId];

  Future<void> setSharedRole(String tableId, String? role) async {
    if (role == null) {
      if (_sharedRoles.remove(tableId) == null) return;
      // Artık ortak değilse bekleyen değişikliklerin gönderileceği yer yok.
      _pending.remove(tableId);
      await StorageService.savePendingRowChanges(Map.of(_pending));
    } else {
      if (_sharedRoles[tableId] == role) return;
      _sharedRoles[tableId] = role;
    }
    await StorageService.saveSharedTableRoles(Map.of(_sharedRoles));
    notifyListeners();
  }

  /// Buluttaki kimlik değiştiğinde çağrılır; tabloların kendisi cihazda
  /// kalır, yalnızca onları buluta bağlayan roller ve bekleyen kuyruk gider.
  ///
  /// Hesap silindiyse hepsi temizlenir: paylaşılan tablolar da sunucudan
  /// silinmiştir. Misafir oturumu gerçek bir hesapla değiştiyse yalnızca
  /// katılınanlar ([joinedOnly]): üyelik eski misafir kimliğine aitti, ama
  /// kullanıcının daha önce kendi hesabıyla paylaştıkları hâlâ geçerli.
  /// Roller durursa senkron servisi erişemediği tablolara göndermeye
  /// çalışır ve gösterge kalıcı hatada kalır.
  Future<void> clearSharedState({bool joinedOnly = false}) async {
    final lost = [
      for (final entry in _sharedRoles.entries)
        if (!joinedOnly || entry.value != 'owner') entry.key,
    ];
    if (lost.isEmpty) return;
    for (final tableId in lost) {
      _sharedRoles.remove(tableId);
      _pending.remove(tableId);
    }
    await StorageService.saveSharedTableRoles(Map.of(_sharedRoles));
    await StorageService.savePendingRowChanges(Map.of(_pending));
    notifyListeners();
  }

  /// Sunucunun uyguladığını bildirdiği satırları kuyruktan düşürür.
  Future<void> markChangesApplied(
    String tableId,
    Iterable<String> rowIds,
  ) async {
    final pending = _pending[tableId];
    if (pending == null) return;
    pending.clearApplied(rowIds);
    if (pending.isEmpty) _pending.remove(tableId);
    await StorageService.savePendingRowChanges(Map.of(_pending));
    notifyListeners();
  }

  /// Çakışmada kayıttaki hâli kabul etmek: yerel satır sunucudakiyle
  /// değiştirilir. [values] null ise satır sunucuda silinmiş demektir.
  Future<void> applyServerRow(
    String tableId,
    String rowId,
    List<String>? values,
  ) async {
    final index = _tables.indexWhere((table) => table.id == tableId);
    if (index < 0) return;
    final table = _tables[index];
    final rowIndex = table.indexOfRowId(rowId);
    if (rowIndex < 0) {
      // Satır yerelde yok ama sunucuda var: geri getir.
      if (values != null) table.appendRow(values, rowId: rowId);
    } else if (values == null) {
      table.removeRowAt(rowIndex);
    } else {
      table.replaceRow(rowIndex, values);
    }
    table.touch();
    await _saveTables();
    _applyFilter();
    notifyListeners();
  }

  /// Çakışmada kendi hâlini dayatmak: bekleyen işlemin temeli sunucunun
  /// şimdiki değeriyle değiştirilir, bir sonraki gönderimde geçer.
  void rebaseChange(String tableId, String rowId, List<String>? serverCurrent) {
    final pending = _pending[tableId];
    if (pending == null) return;
    pending.rebase(rowId, serverCurrent);
    unawaited(StorageService.savePendingRowChanges(Map.of(_pending)));
    notifyListeners();
  }

  /// Satır değişikliğini kuyruğa yazar. Ortak olmayan tabloda hiçbir şey
  /// yapmaz, yani sıradan kullanıcı bu maliyeti hiç ödemez.
  void _recordSharedChange(
    TableModel table,
    String rowId, {
    List<String>? values,
    List<String>? base,
    bool isDelete = false,
  }) {
    if (!_sharedRoles.containsKey(table.id)) return;
    final pending = _pending.putIfAbsent(table.id, PendingRowChanges.new);
    if (isDelete) {
      pending.recordDelete(rowId, base: base);
    } else {
      pending.recordUpsert(rowId, values ?? const [], base: base);
    }
    if (pending.isEmpty) _pending.remove(table.id);
    // Çevrimdışı yapılan düzenleme uygulama kapansa da beklemeye devam eder.
    unawaited(StorageService.savePendingRowChanges(Map.of(_pending)));
  }

  /// Aynı sütuna üçüncü dokunuş sıralamayı kaldırır: artan → azalan → kapalı.
  void toggleSort(int columnIndex) {
    final table = currentTable;
    if (table == null ||
        columnIndex < 0 ||
        columnIndex >= table.columns.length) {
      return;
    }
    if (sortColumnIndex != columnIndex) {
      _sorts[table.id] = TableSortPreference.forColumn(
        table.columns,
        columnIndex,
        ascending: true,
      );
    } else if (sortAscending) {
      _sorts[table.id] = TableSortPreference.forColumn(
        table.columns,
        columnIndex,
        ascending: false,
      );
    } else {
      _sorts.remove(table.id);
    }
    notifyListeners();
    _saveSorts();
  }

  void clearSort() {
    final table = currentTable;
    if (table == null) return;
    if (_sorts.remove(table.id) == null) return;
    notifyListeners();
    _saveSorts();
  }

  /// Silinmiş tabloların tercihleri de burada ayıklanır.
  Future<void> _saveSorts() async {
    final ids = _tables.map((table) => table.id).toSet();
    _sorts.removeWhere((id, _) => !ids.contains(id));
    await StorageService.saveTableSorts(Map.of(_sorts));
  }

  // Filtrelenmiş satır sayısı
  int get filteredRowCount => isFiltering
      ? _filteredRowIndices.length
      : (currentTable?.rows.length ?? 0);
  int get totalRowCount => currentTable?.rows.length ?? 0;

  TableProvider() {
    _loadTables();
  }

  Future<void> reloadFromStorage() => _loadTables();

  /// Buluttaki bir kaydi cihaza alir.
  ///
  /// [copyName] yalnizca yeni kopya olustururken kullanilir. Kopya ayni adi
  /// tasirsa cekmecede birbirinden ayirt edilemeyen iki satir olusuyordu.
  Future<bool> importCloudTable(
    TableModel table, {
    required bool overwrite,
    String? copyName,
  }) async {
    try {
      final index = _tables.indexWhere((item) => item.id == table.id);
      if (index >= 0 && overwrite) {
        _tables[index] = table;
        _currentTableIndex = index;
      } else {
        final imported = index >= 0
            ? TableModel(
                columns: table.columns
                    .map((column) => column.copyWith())
                    .toList(),
                rows: table.rows.map(List<String>.from).toList(),
                tableName: copyName ?? table.tableName,
              )
            : table;
        _tables.add(imported);
        _currentTableIndex = _tables.length - 1;
      }
      await _saveTables();
      await _saveLastOpenedTableIndex();
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Bulut tablosu içe aktarılamadı: $error');
      return false;
    }
  }

  // Tabloları yükle
  Future<void> _loadTables() async {
    _isLoading = true;
    notifyListeners();

    _tables = await StorageService.loadTables();
    _sorts
      ..clear()
      ..addAll(await StorageService.loadTableSorts());
    _sharedRoles
      ..clear()
      ..addAll(await StorageService.loadSharedTableRoles());
    _pending
      ..clear()
      ..addAll(await StorageService.loadPendingRowChanges());

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
    _search = TableSearch.none;
    _filteredRowIndices.clear();
    notifyListeners();
  }

  // Filtreleme uygula
  void _applyFilter() {
    final table = currentTable;
    // Sütunlar değişmiş olabilir; arama her seferinde bugünkü sütunlara göre
    // yeniden çözülür.
    _search = table == null
        ? TableSearch.none
        : TableSearch.parse(_searchQuery, table.columns);
    if (table == null || _search.isEmpty) {
      _filteredRowIndices.clear();
      return;
    }

    _filteredRowIndices = [];
    final columns = table.columns;
    final term = _search.term;
    // Sayı sütunları ekranda binlik ayraçlı görünür; "35.000" yazan bir
    // kullanıcı gördüğü satırı bulabilsin diye o biçim de denenir.
    final tryGrouped = term.contains(RegExp(r'[.,]'));

    for (int rowIndex = 0; rowIndex < table.rows.length; rowIndex++) {
      final row = table.rows[rowIndex];

      // Aramanın kapsadığı hücrelerden biri sözü içeriyor mu? Arama bir
      // sütuna sınırlıysa yalnızca o sütunun hücresine bakılır.
      var matches = false;
      for (var c = 0; c < row.length && !matches; c++) {
        if (!_search.covers(c)) continue;
        matches = row[c].toLowerCase().contains(term);
      }
      if (!matches && tryGrouped) {
        for (var c = 0; c < row.length && c < columns.length; c++) {
          if (matches) break;
          if (!_search.covers(c) || !showsGroupedNumbers(columns[c])) continue;
          for (final form in groupedSearchForms(row[c])) {
            if (form.contains(term)) {
              matches = true;
              break;
            }
          }
        }
      }

      if (matches) {
        _filteredRowIndices.add(rowIndex);
      }
    }
  }

  /// Başlangıç değeri verilmiş sütunların kalanları. Aramadan bağımsızdır.
  List<ColumnBalance> get columnBalances {
    final table = currentTable;
    return table == null ? const [] : computeColumnBalances(table);
  }

  /// Açık tablonun yapısı (sütunları) bu cihazdan değiştirilebilir mi.
  /// Kodla katılınan tabloda yapıyı yalnızca sahibi değiştirir.
  bool get canEditStructure {
    final table = currentTable;
    return table != null &&
        canEditCurrent &&
        (!isSharedTable(table.id) || isSharedOwner(table.id));
  }

  /// Bir sütunun başlangıç değerini değiştirir ya da (null ile) kaldırır.
  /// Sermaye arttığında, hedef değiştiğinde tablo yapısına girmeden
  /// güncellenebilsin diye ayrı bir yoldur; satırlara dokunmaz.
  Future<bool> setColumnStartingValue(int columnIndex, double? value) async {
    final table = currentTable;
    if (table == null ||
        !canEditStructure ||
        columnIndex < 0 ||
        columnIndex >= table.columns.length ||
        !table.columns[columnIndex].isSummed) {
      return false;
    }
    return updateTableStructure(table.tableName, [
      for (var index = 0; index < table.columns.length; index++)
        index == columnIndex
            ? table.columns[index].copyWith(
                startingValue: value,
                clearStartingValue: value == null,
              )
            : table.columns[index],
    ], table.columns.length);
  }

  // Filtrelenmiş satırların sayısal sütun toplamlarını hesapla
  // NOT: Sabit değer ve sıra numarası sütunları toplamdan hariç tutulur
  Map<String, double> calculateFilteredColumnSums() {
    Map<String, double> sums = {};

    if (currentTable == null) return sums;

    // Hangi satırları toplayacağız?
    final rowsToSum = isFiltering ? filteredRows : currentTable!.rows;

    for (
      int colIndex = 0;
      colIndex < currentTable!.columns.length;
      colIndex++
    ) {
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
  Future<bool> createTable(
    String tableName,
    List<ColumnModel> columns, {
    bool isPremium = false,
  }) async {
    if (_isCommittingForm) return false;
    _isCommittingForm = true;
    try {
      if (!isPremium && !canCreateFreeTable) return false;
      final newTable = TableModel(
        tableName: tableName.trim(),
        columns: columns.map((column) => column.copyWith()).toList(),
        rows: [],
      );

      if (!await StorageService.saveTables([..._tables, newTable]))
        return false;
      _tables.add(newTable);
      _currentTableIndex = _tables.length - 1;
      clearSearch();
      await _saveLastOpenedTableIndex();
      notifyListeners();
      return true;
    } catch (e) {
      print('Tablo oluşturulurken hata: $e');
      return false;
    } finally {
      _isCommittingForm = false;
    }
  }

  // Tablo adını değiştir
  Future<bool> renameTable(int tableIndex, String newName) async {
    try {
      if (tableIndex >= 0 &&
          tableIndex < _tables.length &&
          newName.trim().isNotEmpty) {
        _tables[tableIndex].tableName = newName.trim();
        _tables[tableIndex].touch();
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
    if (_isCommittingForm || !canEditCurrent) return false;
    final table = currentTable;
    if (table == null || rowData.length != table.columns.length) return false;
    final index = _currentTableIndex;
    _isCommittingForm = true;
    try {
      final updated = TableModel.fromJson(table.toJson());
      updated.appendRow(rowData);
      updated.touch();
      final addedId = updated.rowIds.last;
      _recordSharedChange(updated, addedId, values: rowData);
      final snapshot = List<TableModel>.from(_tables)..[index] = updated;
      if (!await StorageService.saveTables(snapshot)) return false;
      _tables[index] = updated;
      _applyFilter();
      notifyListeners();
      return true;
    } catch (e) {
      print('Satır eklenirken hata: $e');
      return false;
    } finally {
      _isCommittingForm = false;
    }
  }

  // Satır güncelle
  Future<bool> updateRow(int rowIndex, List<String> newRowData) async {
    if (_isCommittingForm || !canEditCurrent) return false;
    final table = currentTable;
    if (table == null ||
        rowIndex < 0 ||
        rowIndex >= table.rows.length ||
        newRowData.length != table.columns.length)
      return false;
    final index = _currentTableIndex;
    _isCommittingForm = true;
    try {
      // Cakisma tespiti icin buluta "neyi gordugumu" soylemem gerekiyor, o
      // yuzden onceki deger degisiklikten once alinir.
      final previous = List<String>.from(table.rows[rowIndex]);
      final rowId = table.rowIdAt(rowIndex);
      final updated = TableModel.fromJson(table.toJson());
      updated.replaceRow(rowIndex, newRowData);
      updated.touch();
      if (rowId != null) {
        _recordSharedChange(updated, rowId, values: newRowData, base: previous);
      }
      final snapshot = List<TableModel>.from(_tables)..[index] = updated;
      if (!await StorageService.saveTables(snapshot)) return false;
      _tables[index] = updated;
      _applyFilter();
      notifyListeners();
      return true;
    } catch (e) {
      print('Satır güncellenirken hata: $e');
      return false;
    } finally {
      _isCommittingForm = false;
    }
  }

  // Satır sil
  Future<bool> deleteRow(int rowIndex) async {
    if (!canEditCurrent) return false;
    try {
      if (currentTable != null && rowIndex < currentTable!.rows.length) {
        final table = _tables[_currentTableIndex];
        final removedId = table.rowIdAt(rowIndex);
        final previous = List<String>.from(table.rows[rowIndex]);
        if (removedId != null) {
          _recordSharedChange(table, removedId, base: previous, isDelete: true);
        }
        _tables[_currentTableIndex].removeRowAt(rowIndex);
        _tables[_currentTableIndex].touch();
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
        final removed = _tables.removeAt(tableIndex);
        // Tablo gidince onu buluta bağlayan kayıtlar da gider; yoksa silinmiş
        // bir tablo "katılınmış tablo var" diye görünmeye devam ederdi.
        final hadRole = _sharedRoles.remove(removed.id) != null;
        final hadPending = _pending.remove(removed.id) != null;
        if (hadRole) {
          await StorageService.saveSharedTableRoles(Map.of(_sharedRoles));
        }
        if (hadPending) {
          await StorageService.savePendingRowChanges(Map.of(_pending));
        }

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
  Future<bool> updateTableStructure(
    String newName,
    List<ColumnModel> newColumns,
    int originalColumnCount,
  ) async {
    try {
      if (currentTable == null || !canEditCurrent) return false;

      final table = currentTable!;

      // Tablo adını güncelle
      table.tableName = newName.trim();

      // Mevcut sütunların eşleştirilmesi
      Map<int, int> columnMapping = {};
      for (
        int newIdx = 0;
        newIdx < newColumns.length && newIdx < originalColumnCount;
        newIdx++
      ) {
        columnMapping[newIdx] = newIdx;
      }

      // Satırları yeni yapıya göre düzenle
      List<List<String>> newRows = [];
      for (var oldRow in table.rows) {
        List<String> newRow = List.filled(newColumns.length, '');

        // Mevcut sütunları kopyala
        for (
          int i = 0;
          i < originalColumnCount && i < oldRow.length && i < newColumns.length;
          i++
        ) {
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
      // Only the columns change here; every row survives, so it keeps its id.
      table.setRows(newRows, ids: table.rowIds);
      table.touch();

      await _saveTables();
      notifyListeners();
      return true;
    } catch (e) {
      print('Tablo yapısı güncellenirken hata: $e');
      return false;
    }
  }
}
