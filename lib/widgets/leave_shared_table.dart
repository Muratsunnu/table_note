import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../services/cloud_repository.dart';
import '../services/shared_sync_service.dart';

/// Kodla katılınmış bir tablodan ya da çeteleden ayrılma.
///
/// Katılınan tablo "silinmez", ondan ayrılınır: yalnızca cihazdan silmek
/// üyeliği sunucuda bırakır, kişi sahibin listesinde görünmeye devam eder ve
/// o tabloda kullandığı adı başkası alamaz. Bu yüzden silme yolları katılınan
/// tabloda buraya gelir.
///
/// Gönderilmemiş değişiklik varsa önce onlar gönderilir. Ayrılma başarılı
/// olursa tablo bu cihazdan kaldırılır ve bir bildirim gösterilir.
Future<void> leaveSharedTableFlow(
  BuildContext context, {
  required String tableId,
  required String tableName,
  required bool isTally,
  @visibleForTesting CloudRepository? repository,
}) async {
  final loc = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final left = await showDialog<bool>(
    context: context,
    builder: (_) => _LeaveDialog(
      tableId: tableId,
      tableName: tableName,
      isTally: isTally,
      repository: repository,
    ),
  );
  if (left != true) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(loc.leftShared(tableName))));
}

class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog({
    required this.tableId,
    required this.tableName,
    required this.isTally,
    this.repository,
  });

  final String tableId;
  final String tableName;
  final bool isTally;
  final CloudRepository? repository;

  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends State<_LeaveDialog> {
  bool _busy = false;
  String? _errorCode;

  /// Bekleyen değişiklikler gönderilemedi; kişi yine de ayrılmayı seçebilir.
  bool _sendFailed = false;

  Future<void> _leave() async {
    final tables = context.read<TableProvider>();
    final tallies = context.read<TallyProvider>();
    // Testlerde bu servis olmayabilir.
    final sync = context.read<SharedSyncService?>();
    final repository = widget.repository ?? CloudRepository();
    int pending() => widget.isTally
        ? tallies.pendingChangeCount(widget.tableId)
        : tables.pendingChangeCount(widget.tableId);
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      // Gönderilmemiş emek ayrılırken sessizce yok olmasın: önce gönderilir.
      // Gönderilemezse (çakışma, yetki alınmış, bağlantı yok) kişiye sorulur;
      // "yine de ayrıl" dediyse ikinci kez denenmez.
      if (pending() > 0 && !_sendFailed) {
        final sent = sync != null && await sync.push(widget.tableId);
        if (!sent || pending() > 0) {
          if (mounted) {
            setState(() {
              _busy = false;
              _sendFailed = true;
            });
          }
          return;
        }
      }
      // Önce sunucu: üyelik silinemediyse tablo cihazdan da kaldırılmaz,
      // yoksa kişi listede kalır ama tablosunu göremez.
      await repository.leaveSharedTable(widget.tableId);
      if (widget.isTally) {
        final index = tallies.tables.indexWhere((t) => t.id == widget.tableId);
        if (index >= 0) await tallies.deleteTable(index);
      } else {
        final index = tables.tables.indexWhere((t) => t.id == widget.tableId);
        if (index >= 0) await tables.deleteTable(index);
      }
      if (mounted) Navigator.pop(context, true);
    } on SharedTableException catch (error) {
      debugPrint('Paylaşımdan ayrılma: ${error.code}');
      if (mounted) {
        setState(() {
          _busy = false;
          _errorCode = error.isKnown ? error.code : 'unknown';
        });
      }
    } catch (error) {
      debugPrint('Paylaşımdan ayrılınamadı: $error');
      if (mounted) {
        setState(() {
          _busy = false;
          _errorCode = 'unknown';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final pending = widget.isTally
        ? context.watch<TallyProvider>().pendingChangeCount(widget.tableId)
        : context.watch<TableProvider>().pendingChangeCount(widget.tableId);
    return AlertDialog(
      title: Text(loc.leaveShared),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.leaveSharedConfirm(widget.tableName)),
          // Gönderilmemiş emek varsa kişi ne olacağını ayrılmadan önce bilir.
          if (_sendFailed) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                loc.leaveSendFailed,
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else if (pending > 0) ...[
            const SizedBox(height: 12),
            Text(loc.leavePendingWillSend(pending)),
          ],
          if (_errorCode != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                loc.sharedTableError(_errorCode!),
                style: TextStyle(color: colors.error),
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(loc.cancel),
        ),
        FilledButton(
          key: const ValueKey('leave-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: _busy ? null : _leave,
          child: Text(_sendFailed ? loc.leaveAnyway : loc.leaveAction),
        ),
      ],
    );
  }
}
