import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../services/cloud_repository.dart';

/// Tabloyu paylasan kisinin yonetim ekrani: kod uretme, istege bagli sifre,
/// kimlerin katildigi ve degisiklik gecmisi.
///
/// Gecmisi yalnizca bu ekran gosterir, cunku yalnizca sahip okuyabilir;
/// katilan kisi ayni tabloya baksa bile sunucu ona bos liste doner.
class SharedTableManageScreen extends StatefulWidget {
  const SharedTableManageScreen({
    super.key,
    required this.tableId,
    required this.tableName,
    required this.collaborationEnabled,
  });

  final String tableId;
  final String tableName;
  final bool collaborationEnabled;

  @override
  State<SharedTableManageScreen> createState() =>
      _SharedTableManageScreenState();
}

class _SharedTableManageScreenState extends State<SharedTableManageScreen> {
  final _repository = CloudRepository();

  bool _busy = false;
  String? _errorCode;
  String? _code;
  late bool _enabled = widget.collaborationEnabled;
  List<SharedTableMember> _members = const [];
  List<TableActivityEntry> _activity = const [];

  @override
  void initState() {
    super.initState();
    if (_enabled) _refresh();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await action();
    } on SharedTableException catch (error) {
      if (mounted) {
        setState(() => _errorCode = error.isKnown ? error.code : 'unknown');
      }
    } catch (error) {
      debugPrint('Ortak tablo yonetimi: $error');
      if (mounted) setState(() => _errorCode = 'unknown');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() => _run(() async {
    final members = await _repository.sharedTableMembers(widget.tableId);
    final activity = await _repository.tableActivity(widget.tableId);
    if (!mounted) return;
    setState(() {
      _members = members;
      _activity = activity;
    });
  });

  Future<void> _generateCode() {
    // Saglayici await'lerden ONCE yakalanir. Kod uretimi ag uzerinden
    // surerken kullanici geri donerse bu ekranin context'i gecersizlesir;
    // sonrasinda context.read cagirmak cokmeye yol acardi.
    final tables = context.read<TableProvider>();
    return _run(() async {
      final code = await _repository.rotateSharedTableCode(widget.tableId);
      // Sahibin kendi degisiklikleri bundan sonra kendiliginden gitsin diye
      // tablo yerelde 'owner' olarak isaretlenir.
      await tables.setSharedRole(widget.tableId, 'owner');
      if (!mounted) return;
      setState(() {
        _code = code;
        _enabled = true;
      });
      await _refresh();
    });
  }

  Future<void> _disable() {
    final tables = context.read<TableProvider>();
    return _run(() async {
      await _repository.disableSharedTableCollaboration(widget.tableId);
      await tables.setSharedRole(widget.tableId, null);
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _code = null;
        _members = const [];
      });
    });
  }

  Future<void> _setPassword() async {
    final loc = AppLocalizations.of(context);
    // Denetleyici degil duz degisken: showDialog, kapanma animasyonu
    // bitmeden doner. Denetleyiciyi doner donmez dispose etmek, hala agacta
    // duran TextField yuzunden '_dependents.isEmpty' iddiasini patlatiyordu.
    // Animasyonun bitmesini beklemek yerine dispose edilecek nesneyi ortadan
    // kaldirmak, zamanlamaya bagli kalmayan tek cozum.
    var typed = '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.joinPassword),
        content: TextField(
          autofocus: true,
          onChanged: (text) => typed = text,
          onSubmitted: (text) => Navigator.pop(dialogContext, text),
          decoration: InputDecoration(
            labelText: loc.joinPasswordOptional,
            // Ipucu tek satira sigmayip ortasindan kesiliyordu.
            helperText: loc.joinPasswordHint,
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, typed),
            child: Text(loc.save),
          ),
        ],
      ),
    );
    if (value == null) return;
    await _run(() async {
      await _repository.setSharedTablePassword(widget.tableId, value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value.trim().isEmpty ? loc.passwordRemoved : loc.passwordSaved,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final selfActorId = context.watch<AuthProvider>().user?.id;
    return Scaffold(
      appBar: AppBar(title: Text(widget.tableName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_errorCode != null) ...[
            Text(
              loc.sharedTableError(_errorCode!),
              style: TextStyle(color: colors.error),
            ),
            const SizedBox(height: 16),
          ],
          if (_code != null) ...[
            _CodeCard(code: _code!),
            const SizedBox(height: 16),
          ] else if (_enabled) ...[
            Text(
              loc.codeHiddenExplainer,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(
              loc.shareExplainer,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _generateCode,
            icon: const Icon(Icons.key_rounded),
            label: Text(_enabled ? loc.newCode : loc.startSharing),
          ),
          if (_enabled) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _setPassword,
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text(loc.joinPassword),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _disable,
              icon: const Icon(Icons.link_off_rounded),
              label: Text(loc.stopSharing),
              style: TextButton.styleFrom(foregroundColor: colors.error),
            ),
            const SizedBox(height: 24),
            Text(
              loc.sharedTableMembers,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_members.isEmpty)
              Text(
                loc.noMembersYet,
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              for (final member in _members)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(member.displayName ?? '—'),
                  subtitle: Text(_date(member.joinedAt)),
                ),
            const SizedBox(height: 24),
            Text(
              loc.activityLog,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              loc.activityLogOwnerOnly,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (_activity.isEmpty)
              Text(
                loc.noActivityYet,
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              for (final entry in _activity)
                _ActivityRow(entry: entry, selfActorId: selfActorId),
          ],
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

/// Kod buyuk ve okunakli; telefonda soylenmek icin var.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            loc.joinCode,
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
          const SizedBox(height: 8),
          SelectableText(
            code,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(loc.copied)));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(loc.copy),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.selfActorId});

  final TableActivityEntry entry;

  /// Gunlugu okuyan kisinin kimligi. Bu gunlugu yalnizca tablo sahibi
  /// gordugu icin kendi satirlarini adiyla degil "Sen" diye gostermek hem
  /// daha anlasilir hem de profilde ad olup olmamasindan bagimsiz.
  final String? selfActorId;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final detail = switch (entry.action) {
      'joined' => loc.activityJoined,
      'row_added' => loc.activityRowAdded,
      'row_deleted' => loc.activityRowDeleted,
      'row_updated' =>
        '${entry.columnName}: '
            '${_orDash(entry.oldValue)} → ${_orDash(entry.newValue)}',
      _ => entry.action,
    };
    final isSelf = entry.actorId != null && entry.actorId == selfActorId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              _SharedTableManageScreenState._date(entry.createdAt),
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelf ? loc.activityActorSelf : entry.actorName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(detail, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;
}
