import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/backup_reminder_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../screens/cloud_backup_screen.dart';
import '../theme/app_theme.dart';

/// Bu kullanıcı için şu an hangi yedekleme hatırlatması gösterilmeli.
///
/// Hatırlatma yalnızca yedekleyebilen kişiye (giriş yapmış Premium) ve
/// yedeklenmemiş bir değişiklik varsa çıkar.
BackupStatus backupStatusOf(BuildContext context) {
  final reminder = context.watch<BackupReminderProvider?>();
  final auth = context.watch<AuthProvider?>();
  final subscription = context.watch<SubscriptionProvider?>();
  if (reminder == null || auth == null || subscription == null) {
    return BackupStatus.none;
  }
  final tables = context.watch<TableProvider?>();
  final tallies = context.watch<TallyProvider?>();

  DateTime? latest;
  void consider(DateTime changed) {
    if (latest == null || changed.isAfter(latest!)) latest = changed;
  }

  // Paylaşılan tablolar sürekli eşitlenir; elle yedekleme onları kapsamaz.
  if (tables != null) {
    for (final table in tables.tables) {
      if (!tables.isSharedTable(table.id)) consider(table.updatedAt);
    }
  }
  if (tallies != null) {
    for (final tally in tallies.tables) {
      if (!tallies.isSharedTally(tally.id)) consider(tally.updatedAt);
    }
  }

  return reminder.statusFor(
    userId: auth.user?.id,
    canBackUp: auth.hasAccount && subscription.isPremium,
    latestChange: latest,
  );
}

void _openBackupScreen(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CloudBackupScreen()),
  );
}

/// Yedekleme uzun süre yapılmadığında tablo ve çetele ekranının üstüne inen
/// kart. "Şimdi yedekle" yedekleme ekranını açar; yedeği kullanıcı kendi
/// eliyle alır. "Sonra" denirse bugün bir daha çıkmaz, yarın yeniden gelir.
class BackupReminderCard extends StatelessWidget {
  const BackupReminderCard({super.key, this.onBackUp});

  /// Verilmezse yedekleme ekranı açılır.
  final VoidCallback? onBackUp;

  @override
  Widget build(BuildContext context) {
    final status = backupStatusOf(context);
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: status.nudge == BackupNudge.card
          ? _card(context, status)
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _card(BuildContext context, BackupStatus status) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final days = status.days;
    return Container(
      key: const ValueKey('backup-reminder'),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      decoration: BoxDecoration(
        color: AppTheme.tintedSurface(context, colors.primary),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.cloud_upload_outlined,
              size: 22,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    days == null
                        ? loc.backupReminderNever
                        : loc.backupReminderDays(days),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        key: const ValueKey('backup-reminder-later'),
                        onPressed: () =>
                            context.read<BackupReminderProvider>().snooze(),
                        child: Text(loc.backupLater),
                      ),
                      FilledButton.tonal(
                        key: const ValueKey('backup-reminder-now'),
                        onPressed: onBackUp ?? () => _openBackupScreen(context),
                        child: Text(loc.backupNow),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Başlığın altındaki küçük "Son yedekleme: 3 gün önce" satırı. Dokununca
/// yedekleme ekranını açar. Hatırlatacak bir şey yoksa hiç yer kaplamaz.
class BackupStatusLine extends StatelessWidget {
  const BackupStatusLine({super.key, this.onTap});

  /// Verilmezse yedekleme ekranı açılır.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = backupStatusOf(context);
    if (status.nudge != BackupNudge.line) return const SizedBox.shrink();
    final ink = AppTheme.readableAccent(context, AppTheme.warning);
    return InkWell(
      key: const ValueKey('backup-status-line'),
      borderRadius: BorderRadius.circular(6),
      onTap: onTap ?? () => _openBackupScreen(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_upload_outlined, size: 14, color: ink),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                AppLocalizations.of(context).lastBackupLabel(status.days),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
