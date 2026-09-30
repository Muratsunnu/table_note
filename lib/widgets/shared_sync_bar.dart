import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/table_provider.dart';
import '../services/cloud_repository.dart';
import '../services/shared_sync_service.dart';

/// Ortak tablolarda gorunen senkron seridi. Siradan bir tabloda hicbir sey
/// cizmez, yani paylasim kullanmayan kullanici bunu hic gormez.
///
/// Iki rol iki farkli sey gorur: tabloyu paylasan kisi yalnizca durumu
/// ("kaydedildi" / "gonderiliyor"), katilan kisi ise bekleyen sayisini ve
/// "Buluta kaydet" butonunu.
class SharedSyncBar extends StatelessWidget {
  const SharedSyncBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tables = context.watch<TableProvider>();
    final table = tables.currentTable;
    if (table == null || !tables.isSharedTable(table.id)) {
      return const SizedBox.shrink();
    }

    final sync = context.watch<SharedSyncService>();
    final state = sync.stateFor(table.id);
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final pending = tables.pendingChangeCount(table.id);
    final isOwner = tables.isSharedOwner(table.id);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: state.hasConflicts
            ? colors.errorContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            state.hasConflicts
                ? Icons.merge_type_rounded
                : state.isSending
                ? Icons.cloud_sync_rounded
                : pending > 0
                ? Icons.cloud_upload_outlined
                : Icons.cloud_done_rounded,
            size: 20,
            color: state.hasConflicts
                ? colors.onErrorContainer
                : colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _label(loc, state, pending, isOwner),
              style: TextStyle(
                fontSize: 13,
                color: state.hasConflicts
                    ? colors.onErrorContainer
                    : colors.onSurfaceVariant,
              ),
            ),
          ),
          if (state.hasConflicts)
            TextButton(
              onPressed: () => _showConflicts(context, table.id),
              child: Text(loc.reviewConflicts),
            )
          // Sahip kendiliginden gonderir; butona yalnizca katilan basar.
          else if (!isOwner && pending > 0)
            FilledButton(
              onPressed: state.isSending
                  ? null
                  : () => context.read<SharedSyncService>().push(table.id),
              child: Text(loc.saveToCloud),
            ),
        ],
      ),
    );
  }

  String _label(
    AppLocalizations loc,
    SharedSyncState state,
    int pending,
    bool isOwner,
  ) {
    if (state.hasConflicts) return loc.conflictCount(state.conflicts.length);
    if (state.errorCode != null) return loc.sharedTableError(state.errorCode!);
    if (state.isSending) return loc.syncSending;
    if (pending > 0) {
      return isOwner ? loc.syncSending : loc.pendingChangeCount(pending);
    }
    return loc.syncUpToDate;
  }

  Future<void> _showConflicts(BuildContext context, String tableId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConflictSheet(tableId: tableId),
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
