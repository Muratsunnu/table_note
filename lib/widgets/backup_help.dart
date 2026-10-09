import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'ledger.dart';

/// Yedeklemenin ne olduğunu birkaç kısa satırda anlatan alt kâğıt.
Future<void> showBackupHelp(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final loc = AppLocalizations.of(sheetContext);
      final theme = Theme.of(sheetContext);
      final points = [
        (Icons.cloud_done_outlined, loc.backupHelpWhat),
        (Icons.settings_backup_restore_rounded, loc.backupHelpRestore),
        (Icons.touch_app_outlined, loc.backupHelpManual),
        (Icons.group_outlined, loc.backupHelpShared),
      ];
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.whatIsBackup,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              LedgerCard(
                children: [
                  for (final (icon, text) in points)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              text,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(loc.understood),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// "Yedekleme nedir?" bağlantısı; dokununca açıklamayı açar.
class BackupHelpLink extends StatelessWidget {
  const BackupHelpLink({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('backup-help'),
      onPressed: () => showBackupHelp(context),
      icon: const Icon(Icons.help_outline_rounded, size: 18),
      label: Text(AppLocalizations.of(context).whatIsBackup),
    );
  }
}
