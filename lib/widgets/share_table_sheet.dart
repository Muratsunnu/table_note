import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../screens/account_screen.dart';
import '../screens/premium_screen.dart';
import '../screens/shared_table_manage_screen.dart';
import '../services/cloud_repository.dart';
import '../services/shared_sync_service.dart';
import 'join_code_cells.dart';
import 'join_password_dialog.dart';

/// Tablo ya da çetele ekranından açılan paylaşım kâğıdı.
///
/// Kodu vermek isteyen kişi tabloya bakarken buna basar: tablo paylaşımda
/// değilse tek dokunuşla açılır, paylaşımdaysa kod karşısına çıkar. Eskiden
/// bunun için Ayarlar > Bulut Yedekleme'ye girip tabloyu yedeklemek, listede
/// bulup ayrı bir ekrandan paylaşmak gerekiyordu.
class ShareTableSheet extends StatefulWidget {
  const ShareTableSheet({
    super.key,
    required this.tableId,
    required this.isTally,
    this.repository,
  });

  final String tableId;
  final bool isTally;

  @visibleForTesting
  final CloudRepository? repository;

  static Future<void> show(
    BuildContext context, {
    required String tableId,
    required bool isTally,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ShareTableSheet(tableId: tableId, isTally: isTally),
  );

  @override
  State<ShareTableSheet> createState() => _ShareTableSheetState();
}

class _ShareTableSheetState extends State<ShareTableSheet> {
  late final CloudRepository _repository =
      widget.repository ?? CloudRepository();

  bool _busy = false;
  String? _errorCode;
  String? _notice;

  /// Sunucu "bu hesabın Premium'u yok" dedi. Uygulamanın bildiği ile
  /// sunucunun bildiği ayrışabilir: abonelik yeni bitmiş ya da önbellek eski
  /// olabilir. Son söz sunucunundur.
  bool _premiumRefused = false;

  /// Beklenmeyen hatanın ham hali; yalnızca geliştirme derlemesinde görünür.
  String? _errorDetail;

  /// Düzenleme yetkisi isteyip yanıt bekleyenler.
  List<SharedTableMember> _requests = const [];
  int? _seenPending;
  String? _code;

  /// Sunucuya kod soruldu mu? Sorulmadan "kod yok" denmez.
  bool _codeAsked = false;
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    // Zaten paylaşımdaki tabloda kod hemen okunur; kâğıt açıldığında
    // kullanıcının bir şeye daha basması gerekmesin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOwner(listen: false) && _canReachCloud()) _loadCode();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kâğıt açıkken yeni bir talep gelirse ya da biri yanıtlanırsa liste
    // kendiliğinden tazelenir. Testlerde bu servis olmayabilir.
    final pending = context
        .watch<SharedSyncService?>()
        ?.accessFor(widget.tableId)
        .pendingRequests;
    if (pending != null && pending != _seenPending) {
      final first = _seenPending == null;
      _seenPending = pending;
      // İlk yükleme zaten initState'te yapılıyor.
      if (!first && _isOwner(listen: false)) _loadRequests();
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  /// Talepler ayrı okunur: okunamamaları kodu göstermeye engel değildir.
  Future<void> _loadRequests() async {
    try {
      final members = await _repository.sharedTableMembers(widget.tableId);
      if (!mounted) return;
      setState(
        () => _requests = [
          for (final member in members)
            if (member.editRequestOpen) member,
        ],
      );
    } catch (error) {
      debugPrint('Yetki talepleri okunamadı: $error');
    }
  }

  Future<void> _answerRequest(SharedTableMember member, bool approve) {
    final sync = context.read<SharedSyncService?>();
    return _run(() async {
      await _repository.setSharedMemberRole(
        widget.tableId,
        member.userId,
        approve ? 'editor' : 'viewer',
      );
      await _loadRequests();
      unawaited(sync?.refreshAccess(widget.tableId));
    });
  }

  bool _isOwner({bool listen = true}) => widget.isTally
      ? Provider.of<TallyProvider>(
          context,
          listen: listen,
        ).isSharedOwner(widget.tableId)
      : Provider.of<TableProvider>(
          context,
          listen: listen,
        ).isSharedOwner(widget.tableId);

  bool _canReachCloud() {
    final auth = context.read<AuthProvider>();
    return auth.isAvailable &&
        auth.hasAccount &&
        context.read<SubscriptionProvider>().isPremium;
  }

  String? _tableName() {
    if (widget.isTally) {
      for (final tally in context.watch<TallyProvider>().tables) {
        if (tally.id == widget.tableId) return tally.tableName;
      }
      return null;
    }
    for (final table in context.watch<TableProvider>().tables) {
      if (table.id == widget.tableId) return table.tableName;
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _errorCode = null;
      _errorDetail = null;
      _notice = null;
    });
    try {
      await action();
    } on SharedTableException catch (error) {
      debugPrint('Paylaşım kâğıdı: ${error.code}');
      if (!mounted) return;
      setState(() {
        if (error.code == 'owner_premium_required') {
          _premiumRefused = true;
        } else if (error.isKnown) {
          _errorCode = error.code;
        } else {
          _errorCode = 'unknown';
          _errorDetail = error.code;
        }
      });
    } catch (error) {
      debugPrint('Paylaşım kâğıdı: $error');
      if (mounted) {
        setState(() {
          _errorCode = 'unknown';
          _errorDetail = '$error';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadCode() async {
    await _run(() async {
      final code = await _repository.sharedTableJoinCode(widget.tableId);
      if (!mounted) return;
      setState(() {
        _code = code;
        _codeAsked = true;
      });
    });
    if (mounted) await _loadRequests();
  }

  /// Tabloyu buluta koyar, kodu alır ve bu cihazı sahip olarak işaretler.
  /// Sağlayıcılar await'lerden önce yakalanır: ağ sürerken kâğıt kapatılırsa
  /// context geçersizleşir.
  Future<void> _start() {
    final tables = context.read<TableProvider>();
    final tallies = context.read<TallyProvider>();
    return _run(() async {
      final String code;
      if (widget.isTally) {
        code = await _repository.startSharing(
          tally: tallies.tables.firstWhere((t) => t.id == widget.tableId),
        );
        // Sahibin değişiklikleri bundan sonra kendiliğinden gitsin.
        await tallies.setSharedRole(widget.tableId, 'owner');
      } else {
        code = await _repository.startSharing(
          table: tables.tables.firstWhere((t) => t.id == widget.tableId),
        );
        await tables.setSharedRole(widget.tableId, 'owner');
      }
      if (!mounted) return;
      setState(() {
        _code = code;
        _codeAsked = true;
      });
    });
  }

  Future<void> _newCode() => _run(() async {
    final code = await _repository.rotateSharedTableCode(widget.tableId);
    if (!mounted) return;
    setState(() => _code = code);
  });

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code!));
    if (!mounted) return;
    // Alttaki ekranın bildirimi bu kâğıdın arkasında kalırdı; onay düğmenin
    // kendisinde görünür.
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _send(BuildContext buttonContext, String name) async {
    final loc = AppLocalizations.of(context);
    // iPad'de paylaşım penceresi bir noktaya bağlanmak zorunda.
    final box = buttonContext.findRenderObject() as RenderBox?;
    await Share.share(
      loc.shareCodeMessage(name, _code!),
      subject: name,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _setPassword() async {
    final loc = AppLocalizations.of(context);
    final value = await showJoinPasswordDialog(context);
    if (value == null || !mounted) return;
    await _run(() async {
      await _repository.setSharedTablePassword(widget.tableId, value);
      if (!mounted) return;
      setState(
        () => _notice = value.trim().isEmpty
            ? loc.passwordRemoved
            : loc.passwordSaved,
      );
    });
  }

  Future<void> _openManage(String name) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharedTableManageScreen(
          tableId: widget.tableId,
          tableName: name,
          collaborationEnabled: true,
          isTally: widget.isTally,
        ),
      ),
    );
    // Orada yeni kod üretilmiş ya da paylaşım kapatılmış olabilir.
    if (mounted && _isOwner(listen: false)) _loadCode();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final premium = context.watch<SubscriptionProvider>().isPremium;
    final name = _tableName();
    // Tablo kâğıt açıkken silindiyse gösterilecek bir şey kalmaz.
    if (name == null) return const SizedBox.shrink();
    final owner = _isOwner();

    final List<Widget> body;
    if (!premium || _premiumRefused) {
      body = _gate(
        icon: Icons.workspace_premium_rounded,
        title: loc.premiumRequired,
        message: loc.cloudPremiumMessage,
        button: loc.viewPremium,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PremiumScreen()),
          );
          // Premium alınmış olabilir; dönünce yeniden denenebilsin.
          if (mounted) setState(() => _premiumRefused = false);
        },
      );
      if (premium && kDebugMode) {
        body.add(
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Geliştirici notu: bu hesabın sunucuda Premium kaydı yok. '
              'Geliştirme derlemesi Premium\'u yalnızca uygulamanın içinde '
              'açık sayar; buluta yazmaya sunucu karar verir.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        );
      }
    } else if (!auth.isAvailable) {
      body = _gate(
        icon: Icons.cloud_off_rounded,
        title: loc.onlineServicesUnavailable,
        message: loc.onlineServicesUnavailableDescription,
      );
    } else if (!auth.hasAccount) {
      body = _gate(
        icon: Icons.person_rounded,
        title: loc.connectAccount,
        message: loc.shareNeedsAccount,
        button: loc.signIn,
        // Giriş yapılıp dönüldüğünde kâğıt hâlâ açıktır ve kaldığı yerden
        // devam eder.
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AccountScreen(closeOnSignIn: true),
          ),
        ),
      );
    } else if (!owner) {
      body = [
        Text(
          loc.shareExplainer,
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('share-start'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.key_rounded),
          label: Text(loc.startSharing),
        ),
      ];
    } else {
      body = [
        // Yanıt bekleyen talepler en üstte: sahibin burada yapması gereken
        // bir şey varsa önce onu görür.
        if (_requests.isNotEmpty) ...[
          Text(
            loc.editRequests,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          for (final member in _requests)
            ListTile(
              key: ValueKey('request-${member.userId}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_open_rounded, color: colors.primary),
              title: Text(member.displayName ?? '—'),
              subtitle: Text(loc.wantsEditAccess),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _answerRequest(member, false),
                    child: Text(loc.decline),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () => _answerRequest(member, true),
                    child: Text(loc.approve),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
        ],
        if (_code != null) ...[
          Semantics(
            // Ekran okuyucu "dört yüz altmış üç bin…" demesin, rakam rakam
            // okusun.
            label: '${loc.joinCode}: ${_code!.split('').join(' ')}',
            child: ExcludeSemantics(child: JoinCodeCells(code: _code!)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('share-copy'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _copy,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 18,
                  ),
                  label: Text(_copied ? loc.copied : loc.copy),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    key: const ValueKey('share-send'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _send(buttonContext, name),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(loc.shareSendCode),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            loc.shareHowToJoin,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
        ] else if (_codeAsked) ...[
          Text(
            loc.codeHiddenExplainer,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _busy ? null : _newCode,
            icon: const Icon(Icons.key_rounded),
            label: Text(loc.newCode),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(height: 24),
        ListTile(
          key: const ValueKey('share-password'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline_rounded),
          title: Text(loc.sharePassword),
          subtitle: Text(loc.sharePasswordHint),
          enabled: !_busy,
          onTap: _setPassword,
        ),
        ListTile(
          key: const ValueKey('share-manage'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.group_outlined),
          title: Text(loc.shareMembersHistory),
          trailing: const Icon(Icons.chevron_right_rounded),
          enabled: !_busy,
          onTap: () => _openManage(name),
        ),
      ];
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                widget.isTally
                    ? Icons.grid_on_rounded
                    : Icons.table_chart_rounded,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_busy) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 14),
          ],
          if (_errorCode != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                loc.sharedTableError(_errorCode!),
                style: TextStyle(color: colors.error, height: 1.4),
              ),
            ),
            if (kDebugMode && _errorDetail != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Geliştirici notu: $_errorDetail',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (_notice != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(_notice!, style: TextStyle(color: colors.primary)),
            ),
            const SizedBox(height: 12),
          ],
          ...body,
        ],
      ),
    );
  }

  /// Paylaşımın önündeki engel: Premium yok, hizmet kapalı ya da hesap yok.
  List<Widget> _gate({
    required IconData icon,
    required String title,
    required String message,
    String? button,
    VoidCallback? onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
      if (button != null) ...[
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: onPressed,
          child: Text(button),
        ),
      ],
    ];
  }
}
