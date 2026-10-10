import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/subscription_provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ledger.dart';
import '../widgets/share_table_sheet.dart';
import '../widgets/voice_add_row_dialog.dart';
import 'cloud_backup_screen.dart';

/// Satın alma tamamlandığı an açılan ekran: teşekkür, ne zamana kadar geçerli
/// olduğu ve az önce açılan özelliklere kısa yollar. Kısa yollar bu ekranın
/// üstünde açılır; kişi dönünce bir başkasını deneyebilir.
class PremiumWelcomeScreen extends StatelessWidget {
  const PremiumWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final validUntil = context.watch<SubscriptionProvider>().validUntil;
    final tables = context.watch<TableProvider?>();
    final tallies = context.watch<TallyProvider?>();
    final table = tables?.currentTable;
    final tally = tallies?.currentTable;
    // Paylaşılacak ya da sesle doldurulacak bir tablo yoksa o kısa yol çizilmez.
    final shareId = table?.id ?? tally?.id;
    final canFillByVoice = table != null && table.columns.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: _Badge()),
                    const SizedBox(height: 20),
                    Text(
                      loc.premiumWelcomeTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.premiumWelcomeBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (validUntil != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        loc.premiumValidUntil(
                          MaterialLocalizations.of(
                            context,
                          ).formatShortDate(validUntil.toLocal()),
                        ),
                        key: const ValueKey('premium-valid-until'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      loc.premiumWelcomeNext,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LedgerCard(
                      children: [
                        _Shortcut(
                          key: const ValueKey('welcome-backup'),
                          icon: Icons.cloud_upload_outlined,
                          title: loc.welcomeBackup,
                          hint: loc.welcomeBackupHint,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CloudBackupScreen(),
                            ),
                          ),
                        ),
                        if (shareId != null)
                          _Shortcut(
                            key: const ValueKey('welcome-share'),
                            icon: Icons.group_add_outlined,
                            title: loc.welcomeShare,
                            hint: loc.welcomeShareHint,
                            onTap: () => ShareTableSheet.show(
                              context,
                              tableId: shareId,
                              isTally: table == null,
                            ),
                          ),
                        if (canFillByVoice)
                          _Shortcut(
                            key: const ValueKey('welcome-voice'),
                            icon: Icons.mic_none_rounded,
                            title: loc.welcomeVoice,
                            hint: loc.welcomeVoiceHint,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => const VoiceAddRowDialog(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('welcome-close'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.welcomeClose),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onay işareti; ekran açılırken bir kez büyüyerek belirir.
class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.tintedSurface(context, AppTheme.success),
      ),
      child: Icon(
        Icons.check_rounded,
        size: 48,
        color: AppTheme.readableAccent(context, AppTheme.success),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return badge;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: badge,
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
