import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/shared_row_operation.dart';
import '../models/shared_tally_operation.dart';
import '../models/tabel_model.dart';
import '../models/tally_model.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import 'cloud_repository.dart';

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

/// Bekleyen satir degisikliklerini buluta gonderir.
///
/// Iki farkli ritim var ve bu bilincli: tabloyu paylasan kisinin her
/// degisikligi kisa bir gecikmeyle kendiliginden gider, katilan kisininki
/// birikir ve ancak butona basinca gonderilir. Katilanin yarim kalmis
/// duzenlemesi digerlerinin ekranina damlamasin diye.
class SharedSyncService extends ChangeNotifier {
  /// Sahibin degisikliklerinin toplanma suresi. Her tusa basista istek
  /// atmamak icin var; widget yayinindaki 180 ms ile ayni fikir, biraz daha
  /// uzun cunku bu bir ag cagrisi.
  static const Duration ownerDebounce = Duration(milliseconds: 1200);

  final TableProvider tables;
  final TallyProvider tallies;
  final CloudRepository repository;

  final Map<String, SharedSyncState> _states = {};
  final Map<String, Timer> _timers = {};
  final Set<String> _inFlight = {};

  /// Indirilmis son surum. Ayni surumu tekrar indirip tabloyu bosuna
  /// degistirmemek icin tutulur.
  final Map<String, int> _knownRevision = {};

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
  bool _disposed = false;

  SharedSyncService({
    required this.tables,
    required this.tallies,
    CloudRepository? repository,
  }) : repository = repository ?? CloudRepository() {
    tables.addListener(_onTablesChanged);
    tallies.addListener(_onTablesChanged);
  }

  /// Bu kimlik bir cetele mi? Kimlikler iki tur arasinda benzersiz oldugu
  /// icin gonderim ve indirme yolu buradan secilir.
  bool _isTally(String id) => tallies.isSharedTally(id);

  SharedSyncState stateFor(String tableId) =>
      _states[tableId] ?? const SharedSyncState();

  @override
  void dispose() {
    _disposed = true;
    for (final watch in _liveWatches.values) {
      unawaited(watch.cancel());
    }
    _liveWatches.clear();
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
      if (tables.isSharedTable(tableId)) unawaited(pull(tableId));
    }
    final tallyId = tallies.currentTable?.id;
    if (tallyId != null && tallyId != _openTallyId) {
      _openTallyId = tallyId;
      if (tallies.isSharedTally(tallyId)) unawaited(pull(tallyId));
    }
    _syncWatches();

    // Yalnizca sahip kendiliginden gonderir.
    if (tableId != null && tables.isSharedOwner(tableId)) {
      _scheduleOwnerPush(tableId, tables.pendingChangeCount(tableId));
      _scheduleStructurePush(tableId);
    }
    if (tallyId != null && tallies.isSharedOwner(tallyId)) {
      _scheduleOwnerPush(tallyId, tallies.pendingChangeCount(tallyId));
      _scheduleStructurePush(tallyId);
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
      _knownRevision[id] = result.revision;
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
    }
  }

  void _scheduleOwnerPush(String id, int pending) {
    if (pending == 0) return;
    _timers[id]?.cancel();
    _timers[id] = Timer(ownerDebounce, () => push(id));
  }

  /// Katilan kisinin "Buluta kaydet" butonu da, sahibin zamanlayicisi da
  /// buraya gelir.
  Future<bool> push(String tableId) async {
    if (_disposed || _inFlight.contains(tableId)) return false;
    final isTally = _isTally(tableId);
    final pendingCount = isTally
        ? tallies.pendingChangeCount(tableId)
        : tables.pendingChangeCount(tableId);
    if (pendingCount == 0) return true;

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
      _update(
        tableId,
        (state) => state.copyWith(isSending: false, errorCode: 'unknown'),
      );
      return false;
    } finally {
      _inFlight.remove(tableId);
    }
  }

  /// Acik tablonun canli yayinina abone olur, oncekini birakir.
  ///
  /// Karsi taraf kaydettigi anda surum artar ve asagidaki dinleyici
  /// indirmeyi tetikler; ekran kendiliginden guncellenir. Beklemek yerine
  /// anlik olmasinin sebebi satir eklemek: baskasinin ekledigi satiri
  /// gormeyen kullanici ayni sira numarasini uretir.
  void _syncWatches() {
    final wanted = <String>{};
    final tableId = _openTableId;
    if (tableId != null && tables.isSharedTable(tableId)) wanted.add(tableId);
    final tallyId = _openTallyId;
    if (tallyId != null && tallies.isSharedTally(tallyId)) wanted.add(tallyId);

    for (final id in _liveWatches.keys.toList()) {
      if (wanted.contains(id)) continue;
      unawaited(_liveWatches.remove(id)?.cancel());
    }
    for (final id in wanted) {
      if (_liveWatches.containsKey(id)) continue;
      _liveWatches[id] = repository.watchSharedTableRevision(id).listen(
        (revision) {
          // Kendi gonderimimiz de yayina dusuyor; bilinen surumse is yok.
          if (revision == 0 || revision == _knownRevision[id]) return;
          unawaited(pull(id));
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
  Future<void> pull(String tableId) async {
    if (_disposed || _pulling.contains(tableId)) return;
    if (_pendingCount(tableId) > 0) return;
    _pulling.add(tableId);
    try {
      final snapshot = await repository.fetchSharedTable(tableId);
      if (snapshot == null) return;
      if (_knownRevision[tableId] == snapshot.revision) return;
      // Istek sirasinda kullanici bir sey degistirmis olabilir.
      if (_pendingCount(tableId) > 0) return;
      await _adopt(tableId, snapshot.payload, snapshot.revision);
    } catch (error) {
      // Tazeleme sessiz bir istek: basarisiz olmasi kullaniciyi
      // uyarmayi gerektirmez, elindeki veri gecerliligini korur.
      debugPrint('Ortak tablo indirilemedi: $error');
    } finally {
      _pulling.remove(tableId);
    }
  }

  int _pendingCount(String id) => _isTally(id)
      ? tallies.pendingChangeCount(id)
      : tables.pendingChangeCount(id);

  Future<void> _adopt(
    String tableId,
    Map<String, dynamic> payload,
    int revision,
  ) async {
    _knownRevision[tableId] = revision;
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
