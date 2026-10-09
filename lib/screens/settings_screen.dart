import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/backup_reminder_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'cloud_backup_screen.dart';
import 'premium_screen.dart';
import 'home_widget_help_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final auth = context.watch<AuthProvider>();
    final subscription = context.watch<SubscriptionProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(loc.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF172554), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFBBF24),
                  size: 34,
                ),
                title: Text(
                  subscription.isPremium
                      ? loc.premiumActive
                      : loc.unlockPremium,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  // Deneme süresi mağazadan gelir; mağaza deneme vermiyorsa
                  // vaat de edilmez.
                  subscription.isPremium
                      ? loc.premiumActiveDescription
                      : switch (subscription.plans
                            .map((plan) => plan.trialDays)
                            .nonNulls
                            .firstOrNull) {
                          final days? => loc.trialBadge(days),
                          null => loc.premiumDescription,
                        },
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: AppTheme.cardDecorationFor(context),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.cloud_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(loc.cloudBackup),
                subtitle: Text(loc.cloudBackupSubtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudBackupScreen()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: AppTheme.cardDecorationFor(context),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(loc.account),
                subtitle: Text(auth.email ?? loc.noAccountConnected),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountScreen()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: AppTheme.cardDecorationFor(context),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.widgets_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  loc.locale.languageCode == 'en'
                      ? 'Home screen widget'
                      : 'Ana ekran widget’ı',
                ),
                subtitle: Text(
                  loc.locale.languageCode == 'en'
                      ? 'Table summaries and quick entry'
                      : 'Tablo özeti ve hızlı kayıt',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomeWidgetHelpScreen(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              loc.appearance,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              secondary: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                loc.darkTheme,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(loc.darkThemeDescription),
              value: themeProvider.isDarkMode,
              onChanged: themeProvider.setDarkMode,
            ),
          ),
          const SizedBox(height: 16),
          // Dil Ayarları
          Container(
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        loc.language,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _buildLanguageTile(
                  context: context,
                  title: loc.turkish,
                  subtitle: 'Türkçe',
                  locale: const Locale('tr'),
                  isSelected: localeProvider.isTurkish,
                  flag: '🇹🇷',
                  localeProvider: localeProvider,
                ),
                _buildLanguageTile(
                  context: context,
                  title: loc.english,
                  subtitle: 'English',
                  locale: const Locale('en'),
                  isSelected: localeProvider.isEnglish,
                  flag: '🇬🇧',
                  localeProvider: localeProvider,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Yalnızca geliştirme derlemesinde: ücretsiz kullanıcının gördüğünü
          // (sınırlar, Premium ekranı) denemek için.
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                key: const ValueKey('debug-free-user'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: const Text(
                  'Ücretsiz kullanıcı gibi göster',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Geliştirici ayarı; mağaza sürümünde görünmez. Uygulama '
                  'yeniden başlayınca kapanır.',
                ),
                value: subscription.debugFreeUser,
                onChanged: subscription.setDebugFreeUser,
              ),
            ),
            // Yedekleme hatırlatmalarını beklemeden görmek için: son yedeği
            // geriye alır. Giriş yapılmışsa çalışır.
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final (label, days) in const [
                    ('Son yedek: 4 gün önce', 4),
                    ('Son yedek: 8 gün önce', 8),
                    ('Yedek kaydını sil', null),
                  ])
                    OutlinedButton(
                      onPressed: auth.user == null
                          ? null
                          : () => context
                                .read<BackupReminderProvider>()
                                .debugSetDaysSinceBackup(auth.user!.id, days),
                      child: Text(label),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Locale locale,
    required bool isSelected,
    required String flag,
    required LocaleProvider localeProvider,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(flag, style: const TextStyle(fontSize: 22)),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          isSelected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: () {
          localeProvider.setLocale(locale);
        },
      ),
    );
  }
}
