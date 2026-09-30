import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shared_row_operation.dart';
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
