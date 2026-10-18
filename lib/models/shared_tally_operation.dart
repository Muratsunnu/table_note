/// Buluta gonderilmeyi bekleyen tek bir cetele ogesi degisikligi.
///
/// Tablodaki satirdan farkli olarak birlestirme OGE degil GUN duzeyinde
/// yapilir: [days] yalnizca gercekten dokunulan gunleri tasir, [dayBase] de o
/// gunlerin dokunulmadan onceki halini. Sunucu gun gun karsilastirir.
///
/// Sebebi cetelenin dogasi: iki kisi ayni kisiye bakip biri Pazartesi'yi,
/// digeri Sali'yi isaretler. Ogenin tamamini karsilastirsaydik bu ikisi
/// cakisirdi; oysa birbirlerinin isini hic bozmuyorlar. Cakisma yalnizca ayni
/// ogenin AYNI gununde olur.
class SharedTallyOperation {
  final String itemId;
  final bool isDelete;

  /// Degisen gunler: anahtar gun, deger durum kodu. null, isaretin
  /// kaldirildigi anlamina gelir.
  final Map<String, String?> days;

  /// Ayni gunlerin ilk degisiklikten onceki hali.
  final Map<String, String?> dayBase;

  /// Oge adi degistiyse yeni ad, yoksa null.
  final String? name;

  /// Ogenin bulutta hic var olmadigi durumda null; yerelde olusturuldu demek.
  final String? nameBase;

  /// Yerelde olusturulmus, buluta hic gitmemis oge.
  final bool isNew;

  const SharedTallyOperation({
    required this.itemId,
    required this.isDelete,
    this.days = const {},
    this.dayBase = const {},
    this.name,
    this.nameBase,
    this.isNew = false,
  });

  Map<String, dynamic> toJson() => {
    'op': isDelete ? 'delete' : 'upsert',
    'itemId': itemId,
    'isNew': isNew,
    if (!isDelete) ...{
      'days': days,
      'dayBase': dayBase,
      if (name != null) 'name': name,
      'nameBase': nameBase,
    },
  };

  static SharedTallyOperation? fromJson(Map<String, dynamic> json) {
    final itemId = json['itemId']?.toString();
    if (itemId == null || itemId.isEmpty) return null;
    Map<String, String?> marks(Object? raw) {
      if (raw is! Map) return const {};
      return {
        for (final entry in raw.entries)
          entry.key.toString(): entry.value?.toString(),
      };
    }

    return SharedTallyOperation(
      itemId: itemId,
      isDelete: json['op'] == 'delete',
      days: marks(json['days']),
      dayBase: marks(json['dayBase']),
      name: json['name']?.toString(),
      nameBase: json['nameBase']?.toString(),
      isNew: json['isNew'] == true,
    );
  }
}

/// Bir cetelenin bekleyen degisiklikleri. Oge basina tek islem tutulur; ayni
/// oge bes kez duzenlense de buluta bir kez gider.
///
/// Kural tablodakiyle ayni, yalnizca gun bazinda uygulanir: bir gunun
/// [dayBase] degeri **ilk** dokunustan onceki degerdir ve sonraki dokunuslar
/// onu ezmez. Yoksa kullanici kendi ara adimini "kayittaki deger" sanip
/// cakismayi gozden kacirirdi.
class PendingTallyChanges {
  final Map<String, SharedTallyOperation> _byItemId;

  PendingTallyChanges([Map<String, SharedTallyOperation>? initial])
    : _byItemId = {...?initial};

  bool get isEmpty => _byItemId.isEmpty;
  bool get isNotEmpty => _byItemId.isNotEmpty;
  int get length => _byItemId.length;
  List<SharedTallyOperation> get operations => _byItemId.values.toList();
  bool contains(String itemId) => _byItemId.containsKey(itemId);

  /// Bir gunun isareti degisti.
  void recordMark(
    String itemId,
    String dayKey, {
    required String? value,
    required String? base,
  }) {
    final existing = _byItemId[itemId];
    final days = {...?existing?.days, dayKey: value};
    final dayBase = {...?existing?.dayBase};
    // Ilk dokunus temeli belirler; sonrakiler dokunmaz.
    dayBase.putIfAbsent(dayKey, () => base);
    _byItemId[itemId] = SharedTallyOperation(
      itemId: itemId,
      isDelete: false,
      days: days,
      dayBase: dayBase,
      name: existing?.name,
      nameBase: existing?.nameBase,
      isNew: existing?.isNew ?? false,
    );
  }

  /// Oge adi degisti.
  void recordRename(String itemId, String name, {String? base}) {
    final existing = _byItemId[itemId];
    _byItemId[itemId] = SharedTallyOperation(
      itemId: itemId,
      isDelete: false,
      days: existing?.days ?? const {},
      dayBase: existing?.dayBase ?? const {},
      name: name,
      // Temel ALAN bazinda donar, oge bazinda degil: ogenin gunlerine daha
      // once dokunulmus olmasi, adin temelini kacirmak icin sebep degil.
      nameBase: existing?.name == null ? base : existing!.nameBase,
      isNew: existing?.isNew ?? false,
    );
  }

  /// Yerelde yeni oge olusturuldu. Gunleri bos baslar.
  void recordCreate(String itemId, String name) {
    _byItemId[itemId] = SharedTallyOperation(
      itemId: itemId,
      isDelete: false,
      name: name,
      isNew: true,
    );
  }

  void recordDelete(String itemId) {
    final existing = _byItemId[itemId];
    // Yerelde olusturulup yine yerelde silinen ogenin buluta soyleyecegi bir
    // seyi yok; islem tamamen duser.
    if (existing != null && existing.isNew) {
      _byItemId.remove(itemId);
      return;
    }
    _byItemId[itemId] = SharedTallyOperation(itemId: itemId, isDelete: true);
  }

  /// Sunucunun uyguladigini bildirdigi ogeler kuyruktan dusulur.
  void clearApplied(Iterable<String> itemIds) {
    for (final itemId in itemIds) {
      _byItemId.remove(itemId);
    }
  }

  /// Cakisan ogede kullanici "benimki kalsin" derse, bekleyen islemin temeli
  /// sunucunun simdiki haliyle degistirilir; bir sonraki gonderimde sunucu
  /// artik farklilik gormez.
  ///
  /// [serverDays] null ise oge sunucuda silinmis demektir; islem yeni oge
  /// haline gelir, yoksa var olmayan bir ogeyi guncellemeye calisip yine
  /// takilirdi.
  void rebase(
    String itemId,
    Map<String, String?>? serverDays,
    String? serverName,
  ) {
    final existing = _byItemId[itemId];
    if (existing == null) return;
    if (serverDays == null) {
      _byItemId[itemId] = SharedTallyOperation(
        itemId: itemId,
        isDelete: existing.isDelete,
        days: existing.days,
        dayBase: const {},
        name: existing.name,
        isNew: true,
      );
      return;
    }
    _byItemId[itemId] = SharedTallyOperation(
      itemId: itemId,
      isDelete: existing.isDelete,
      days: existing.days,
      // Yalnizca gonderecegimiz gunlerin temeli gerekir.
      dayBase: {for (final day in existing.days.keys) day: serverDays[day]},
      name: existing.name,
      nameBase: serverName,
      isNew: false,
    );
  }

  void clear() => _byItemId.clear();

  List<Map<String, dynamic>> toJson() =>
      operations.map((operation) => operation.toJson()).toList();

  static PendingTallyChanges fromJson(Object? raw) {
    if (raw is! List) return PendingTallyChanges();
    final entries = <String, SharedTallyOperation>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final operation = SharedTallyOperation.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (operation != null) entries[operation.itemId] = operation;
    }
    return PendingTallyChanges(entries);
  }
}
