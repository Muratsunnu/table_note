import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dil Ayarları
          Container(
            decoration: AppTheme.cardDecoration,
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
                          color: AppTheme.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.language_rounded,
                          color: AppTheme.primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        loc.language,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
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
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : AppTheme.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            flag,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.7)
              : AppTheme.textSecondary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppTheme.primaryBlue)
          : const Icon(Icons.circle_outlined, color: AppTheme.textSecondary),
      onTap: () {
        localeProvider.setLocale(locale);
      },
    );
  }
}
