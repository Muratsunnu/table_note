import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../models/shared_row_operation.dart';
import '../models/shared_tally_operation.dart';
import '../models/tabel_model.dart';
import '../models/tally_model.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import 'cloud_repository.dart';
import 'storage_service.dart';

/// Bir tablonun senkron durumu; arayuz rozetini ve cakisma ekranini besler.
class SharedSyncState {
  final bool isSending;
  final String? errorCode;
  final List<SharedRowConflict> conflicts;

  /// Cetele cakismalari ayri listede: iki tur ayni ekranda hic bir arada
  /// olmaz, cunku bir kimlik ya tablodur ya cetele.
  final List<SharedTallyConflict> tallyConflicts;
  final DateTime? lastSentAt;

  const SharedSyncState({
    this.isSending = false,
    this.errorCode,
    this.conflicts = const [],
    this.tallyConflicts = const [],
    this.lastSentAt,
  });

  bool get hasConflicts => conflicts.isNotEmpty || tallyConflicts.isNotEmpty;
  int get conflictCount => conflicts.length + tallyConflicts.length;

  SharedSyncState copyWith({
    bool? isSending,
    String? errorCode,
    List<SharedRowConflict>? conflicts,
    List<SharedTallyConflict>? tallyConflicts,
    DateTime? lastSentAt,
    bool clearError = false,
  }) => SharedSyncState(
    isSending: isSending ?? this.isSending,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    conflicts: conflicts ?? this.conflicts,
    tallyConflicts: tallyConflicts ?? this.tallyConflicts,
    lastSentAt: lastSentAt ?? this.lastSentAt,
  );
}

/// Bekleyen degisiklikleri buluta gonderir, baskalarinin degisikliklerini
/// indirir.
///
/// Duzenleyebilen herkesin degisikligi kisa bir gecikmeyle kendiliginden
/// gider. Eskiden yalnizca sahibinki gidiyor, katilan kisininki butona
/// basana kadar bekliyordu; o sirada baskasi ayni satiri eklerse karisiklik
/// cikiyordu. Rol sistemi geldiginden beri yazabilenler zaten sahibin
/// onayladigi kisiler.
///
/// Maliyet dusunulerek kurulu: art arda yapilan duzenlemeler tek istekte
/// toplanir, reddedilen bir gonderim icerik degismeden yeniden denenmez,
/// tablo yalnizca gercekten degistiyse indirilir, uygulama arka plandayken
/// canli yayin baglantisi birakilir.
class SharedSyncService extends ChangeNotifier with WidgetsBindingObserver {
  /// Sahibin degisikliklerinin toplanma suresi. Her tusa basista istek
  /// atmamak icin var; widget yayinindaki 180 ms ile ayni fikir, biraz daha
  /// uzun cunku bu bir ag cagrisi.
  static const Duration ownerDebounce = Duration(milliseconds: 1200);

  /// Katilan kisinin degisikliklerinin toplanma suresi. Sahibinkinden uzun:
  /// ayni tabloda ayni anda yazan birden fazla kisi olabilir ve her gonderim
  /// tabloyu acik tutan diger herkese bir indirme yaptirir.
  static const Duration editorDebounce = Duration(seconds: 2);

  final TableProvider tables;
  final TallyProvider tallies;
  final CloudRepository repository;

  final Map<String, SharedSyncState> _states = {};
  final Map<String, Timer> _timers = {};
  final Set<String> _inFlight = {};

  /// Indirilmis son surum. Ayni surumu tekrar indirip tabloyu bosuna
  /// degistirmemek icin tutulur.
  final Map<String, int> _knownRevision = {};

  /// Bilinen surumun sunucudaki degisiklik ani. Kendi gonderimimizden sonra
  /// bilinmez (null); ilk sorulusta ogrenilir.
  final Map<String, String?> _knownUpdatedAt = {};
  late final Future<void> _versionsReady;

  /// Reddedilen son gonderimin icerigi. Ayni icerik kendiliginden yeniden
  /// gonderilmez: cozulmemis bir cakisma ya da geri alinmis bir yetki, her
  /// bildirimde bastan denenip durmasin.
  final Map<String, String> _refused = {};

  /// Zamanlayicisi kurulmus gonderimin icerigi. Icerik degismedikce sayac
  /// bastan baslatilmaz.
  final Map<String, String> _scheduled = {};

  /// Indirme surerken gelen yeni bildirimler; bitince bir kez daha bakilir.
  final Set<String> _pullAgain = {};
  bool _inBackground = false;

  /// Sunucudaki yapinin parmak izi. Yerelde bundan farkli bir yapi gorulurse
  /// sahip onu gondermeli demektir. Imza sunucudan indirilen yukla kurulur,
  /// yoksa uygulama her acilista yapiyi bosuna yeniden gonderirdi.
  final Map<String, String> _knownStructure = {};
  final Set<String> _pulling = {};
  String? _openTableId;
  String? _openTallyId;

  /// Acik ortak tablolarin canli yayin abonelikleri, kimlige gore. Tablo ve
  /// cetele sekmeleri ayri ayri acik kalabildigi icin ayni anda iki tane
  /// olabilir.
  final Map<String, StreamSubscription<int>> _liveWatches = {};

  /// Bu cihazdaki kisinin acik ortak tablolardaki yetkisi: gorunteleyenin
  /// talebi bekliyor mu, sahibin yanitlamasi gereken kac talep var.
  final Map<String, SharedAccess> _access = {};
  final Set<String> _refreshingAccess = {};
  bool _disposed = false;

  SharedSyncService({
    required this.tables,
    required this.tallies,
    CloudRepository? repository,
  }) : repository = repository ?? CloudRepository() {
    _versionsReady = _loadVersions();
    tables.addListener(_onTablesChanged);
    tallies.addListener(_onTablesChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadVersions() async {
    try {
      final stored = await StorageService.loadSharedVersions();
      for (final entry in stored.entries) {
        // Bu oturumda ogrenilen deger daha yenidir; uzerine yazilmaz.
        if (_knownRevision.containsKey(entry.key)) continue;
        _knownRevision[entry.key] = entry.value['revision'] as int;
        _knownUpdatedAt[entry.key] = entry.value['updatedAt']?.toString();
      }
    } catch (error) {
      debugPrint('Bilinen surumler okunamadi: $error');
    }
  }

  /// Yereldeki halin sunucudaki hangi surume karsilik geldigini kaydeder.
  void _remember(String id, int revision, String? updatedAt) {
    _knownRevision[id] = revision;
    _knownUpdatedAt[id] = updatedAt;
    unawaited(
      StorageService.saveSharedVersions({
        for (final entry in _knownRevision.entries)
          entry.key: {
            'revision': entry.value,
            'updatedAt': _knownUpdatedAt[entry.key],
          },
      }),
    );
  }

  /// Bu kimlik bir cetele mi? Kimlikler iki tur arasinda benzersiz oldugu
  /// icin gonderim ve indirme yolu buradan secilir.
  bool _isTally(String id) => tallies.isSharedTally(id);

  SharedSyncState stateFor(String tableId) =>
      _states[tableId] ?? const SharedSyncState();

  SharedAccess accessFor(String tableId) =>
      _access[tableId] ?? const SharedAccess();

  /// Yetkiyi sunucudan yeniden okur ve yerel rolu ona uydurur.
  ///
  /// Sahip rolu baska bir cihazdan degistirir; katilan kisinin ekrani bunu
  /// ancak sorarak ogrenir. Indirmeden ayri tutulur, cunku indirme bekleyen
  /// degisiklik varken hic calismaz ama yetki o zaman da degismis olabilir.
  Future<void> refreshAccess(String id) async {
    if (_disposed || !_refreshingAccess.add(id)) return;
    try {
      final access = await repository.sharedTableAccess(id);
      if (_disposed) return;
      _access[id] = access;
      await _applyServerRole(id, access.role);
      notifyListeners();
    } catch (error) {
      // Sessiz bir tazeleme: basarisiz olursa eldeki rol gecerli kalir.
      // Yazma yetkisini zaten sunucu denetler.
      debugPrint('Yetki okunamadi: $error');
    } finally {
      _refreshingAccess.remove(id);
    }
  }

  /// Yalnizca katilan kisinin iki rolu arasinda gecis yapar. Sahiplik ya da
  /// uyeligin bittigi bilgisi buradan yerel kayda islenmez: yanlis okunan tek
  /// bir yanit, tabloyu bulutla baglantisiz birakmamali.
  Future<void> _applyServerRole(String id, String? role) async {
    if (role != 'viewer' && role != 'editor') return;
    final isTally = _isTally(id);
    final local = isTally ? tallies.sharedRole(id) : tables.sharedRole(id);
    if (local == null || local == 'owner' || local == role) return;
    if (isTally) {
      await tallies.setSharedRole(id, role);
    } else {
      await tables.setSharedRole(id, role);
    }
  }

  /// Goruntuleyen kisinin duzenleme yetkisi talebi. Basarida null, aksi
  /// halde arayuzun gosterecegi hata kodu doner.
  Future<String?> requestEditAccess(String id) async {
    try {
      final access = await repository.requestSharedEditAccess(id);
      if (_disposed) return null;
      _access[id] = access;
      await _applyServerRole(id, access.role);
      notifyListeners();
      return null;
    } on SharedTableException catch (error) {
      if (!error.isKnown) debugPrint('Bilinmeyen talep kodu: ${error.code}');
      return error.isKnown ? error.code : 'unknown';
    } catch (error) {
      debugPrint('Yetki talebi gonderilemedi: $error');
      return 'unknown';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final watch in _liveWatches.values) {
      unawaited(watch.cancel());
    }
    _liveWatches.clear();
    WidgetsBinding.instance.removeObserver(this);
    tables.removeListener(_onTablesChanged);
    tallies.removeListener(_onTablesChanged);
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  void _onTablesChanged() {
    if (_disposed) return;

    // Baska bir ortak tabloya ya da ceteleye gecildiginde sunucudaki hali bir
    // kez indir. Bu dinleyici her tus vurusunda calistigi icin kimlik
    // degisimine bakiliyor; yoksa her harfte bir ag cagrisi giderdi.
    final tableId = tables.currentTable?.id;
    if (tableId != null && tableId != _openTableId) {
      _openTableId = tableId;
      if (tables.isSharedTable(tableId)) {
        unawaited(pull(tableId));
        unawaited(refreshAccess(tableId));
      }
    }
    final tallyId = tallies.currentTable?.id;
    if (tallyId != null && tallyId != _openTallyId) {
      _openTallyId = tallyId;
      if (tallies.isSharedTally(tallyId)) {
        unawaited(pull(tallyId));
        unawaited(refreshAccess(tallyId));
      }
    }
    _syncWatches();

    // Duzenleyebilen herkesin degisikligi kendiliginden gider; yapi yalnizca
    // sahibindir.
    if (tableId != null && tables.isSharedTable(tableId)) {
      _scheduleAutoPush(tableId);
      if (tables.isSharedOwner(tableId)) _scheduleStructurePush(tableId);
    }
    if (tallyId != null && tallies.isSharedTally(tallyId)) {
      _scheduleAutoPush(tallyId);
      if (tallies.isSharedOwner(tallyId)) _scheduleStructurePush(tallyId);
    }
  }

  /// Yapinin degisip degismedigine imzayla bakilir. Bunu her cagiran ekrana
  /// elle eklemek yerine burada saptamak, ileride eklenecek bir yapi
  /// duzenleme yolunun sessizce senkron disinda kalmasini engelliyor.
  void _scheduleStructurePush(String id) {
    final signature = _structureOf(id);
    if (signature == null) return;
    final known = _knownStructure[id];
    if (known == null) {
      // Sunucudaki hali hic gormedik; bunu "degisiklik" sayip gondermek
      // yanlis olurdu.
      _knownStructure[id] = signature;
      return;
    }
    if (known == signature) return;
    _timers['$id#structure']?.cancel();
    _timers['$id#structure'] = Timer(ownerDebounce, () => pushStructure(id));
  }

  String? _structureOf(String id) {
    if (_isTally(id)) {
      final tally = tallies.tables.where((item) => item.id == id).firstOrNull;
      if (tally == null) return null;
      return jsonEncode({
        'name': tally.tableName,
        'statuses': tally.statuses.map((status) => status.toJson()).toList(),
        'start': tally.startDate.toIso8601String(),
        'end': tally.endDate.toIso8601String(),
      });
    }
    final table = tables.tables.where((item) => item.id == id).firstOrNull;
    if (table == null) return null;
    return jsonEncode({
      'name': table.tableName,
      'columns': table.columns.map((column) => column.toJson()).toList(),
    });
  }

  /// Yapi degisikligini gonderir. Satirlar gonderilmez; sunucu mevcut
  /// satirlarin boyunu kendisi ayarlar, boylece karsi tarafin o sirada
  /// kaydettigi satir tehlikeye girmez.
  Future<bool> pushStructure(String id) async {
    if (_disposed || _inFlight.contains(id)) return false;
    final isTally = _isTally(id);
    final isOwner = isTally
        ? tallies.isSharedOwner(id)
        : tables.isSharedOwner(id);
    if (!isOwner) return false;
    final signature = _structureOf(id);
    if (signature == null) return false;

    _inFlight.add(id);
    _update(id, (state) => state.copyWith(isSending: true, clearError: true));
    try {
      final SharedRowSyncResult result;
      if (isTally) {
        final tally = tallies.tables.firstWhere((item) => item.id == id);
        result = await repository.applySharedTallyStructure(
          tallyId: id,
          name: tally.tableName,
          statuses: tally.statuses.map((status) => status.toJson()).toList(),
          startDate: tally.startDate.toIso8601String(),
          endDate: tally.endDate.toIso8601String(),
        );
      } else {
        final table = tables.tables.firstWhere((item) => item.id == id);
        result = await repository.applySharedTableColumns(
          tableId: id,
          name: table.tableName,
          columns: table.columns.map((column) => column.toJson()).toList(),
        );
      }
      _remember(id, result.revision, null);
      _knownStructure[id] = signature;
      _update(
        id,
        (state) => state.copyWith(
          isSending: false,
          lastSentAt: DateTime.now(),
          clearError: true,
        ),
      );
      return true;
    } on SharedTableException catch (error) {
      if (!error.isKnown) debugPrint('Bilinmeyen yapi kodu: ${error.code}');
      _update(
        id,
        (state) => state.copyWith(
          isSending: false,
          errorCode: error.isKnown ? error.code : 'unknown',
        ),
      );
      return false;
    } catch (error) {
      debugPrint('Yapi gonderilemedi: $error');
      _update(
        id,
        (state) => state.copyWith(isSending: false, errorCode: 'unknown'),
      );
      return false;
    } finally {
      _inFlight.remove(id);
      // Yapi gonderilirken sayaci dolan satir gonderimi atlanmis olabilir.
      if (!_disposed) _scheduleAutoPush(id);
    }
  }

  /// Bekleyen degisikliklerin icerigi; yoksa null. Icerigin degisip
  /// degismedigini anlamak icin kullanilir, baska bir anlami yoktur.
  String? _pendingFingerprint(String id) {
    final operations = _isTally(id)
        ? tallies.pendingChanges(id)?.toJson()
        : tables.pendingChanges(id)?.toJson();
    if (operations == null || operations.isEmpty) return null;
    return jsonEncode(operations);
  }

  /// Bekleyen degisiklikleri, son degisiklikten kisa bir sure sonra gonderir.
  void _scheduleAutoPush(String id) {
    final role = _isTally(id) ? tallies.sharedRole(id) : tables.sharedRole(id);
    // Goruntuleyenin gonderecegi bir sey olmaz. Yetkisi alinmis kisinin
    // kuyrugu ise yetki geri gelene kadar bekler; sayaci islerken yetki
    // alinmissa sayac da durdurulur.
    if (role != 'owner' && role != 'editor') {
      _timers.remove(id)?.cancel();
      _scheduled.remove(id);
      return;
    }
    // Suren bir gonderim sirasinda gelen bildirimler (uygulananlarin
    // kuyruktan dusmesi gibi) yeni bir sayac kurmaz; gonderim bitince, sonucu
    // bilinerek yeniden bakilir.
    if (_inFlight.contains(id)) return;
    final fingerprint = _pendingFingerprint(id);
    if (fingerprint == null) {
      _refused.remove(id);
      _scheduled.remove(id);
      return;
    }
    // Az once reddedilen ayni icerik ya da sayaci zaten isleyen icerik.
    if (_refused[id] == fingerprint || _scheduled[id] == fingerprint) return;
    _scheduled[id] = fingerprint;
    _timers[id]?.cancel();
    _timers[id] = Timer(role == 'owner' ? ownerDebounce : editorDebounce, () {
      _scheduled.remove(id);
      push(id);
    });
  }

  /// Gonderimin sonucunu isler: reddedilen icerik, degismedikce kendiliginden
  /// yeniden denenmez.
  void _noteOutcome(String id, {required bool refused}) {
    final fingerprint = refused ? _pendingFingerprint(id) : null;
    if (fingerprint == null) {
      _refused.remove(id);
    } else {
      _refused[id] = fingerprint;
    }
  }

  /// Bekleyen her seyi hemen gonderir: uygulama arka plana gecerken sayacin
  /// dolmasini beklemek, degisikligin hic gitmemesi demek olabilir.
  void flush() {
    for (final id in _scheduled.keys.toList()) {
      _timers.remove(id)?.cancel();
      _scheduled.remove(id);
      unawaited(push(id));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_inBackground) return;
        _inBackground = false;
        _syncWatches();
        // Arka plandayken kacirilanlar: yetki, baskalarinin degisiklikleri
        // ve gonderilememis kendi degisikliklerimiz.
        for (final id in _openSharedIds()) {
          _refused.remove(id);
          unawaited(refreshAccess(id));
          unawaited(pull(id));
          _scheduleAutoPush(id);
        }
      case AppLifecycleState.inactive:
        flush();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_inBackground) return;
        _inBackground = true;
        flush();
        // Arka plandaki uygulama canli yayin baglantisi tutmasin; ayni anda
        // acik baglanti sayisi sinirli.
        _syncWatches();
    }
  }

  Set<String> _openSharedIds() => {
    if (_openTableId case final id? when tables.isSharedTable(id)) id,
    if (_openTallyId case final id? when tallies.isSharedTally(id)) id,
  };

  /// Zamanlayici da, gostergeye dokunan kullanici da buraya gelir.
  Future<bool> push(String tableId) async {
    if (_disposed || _inFlight.contains(tableId)) return false;
    final isTally = _isTally(tableId);
    final pendingCount = isTally
        ? tallies.pendingChangeCount(tableId)
        : tables.pendingChangeCount(tableId);
    if (pendingCount == 0) return true;

    // Yetkisi olmayanin gonderimini sunucu zaten reddeder; bosuna sorulmaz.
    final role = isTally
        ? tallies.sharedRole(tableId)
        : tables.sharedRole(tableId);
    if (role != 'owner' && role != 'editor') {
      _update(
        tableId,
        (state) =>
            state.copyWith(errorCode: 'shared_table_edit_access_required'),
      );
      return false;
    }

    _inFlight.add(tableId);
    _update(
      tableId,
      (state) => state.copyWith(isSending: true, clearError: true),
    );
    try {
      if (isTally) {
        final operations = List<SharedTallyOperation>.from(
          tallies.pendingChanges(tableId)!.operations,
        );
        final result = await repository.applySharedTallyItems(
          tableId,
          operations,
        );
        await tallies.markChangesApplied(tableId, result.applied);
        if (!result.hasConflicts && result.payload != null) {
          await _adopt(tableId, result.payload!, result.revision);
        }
        _noteOutcome(tableId, refused: result.hasConflicts);
        _update(
          tableId,
          (state) => state.copyWith(
            isSending: false,
            tallyConflicts: result.conflicts,
            lastSentAt: DateTime.now(),
            clearError: true,
          ),
        );
        return !result.hasConflicts;
      }
      final operations = List<SharedRowOperation>.from(
        tables.pendingChanges(tableId)!.operations,
      );
      final result = await repository.applySharedTableRows(tableId, operations);
      await tables.markChangesApplied(tableId, result.applied);
      // Sunucu, birlestirme sonrasi tablonun tamamini geri veriyor. Karsi
      // tarafin bu arada kaydettigi satirlar da icinde; bedava gelen bu
      // veriyi atmak, gonderen kisiyi eski halde birakmak olurdu.
      if (!result.hasConflicts && result.payload != null) {
        await _adopt(tableId, result.payload!, result.revision);
      }
      _noteOutcome(tableId, refused: result.hasConflicts);
      _update(
        tableId,
        (state) => state.copyWith(
          isSending: false,
          conflicts: result.conflicts,
          lastSentAt: DateTime.now(),
          clearError: true,
        ),
      );
      return !result.hasConflicts;
    } on SharedTableException catch (error) {
      // Beklenmeyen bir sunucu kodu kullaniciya ham haliyle gosterilmez ama
      // teshis edilemez de kalmamali; katilim ekraninda bu zaten boyleydi.
      if (!error.isKnown) debugPrint('Bilinmeyen senkron kodu: ${error.code}');
      if (error.code == 'shared_table_edit_access_required') {
        // Sahip yetkiyi geri almis. Bekleyen degisiklikler silinmez; yetki
        // yeniden verilirse gonderilebilirler.
        unawaited(refreshAccess(tableId));
      }
      _noteOutcome(tableId, refused: true);
      _update(
        tableId,
        (state) => state.copyWith(
          isSending: false,
          errorCode: error.isKnown ? error.code : 'unknown',
        ),
      );
      return false;
    } catch (error) {
      debugPrint('Ortak tablo gonderilemedi: $error');
      _noteOutcome(tableId, refused: true);
      _update(
        tableId,
        (state) => state.copyWith(isSending: false, errorCode: 'unknown'),
      );
      return false;
    } finally {
      _inFlight.remove(tableId);
      // Gonderim surerken yapilan yeni duzenlemeler burada yakalanir.
      if (!_disposed) _scheduleAutoPush(tableId);
    }
  }

  /// Acik tablonun canli yayinina abone olur, oncekini birakir.
  ///
  /// Karsi taraf kaydettigi anda surum artar ve asagidaki dinleyici
  /// indirmeyi tetikler; ekran kendiliginden guncellenir. Beklemek yerine
  /// anlik olmasinin sebebi satir eklemek: baskasinin ekledigi satiri
  /// gormeyen kullanici ayni sira numarasini uretir.
  void _syncWatches() {
    // Arka plandayken hicbir tablo izlenmez.
    final wanted = _inBackground ? <String>{} : _openSharedIds();

    for (final id in _liveWatches.keys.toList()) {
      if (wanted.contains(id)) continue;
      unawaited(_liveWatches.remove(id)?.cancel());
    }
    for (final id in wanted) {
      if (_liveWatches.containsKey(id)) continue;
      _liveWatches[id] = repository.watchSharedTableRevision(id).listen(
        (revision) {
          if (revision == CloudRepository.revisionUnknown) {
            // Baglanti kopup yeniden kuruldu; arada bir sey kacmis olabilir.
            // Ucuz yoldan sorulur: degismediyse tablo indirilmez.
            unawaited(refreshAccess(id));
            unawaited(pull(id));
            return;
          }
          // Kendi gonderimimiz de yayina dusuyor; bilinen surumse is yok.
          if (revision == 0 || revision == _knownRevision[id]) return;
          // Surum, rol ya da talep degistiginde de artar. Yetki, indirmenin
          // atlandigi durumda bile (bekleyen degisiklik varken) sorulur.
          unawaited(refreshAccess(id));
          unawaited(pull(id, changed: true));
        },
        // Baglanti kopabilir; uygulamanin durmasi icin sebep degil. Tablo
        // yeniden acildiginda zaten bir kez indiriliyor.
        onError: (Object error) => debugPrint('Canli yayin koptu: $error'),
      );
    }
  }

  /// Sunucudaki hali yerele indirir.
  ///
  /// Bekleyen degisiklik varken hicbir sey yapmaz. Kullanicinin henuz
  /// gondermedigi duzenlemesini sunucunun eski haliyle ezmek dogrudan veri
  /// kaybi olurdu; o satirlar zaten gonderimde cakisma olarak karsiya cikar.
  ///
  /// Tablonun tamami yalnizca degistiyse indirilir. Degistigi biliniyorsa
  /// ([changed], canli yayin soyledi) dogrudan indirilir; bilinmiyorsa (tablo
  /// acildi, uygulama one geldi) once birkac yuz baytlik surum sorulur.
  Future<void> pull(String tableId, {bool changed = false}) async {
    if (_disposed) return;
    if (_pulling.contains(tableId)) {
      // Suren indirme bu bildirimden onceki hali getiriyor olabilir.
      _pullAgain.add(tableId);
      return;
    }
    if (_pendingCount(tableId) > 0) return;
    _pulling.add(tableId);
    try {
      await _versionsReady;
      if (!changed && _knownRevision.containsKey(tableId)) {
        final version = await repository.fetchSharedTableVersion(tableId);
        if (version == null) return;
        if (_isKnown(tableId, version.revision, version.updatedAt)) {
          // Kendi gonderimimizden sonra degisiklik anini bilmiyorduk.
          if (_knownUpdatedAt[tableId] == null && version.updatedAt != null) {
            _remember(tableId, version.revision, version.updatedAt);
          }
          return;
        }
      }
      final snapshot = await repository.fetchSharedTable(tableId);
      if (snapshot == null) return;
      if (_isKnown(tableId, snapshot.revision, snapshot.updatedAt)) return;
      // Istek sirasinda kullanici bir sey degistirmis olabilir.
      if (_pendingCount(tableId) > 0) return;
      await _adopt(
        tableId,
        snapshot.payload,
        snapshot.revision,
        updatedAt: snapshot.updatedAt,
      );
    } catch (error) {
      // Tazeleme sessiz bir istek: basarisiz olmasi kullaniciyi
      // uyarmayi gerektirmez, elindeki veri gecerliligini korur.
      debugPrint('Ortak tablo indirilemedi: $error');
    } finally {
      _pulling.remove(tableId);
      if (_pullAgain.remove(tableId) && !_disposed) unawaited(pull(tableId));
    }
  }

  /// Yereldeki hal bu surume karsilik mi geliyor. Surum ayni olsa da
  /// degisiklik ani farkliysa yuk degismistir: paylasim kapaliyken yapilan
  /// yedekleme surumu artirmaz.
  bool _isKnown(String id, int revision, String? updatedAt) {
    if (_knownRevision[id] != revision) return false;
    final knownAt = _knownUpdatedAt[id];
    return knownAt == null || updatedAt == null || knownAt == updatedAt;
  }

  int _pendingCount(String id) => _isTally(id)
      ? tallies.pendingChangeCount(id)
      : tables.pendingChangeCount(id);

  Future<void> _adopt(
    String tableId,
    Map<String, dynamic> payload,
    int revision, {
    String? updatedAt,
  }) async {
    _remember(tableId, revision, updatedAt);
    if (_isTally(tableId)) {
      await tallies.importCloudTable(
        TallyTableModel.fromJson(payload),
        overwrite: true,
      );
    } else {
      await tables.importCloudTable(
        TableModel.fromJson(payload),
        overwrite: true,
      );
    }
    // Sunucudaki yapi artik yerelde. Imza buradan kurulur ki bundan sonraki
    // YEREL bir degisiklik "gonderilmeli" diye saptanabilsin.
    _knownStructure[tableId] = _structureOf(tableId) ?? '';
  }

  /// Cakisan ogede kayittaki hali kabul et.
  Future<void> keepServerItem(
    String tallyId,
    SharedTallyConflict conflict,
  ) async {
    await tallies.applyServerItem(tallyId, conflict.itemId, conflict.current);
    await tallies.markChangesApplied(tallyId, [conflict.itemId]);
    _dropTallyConflict(tallyId, conflict.itemId);
  }

  /// Cakisan ogede kendi halini dayat.
  Future<void> keepLocalItem(
    String tallyId,
    SharedTallyConflict conflict,
  ) async {
    tallies.rebaseChange(tallyId, conflict.itemId, conflict.current);
    _dropTallyConflict(tallyId, conflict.itemId);
  }

  void _dropTallyConflict(String tallyId, String itemId) {
    final state = stateFor(tallyId);
    _update(
      tallyId,
      (current) => current.copyWith(
        tallyConflicts: [
          for (final conflict in state.tallyConflicts)
            if (conflict.itemId != itemId) conflict,
        ],
      ),
    );
  }

  /// Cakisan satirda kayittaki hali kabul et: yerel satir sunucudakiyle
  /// degistirilir ve bekleyen islem duser.
  Future<void> keepServerVersion(
    String tableId,
    SharedRowConflict conflict,
  ) async {
    await tables.applyServerRow(tableId, conflict.rowId, conflict.current);
    await tables.markChangesApplied(tableId, [conflict.rowId]);
    _dropConflict(tableId, conflict.rowId);
  }

  /// Cakisan satirda kendi halini dayat: bekleyen islemin temeli sunucunun
  /// simdiki degeriyle degistirilir, boylece bir sonraki gonderimde gecer.
  Future<void> keepLocalVersion(
    String tableId,
    SharedRowConflict conflict,
  ) async {
    tables.rebaseChange(tableId, conflict.rowId, conflict.current);
    _dropConflict(tableId, conflict.rowId);
  }

  void _dropConflict(String tableId, String rowId) {
    final state = stateFor(tableId);
    _update(
      tableId,
      (current) => current.copyWith(
        conflicts: [
          for (final conflict in state.conflicts)
            if (conflict.rowId != rowId) conflict,
        ],
      ),
    );
  }

  void _update(
    String tableId,
    SharedSyncState Function(SharedSyncState) change,
  ) {
    if (_disposed) return;
    _states[tableId] = change(stateFor(tableId));
    notifyListeners();
  }
}
