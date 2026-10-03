/// Buluta gonderilmeyi bekleyen tek bir satir degisikligi.
///
/// [base], duzenlemeye baslanirken satirin kayittaki haliydi. Sunucu bunu
/// kendisindekiyle karsilastirir; farkliysa araya baskasi girmis demektir ve
/// o satir uygulanmaz. Yerelde olusturulmus, buluta hic gitmemis bir satirda
/// [base] null olur.
class SharedRowOperation {
  final String rowId;
  final bool isDelete;
  final List<String>? values;
  final List<String>? base;

  const SharedRowOperation({
    required this.rowId,
    required this.isDelete,
    this.values,
    this.base,
  });

  /// Bulutta hic var olmamis, yerelde eklenmis satir.
  bool get isNew => base == null;

  Map<String, dynamic> toJson() => {
    'op': isDelete ? 'delete' : 'upsert',
    'rowId': rowId,
    if (!isDelete) 'values': values,
    'base': base,
  };

  static SharedRowOperation? fromJson(Map<String, dynamic> json) {
    final rowId = json['rowId']?.toString();
    if (rowId == null || rowId.isEmpty) return null;
    List<String>? cells(Object? raw) => raw == null
        ? null
        : List<String>.from((raw as List).map((cell) => cell.toString()));
    return SharedRowOperation(
      rowId: rowId,
      isDelete: json['op'] == 'delete',
      values: cells(json['values']),
      base: cells(json['base']),
    );
  }
}

/// Bir tablonun bekleyen degisiklikleri. Satir basina tek islem tutulur:
/// aynı satır beş kez düzenlense de buluta bir kez gider.
///
/// Onemli olan kural sudur: [base] her zaman **ilk** degisiklikten onceki
/// degerdir, sonrakiler onu ezmez. Yoksa kullanici kendi ara adimini "kayittaki
/// deger" sanip cakismayi gozden kacirirdi.
class PendingRowChanges {
  final Map<String, SharedRowOperation> _byRowId;

  PendingRowChanges([Map<String, SharedRowOperation>? initial])
    : _byRowId = {...?initial};

  bool get isEmpty => _byRowId.isEmpty;
  bool get isNotEmpty => _byRowId.isNotEmpty;
  int get length => _byRowId.length;
  List<SharedRowOperation> get operations => _byRowId.values.toList();
  bool contains(String rowId) => _byRowId.containsKey(rowId);

  /// Satir eklendi ya da degistirildi. [base] yalnizca bu satir icin ilk kez
  /// kayit tutuluyorsa dikkate alinir.
  void recordUpsert(String rowId, List<String> values, {List<String>? base}) {
    final existing = _byRowId[rowId];
    _byRowId[rowId] = SharedRowOperation(
      rowId: rowId,
      isDelete: false,
      values: List<String>.from(values),
      base: existing == null ? base : existing.base,
    );
  }

  void recordDelete(String rowId, {List<String>? base}) {
    final existing = _byRowId[rowId];
    // Yerelde olusturulup yine yerelde silinen satirin buluta soyleyecegi
    // bir seyi yok; islem tamamen duser.
    if (existing != null && existing.isNew) {
      _byRowId.remove(rowId);
      return;
    }
    _byRowId[rowId] = SharedRowOperation(
      rowId: rowId,
      isDelete: true,
      base: existing?.base ?? base,
    );
  }

  /// Sunucunun uyguladigini bildirdigi satirlar kuyruktan dusulur; cakisanlar
  /// kullanici karar verene kadar bekler.
  void clearApplied(Iterable<String> rowIds) {
    for (final rowId in rowIds) {
      _byRowId.remove(rowId);
    }
  }

  /// Cakisan bir satirda kullanici "benimki kalsin" derse, bekleyen islemin
  /// temeli sunucunun simdiki degeriyle degistirilir; bir sonraki gonderimde
  /// sunucu artik farklilik gormez ve islem gecer.
  ///
  /// [serverCurrent] null ise satir sunucuda silinmis demektir; o zaman islem
  /// yeni satir haline gelir, yoksa var olmayan bir satiri guncellemeye
  /// calisip yine takilirdi.
  void rebase(String rowId, List<String>? serverCurrent) {
    final existing = _byRowId[rowId];
    if (existing == null) return;
    _byRowId[rowId] = SharedRowOperation(
      rowId: rowId,
      isDelete: existing.isDelete,
      values: existing.values,
      base: serverCurrent == null ? null : List<String>.from(serverCurrent),
    );
  }

  void clear() => _byRowId.clear();

  List<Map<String, dynamic>> toJson() =>
      operations.map((operation) => operation.toJson()).toList();

  static PendingRowChanges fromJson(Object? raw) {
    if (raw is! List) return PendingRowChanges();
    final entries = <String, SharedRowOperation>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final operation = SharedRowOperation.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (operation != null) entries[operation.rowId] = operation;
    }
    return PendingRowChanges(entries);
  }
}
