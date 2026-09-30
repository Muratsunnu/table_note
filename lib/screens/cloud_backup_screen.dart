import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/tabel_model.dart';
import '../models/tally_model.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../services/cloud_repository.dart';
import '../l10n/app_localizations.dart';
import 'account_screen.dart';
import 'premium_screen.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  final _repository = CloudRepository();
  bool _loading = false;
  List<CloudEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!context.read<AuthProvider>().isSignedIn ||
        !context.read<SubscriptionProvider>().isPremium) {
      return;
    }
    await _run(() async => _entries = await _repository.list());
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.cloudOperationFailed)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _backup() async {
    final loc = AppLocalizations.of(context);
    await _run(() async {
      await _repository.backupTables(
        context.read<TableProvider>().tables,
        context.read<TallyProvider>().tables,
      );
      _entries = await _repository.list();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.backupComplete)));
      }
    });
  }

  Future<void> _restore(CloudEntry entry) async {
    final loc = AppLocalizations.of(context);
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.restoreTable),
        content: Text(loc.restoreChoiceDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.newCopy),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.overwrite),
          ),
        ],
      ),
    );
    if (overwrite == null || !mounted) return;
    final success = entry.kind == 'table'
        ? await context.read<TableProvider>().importCloudTable(
            TableModel.fromJson(entry.payload),
            overwrite: overwrite,
          )
        : await context.read<TallyProvider>().importCloudTable(
            TallyTableModel.fromJson(entry.payload),
            overwrite: overwrite,
          );
    if (mounted && success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.restoredToDevice)));
    }
  }

  Future<void> _share(CloudEntry entry) async {
    final loc = AppLocalizations.of(context);
    await _run(() async {
      final code = await _repository.createShareCode(entry.id);
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(loc.shareCode),
          content: SelectableText(loc.shareCodeValidity(code)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(loc.ok),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _claim() async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.addSharedTable),
        content: TextField(
          controller: controller,
          autocorrect: false,
          decoration: InputDecoration(labelText: loc.shareCode),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(loc.add),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;
    await _run(() async {
      await _repository.claimShareCode(code);
      _entries = await _repository.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final subscription = context.watch<SubscriptionProvider>();
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.cloudBackup)),
      body: !subscription.isPremium
          ? _AccessCard(
              icon: Icons.workspace_premium_rounded,
              title: loc.premiumRequired,
              message: loc.cloudPremiumMessage,
              button: loc.viewPremium,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
            )
          : !auth.isAvailable
          ? _AccessCard(
              icon: Icons.cloud_off_rounded,
              title: loc.onlineServicesUnavailable,
              message: loc.onlineServicesUnavailableDescription,
            )
          : !auth.isSignedIn
          ? _AccessCard(
              icon: Icons.person_rounded,
              title: loc.connectAccount,
              message: loc.connectAccountMessage,
              button: loc.signIn,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountScreen()),
                );
                if (mounted) _refresh();
              },
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _backup,
                          icon: const Icon(Icons.cloud_upload_rounded),
                          label: Text(loc.backupNow),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _loading ? null : _claim,
                        icon: const Icon(Icons.group_add_rounded),
                        tooltip: loc.addShareCodeTooltip,
                      ),
                    ],
                  ),
                ),
                if (_loading) const LinearProgressIndicator(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: _entries.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              const Icon(Icons.cloud_off_rounded, size: 52),
                              const SizedBox(height: 12),
                              Center(child: Text(loc.noCloudBackup)),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              final owned = entry.ownerId == auth.user?.id;
                              return Card(
                                child: ListTile(
                                  leading: Icon(
                                    entry.kind == 'table'
                                        ? Icons.table_chart_rounded
                                        : Icons.grid_on_rounded,
                                  ),
                                  title: Text(entry.name),
                                  subtitle: Text(
                                    owned ? loc.myBackup : loc.sharedWithMe,
                                  ),
                                  onTap: () => _restore(entry),
                                  trailing: owned
                                      ? IconButton(
                                          onPressed: () => _share(entry),
                                          icon: const Icon(Icons.share_rounded),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? button;
  final VoidCallback? onPressed;

  const _AccessCard({
    required this.icon,
    required this.title,
    required this.message,
    this.button,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 60),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (button != null)
            FilledButton(onPressed: onPressed, child: Text(button!)),
        ],
      ),
    ),
  );
}
