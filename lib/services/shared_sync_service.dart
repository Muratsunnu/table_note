import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shared_row_operation.dart';
import '../models/tabel_model.dart';
import '../providers/table_provider.dart';
import 'cloud_repository.dart';

/// Bir tablonun senkron durumu; arayuz rozetini ve cakisma ekranini besler.
class SharedSyncState {
  final bool isSending;
  final String? errorCode;
  final List<SharedRowConflict> conflicts;
  final DateTime? lastSentAt;

  const SharedSyncState({
    this.isSending = false,
    this.errorCode,
    this.conflicts = const [],
    this.lastSentAt,
  });

  bool get hasConflicts => conflicts.isNotEmpty;

  SharedSyncState copyWith({
    bool? isSending,
    String? errorCode,
    List<SharedRowConflict>? conflicts,
    DateTime? lastSentAt,
    bool clearError = false,
  }) => SharedSyncState(
    isSending: isSending ?? this.isSending,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    conflicts: conflicts ?? this.conflicts,
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
  final CloudRepository repository;

  final Map<String, SharedSyncState> _states = {};
  final Map<String, Timer> _timers = {};
  final Set<String> _inFlight = {};

  /// Indirilmis son surum. Ayni surumu tekrar indirip tabloyu bosuna
  /// degistirmemek icin tutulur.
  final Map<String, int> _knownRevision = {};
  final Set<String> _pulling = {};
  String? _openTableId;

  /// Acik olan ortak tablonun canli yayin aboneligi. Ayni anda tek tane
  /// olur: kullanici baska tabloya gecince eskisi kapatilir.
  StreamSubscription<int>? _liveWatch;
  bool _disposed = false;

  SharedSyncService({required this.tables, CloudRepository? repository})
    : repository = repository ?? CloudRepository() {
    tables.addListener(_onTablesChanged);
  }

  SharedSyncState stateFor(String tableId) =>
      _states[tableId] ?? const SharedSyncState();

  @override
  void dispose() {
    _disposed = true;
    unawaited(_liveWatch?.cancel());
    _liveWatch = null;
    tables.removeListener(_onTablesChanged);
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  void _onTablesChanged() {
    if (_disposed) return;
    final table = tables.currentTable;
    if (table == null) return;

    // Baska bir ortak tabloya gecildiginde sunucudaki hali bir kez indir.
    // Bu dinleyici her tus vurusunda calistigi icin kimlik degisimine
    // bakiliyor; yoksa her harfte bir ag cagrisi giderdi.
    if (table.id != _openTableId) {
      _openTableId = table.id;
      _watchLive(tables.isSharedTable(table.id) ? table.id : null);
      if (tables.isSharedTable(table.id)) unawaited(pull(table.id));
    }

    // Yalnizca sahip kendiliginden gonderir.
    if (!tables.isSharedOwner(table.id)) return;
    if (tables.pendingChangeCount(table.id) == 0) return;
    _timers[table.id]?.cancel();
    _timers[table.id] = Timer(ownerDebounce, () => push(table.id));
  }

  /// Katilan kisinin "Buluta kaydet" butonu da, sahibin zamanlayicisi da
  /// buraya gelir.
  Future<bool> push(String tableId) async {
    if (_disposed || _inFlight.contains(tableId)) return false;
    final pending = tables.pendingChanges(tableId);
    if (pending == null || pending.isEmpty) return true;

    _inFlight.add(tableId);
    _update(
      tableId,
      (state) => state.copyWith(isSending: true, clearError: true),
    );
    try {
      final operations = List<SharedRowOperation>.from(pending.operations);
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
  void _watchLive(String? tableId) {
    unawaited(_liveWatch?.cancel());
    _liveWatch = null;
    if (tableId == null) return;
    _liveWatch = repository.watchSharedTableRevision(tableId).listen(
      (revision) {
        // Kendi gonderimimiz de yayina dusuyor; bilinen surumse is yok.
        if (revision == 0 || revision == _knownRevision[tableId]) return;
        unawaited(pull(tableId));
      },
      // Baglanti kopabilir; uygulamanin durmasi icin sebep degil. Tablo
      // yeniden acildiginda zaten bir kez indiriliyor.
      onError: (Object error) => debugPrint('Canli yayin koptu: $error'),
    );
  }

  /// Sunucudaki hali yerele indirir.
  ///
  /// Bekleyen degisiklik varken hicbir sey yapmaz. Kullanicinin henuz
  /// gondermedigi duzenlemesini sunucunun eski haliyle ezmek dogrudan veri
  /// kaybi olurdu; o satirlar zaten gonderimde cakisma olarak karsiya cikar.
  Future<void> pull(String tableId) async {
    if (_disposed || _pulling.contains(tableId)) return;
    if (tables.pendingChangeCount(tableId) > 0) return;
    _pulling.add(tableId);
    try {
      final snapshot = await repository.fetchSharedTable(tableId);
      if (snapshot == null) return;
      if (_knownRevision[tableId] == snapshot.revision) return;
      // Istek sirasinda kullanici bir sey degistirmis olabilir.
      if (tables.pendingChangeCount(tableId) > 0) return;
      await _adopt(tableId, snapshot.payload, snapshot.revision);
    } catch (error) {
      // Tazeleme sessiz bir istek: basarisiz olmasi kullaniciyi
      // uyarmayi gerektirmez, elindeki veri gecerliligini korur.
      debugPrint('Ortak tablo indirilemedi: $error');
    } finally {
      _pulling.remove(tableId);
    }
  }

  Future<void> _adopt(
    String tableId,
    Map<String, dynamic> payload,
    int revision,
  ) async {
    _knownRevision[tableId] = revision;
    await tables.importCloudTable(
      TableModel.fromJson(payload),
      overwrite: true,
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
