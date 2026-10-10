import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../services/cloud_repository.dart';
import '../services/shared_sync_service.dart';
import '../widgets/join_password_dialog.dart';
import '../widgets/table_activity_list.dart';

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
    required this.isTally,
  });

  final String tableId;
  final String tableName;
  final bool collaborationEnabled;

  /// Rol dogru saglayiciya yazilsin diye gerekiyor. Yanlis saglayiciya
  /// yazilsaydi kayit olusur ama o tur kendini hic "ortak" saymazdi:
  /// gosterge cikmaz, otomatik gonderim calismazdi.
  final bool isTally;

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
    // Kod da her acilista okunur. Eskiden yalnizca uretildigi an
    // gorulebiliyordu; kodunu hatirlamayan kullanicinin tek caresi yeni kod
    // uretmekti, o da eskisini gecersiz kiliyordu.
    final code = await _repository.sharedTableJoinCode(widget.tableId);
    final members = await _repository.sharedTableMembers(widget.tableId);
    final activity = await _repository.tableActivity(widget.tableId);
    if (!mounted) return;
    setState(() {
      if (code != null) _code = code;
      _members = members;
      _activity = activity;
    });
  });

  /// Rolu dogru saglayiciya yazar. Saglayicilar await'lerden ONCE yakalanir:
  /// kod uretimi ag uzerinden surerken kullanici geri donerse bu ekranin
  /// context'i gecersizlesir ve sonrasinda context.read cokmeye yol acardi.
  Future<void> Function(String?) _roleWriter() {
    if (widget.isTally) {
      final tallies = context.read<TallyProvider>();
      return (role) => tallies.setSharedRole(widget.tableId, role);
    }
    final tables = context.read<TableProvider>();
    return (role) => tables.setSharedRole(widget.tableId, role);
  }

  Future<void> _generateCode() {
    final setRole = _roleWriter();
    return _run(() async {
      final code = await _repository.rotateSharedTableCode(widget.tableId);
      // Sahibin kendi degisiklikleri bundan sonra kendiliginden gitsin diye
      // kayit yerelde 'owner' olarak isaretlenir.
      await setRole('owner');
      if (!mounted) return;
      setState(() {
        _code = code;
        _enabled = true;
      });
      await _refresh();
    });
  }

  /// Sahip bir üyenin rolünü belirler. Aynı rolü yeniden vermek o üyenin
  /// açık talebini kapatır; "reddet" budur.
  Future<void> _setRole(SharedTableMember member, String role) {
    // Rozet ve üyenin kendi ekranı bu servisten beslenir.
    final sync = context.read<SharedSyncService>();
    return _run(() async {
      await _repository.setSharedMemberRole(
        widget.tableId,
        member.userId,
        role,
      );
      final members = await _repository.sharedTableMembers(widget.tableId);
      if (mounted) setState(() => _members = members);
      unawaited(sync.refreshAccess(widget.tableId));
    });
  }

  Future<void> _disable() {
    final setRole = _roleWriter();
    return _run(() async {
      await _repository.disableSharedTableCollaboration(widget.tableId);
      await setRole(null);
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
    final value = await showJoinPasswordDialog(context);
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
                if (member.editRequestOpen)
                  // Yanıt bekleyen talep: onayla ya da reddet.
                  ListTile(
                    key: ValueKey('member-${member.userId}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.lock_open_rounded,
                      color: colors.primary,
                    ),
                    title: Text(member.displayName ?? '—'),
                    subtitle: Text(
                      loc.wantsEditAccess,
                      style: TextStyle(color: colors.primary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _setRole(member, 'viewer'),
                          child: Text(loc.decline),
                        ),
                        FilledButton.tonal(
                          onPressed: _busy
                              ? null
                              : () => _setRole(member, 'editor'),
                          child: Text(loc.approve),
                        ),
                      ],
                    ),
                  )
                else
                  // Anahtar açıkken kişi düzenleyebilir; sahip dilediği
                  // zaman verir ya da geri alır.
                  SwitchListTile(
                    key: ValueKey('member-${member.userId}'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.person_outline_rounded),
                    title: Text(member.displayName ?? '—'),
                    subtitle: Text(
                      '${loc.roleLabel(member.role)} · '
                      '${_date(member.joinedAt)}',
                    ),
                    value: member.canEdit,
                    onChanged: _busy
                        ? null
                        : (canEdit) =>
                              _setRole(member, canEdit ? 'editor' : 'viewer'),
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
              TableActivityList(entries: _activity, selfActorId: selfActorId),
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
