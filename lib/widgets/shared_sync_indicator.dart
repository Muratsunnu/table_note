import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../models/shared_tally_operation.dart';
import '../services/cloud_repository.dart';
import '../services/shared_sync_service.dart';

/// Ortak tablolarda tablo adinin yaninda duran senkron gostergesi.
///
/// Siradan bir tabloda hicbir sey cizmez, yani paylasim kullanmayan
/// kullanici bunu hic gormez.
///
/// Bilerek yalnizca ikon: eskiden kendi satirini kaplayan bir serit vardi ve
/// "Bulutla esit" gibi surekli duran bir metin tasiyordu. Metin, iyi durumda
/// hicbir sey soylemiyor ama tabloyu asagi itiyordu. Durumu ikonun kendisi
/// anlatiyor; kelimeler dokunmatik ipucunda duruyor.
///
/// Islem gerektiren durumlarda ikonun kendisi dugmedir: bekleyen degisiklik
/// varken dokunmak gonderir, cakisma varken cozum ekranini acar.
class SharedSyncIndicator extends StatelessWidget {
  const SharedSyncIndicator({super.key, this.isTally = false});

  /// Cetele ekraninda duran gosterge, tablo saglayicisi yerine cetele
  /// saglayicisina bakar. Durum, ikonlar ve dokunma davranisi aynidir.
  final bool isTally;

  @override
  Widget build(BuildContext context) {
    // Her iki saglayici da izlenir ki gosterge kendi turundeki degisikligi
    // kacirmasin; hangisinin okunacagini isTally belirler.
    final tables = context.watch<TableProvider>();
    final tallies = context.watch<TallyProvider>();
    final String? id = isTally
        ? tallies.currentTable?.id
        : tables.currentTable?.id;
    final shared =
        id != null &&
        (isTally ? tallies.isSharedTally(id) : tables.isSharedTable(id));
    if (!shared) return const SizedBox.shrink();

    final sync = context.watch<SharedSyncService>();
    final state = sync.stateFor(id);
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final pending = isTally
        ? tallies.pendingChangeCount(id)
        : tables.pendingChangeCount(id);
    final isOwner = isTally
        ? tallies.isSharedOwner(id)
        : tables.isSharedOwner(id);

    final IconData icon;
    final Color color;
    final String label;
    VoidCallback? onTap;
    var needsAttention = false;

    if (state.hasConflicts) {
      icon = Icons.cloud_sync_rounded;
      color = colors.error;
      label = loc.conflictCount(state.conflictCount);
      needsAttention = true;
      onTap = () => _showConflicts(context, id, isTally: isTally);
    } else if (state.errorCode != null) {
      icon = Icons.cloud_off_rounded;
      color = colors.error;
      label = loc.sharedTableError(state.errorCode!);
      onTap = () => context.read<SharedSyncService>().push(id);
    } else if (state.isSending) {
      icon = Icons.cloud_sync_rounded;
      color = colors.primary;
      label = loc.syncSending;
    } else if (pending > 0) {
      // Sahip kendiliginden gonderir, bekleme hali onda goz acip kapayincaya
      // kadar surer; dokunma yalnizca katilan kisi icin anlamli.
      icon = isOwner ? Icons.cloud_sync_rounded : Icons.cloud_upload_rounded;
      color = colors.primary;
      label = isOwner ? loc.syncSending : loc.pendingChangeCount(pending);
      if (!isOwner) {
        onTap = () => context.read<SharedSyncService>().push(id);
      }
    } else {
      icon = Icons.cloud_done_rounded;
      color = colors.onSurfaceVariant;
      label = loc.syncUpToDate;
    }

    Widget glyph = Icon(icon, size: 22, color: color);
    if (needsAttention) {
      // Kirmizi nokta, "gonderiliyor" ile "karar bekliyor" arasindaki farki
      // renkten bagimsiz olarak da belli eder.
      glyph = Badge(backgroundColor: colors.error, child: glyph);
    }

    return Tooltip(
      message: label,
      child: onTap == null
          ? Padding(padding: const EdgeInsets.all(6), child: glyph)
          : InkResponse(
              onTap: onTap,
              radius: 24,
              child: Padding(padding: const EdgeInsets.all(6), child: glyph),
            ),
    );
  }

  Future<void> _showConflicts(
    BuildContext context,
    String tableId, {
    required bool isTally,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => isTally
          ? _TallyConflictSheet(tallyId: tableId)
          : _ConflictSheet(tableId: tableId),
    );
  }
}

class _ConflictSheet extends StatelessWidget {
  const _ConflictSheet({required this.tableId});

  final String tableId;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final tables = context.watch<TableProvider>();
    final sync = context.watch<SharedSyncService>();
    final conflicts = sync.stateFor(tableId).conflicts;
    final table = tables.currentTable;

    if (conflicts.isEmpty) {
      // Son cakisma da cozulunce sayfa kendini kapatir.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.maybePop(context);
      });
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            loc.conflictTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            loc.conflictExplainer,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final conflict in conflicts)
            _ConflictCard(
              conflict: conflict,
              mine: _mineFor(tables, table?.id, conflict.rowId),
              onKeepServer: () => context
                  .read<SharedSyncService>()
                  .keepServerVersion(tableId, conflict),
              onKeepMine: () => context
                  .read<SharedSyncService>()
                  .keepLocalVersion(tableId, conflict),
            ),
        ],
      ),
    );
  }

  List<String>? _mineFor(TableProvider tables, String? tableId, String rowId) {
    if (tableId == null) return null;
    return tables
        .pendingChanges(tableId)
        ?.operations
        .where((operation) => operation.rowId == rowId)
        .firstOrNull
        ?.values;
  }
}

/// Cetele cakismalari. Tablodakinden tek farki neyin gosterildigi: satirin
/// tamami yerine ogenin adi ve YALNIZCA cakisan gunler. Butun gunleri yan
/// yana dizmek okunmazdi ve zaten cogu ayni.
class _TallyConflictSheet extends StatelessWidget {
  const _TallyConflictSheet({required this.tallyId});

  final String tallyId;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final tallies = context.watch<TallyProvider>();
    final sync = context.watch<SharedSyncService>();
    final conflicts = sync.stateFor(tallyId).tallyConflicts;

    if (conflicts.isEmpty) {
      // Son cakisma da cozulunce sayfa kendini kapatir.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.maybePop(context);
      });
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            loc.conflictTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            loc.conflictExplainer,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final conflict in conflicts)
            _TallyConflictCard(
              conflict: conflict,
              mine: _mineFor(tallies, conflict.itemId),
              labelFor: (code) => _statusLabel(tallies, code),
              onKeepServer: () => context
                  .read<SharedSyncService>()
                  .keepServerItem(tallyId, conflict),
              onKeepMine: () => context.read<SharedSyncService>().keepLocalItem(
                tallyId,
                conflict,
              ),
            ),
        ],
      ),
    );
  }

  SharedTallyOperation? _mineFor(TallyProvider tallies, String itemId) =>
      tallies
          .pendingChanges(tallyId)
          ?.operations
          .where((operation) => operation.itemId == itemId)
          .firstOrNull;

  /// Durum kodu tek basina bir sey anlatmaz; kullanicinin ekranda gordugu
  /// etiket gosterilir.
  String _statusLabel(TallyProvider tallies, String? code) {
    if (code == null || code.isEmpty) return '—';
    final table = tallies.tables
        .where((item) => item.id == tallyId)
        .firstOrNull;
    final status = table?.statuses
        .where((item) => item.code == code)
        .firstOrNull;
    return status?.label ?? code;
  }
}

class _TallyConflictCard extends StatelessWidget {
  const _TallyConflictCard({
    required this.conflict,
    required this.mine,
    required this.labelFor,
    required this.onKeepServer,
    required this.onKeepMine,
  });

  final SharedTallyConflict conflict;
  final SharedTallyOperation? mine;
  final String Function(String?) labelFor;
  final VoidCallback onKeepServer;
  final VoidCallback onKeepMine;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final name = conflict.current?.name ?? mine?.name ?? '—';
    // Yalnizca iki tarafin da dokundugu gunler gosterilir.
    final days = (mine?.days.keys.toList() ?? <String>[])..sort();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflict.reason == 'deleted'
                  ? loc.conflictRowDeleted
                  : loc.conflictRowChanged,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(name, style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 10),
            for (final day in days)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${loc.conflictMine}: ${labelFor(mine?.days[day])}'
                        '   ·   ${loc.conflictTheirs}: '
                        '${labelFor(conflict.current?.entries[day])}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onKeepServer,
                  child: Text(loc.conflictKeepTheirs),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onKeepMine,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  child: Text(loc.conflictKeepMine),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.mine,
    required this.onKeepServer,
    required this.onKeepMine,
  });

  final SharedRowConflict conflict;
  final List<String>? mine;
  final VoidCallback onKeepServer;
  final VoidCallback onKeepMine;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflict.reason == 'deleted'
                  ? loc.conflictRowDeleted
                  : loc.conflictRowChanged,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _Side(label: loc.conflictMine, values: mine),
            const SizedBox(height: 6),
            _Side(label: loc.conflictTheirs, values: conflict.current),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onKeepServer,
                  child: Text(loc.conflictKeepTheirs),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onKeepMine,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  child: Text(loc.conflictKeepMine),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.label, required this.values});

  final String label;
  final List<String>? values;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            values == null
                ? AppLocalizations.of(context).conflictRowGone
                : values!.where((cell) => cell.trim().isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
