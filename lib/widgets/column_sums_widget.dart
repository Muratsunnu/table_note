import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class ColumnSumsWidget extends StatelessWidget {
  const ColumnSumsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        if (!provider.hasTables) return const SizedBox();

        final sums = provider.calculateFilteredColumnSums();

        if (sums.isEmpty) return const SizedBox();

        final isFiltering = provider.isFiltering;
        final bgColor = AppTheme.tintedSurface(
          context,
          isFiltering ? AppTheme.warning : AppTheme.success,
        );
        final accentColor = isFiltering ? AppTheme.warning : AppTheme.success;
        final darkColor = Theme.of(context).brightness == Brightness.dark
            ? AppTheme.readableAccent(context, accentColor)
            : isFiltering
            ? const Color(0xFFE65100)
            : const Color(0xFF2E7D32);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isFiltering
                            ? Icons.filter_list_rounded
                            : Icons.functions_rounded,
                        color: darkColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFiltering
                                ? AppLocalizations.of(context).filteredTotals
                                : AppLocalizations.of(context).totals,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: darkColor,
                              fontSize: 14,
                            ),
                          ),
                          if (isFiltering)
                            Text(
                              AppLocalizations.of(
                                context,
                              ).searchOf(provider.searchLabel),
                              style: TextStyle(
                                color: darkColor.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFiltering
                            ? '${provider.filteredRowCount}/${provider.totalRowCount}'
                            : AppLocalizations.of(
                                context,
                              ).nRecords(provider.totalRowCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Toplamlar
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sums.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: darkColor.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatNumber(
                              entry.value,
                              Localizations.localeOf(context).languageCode ==
                                  'tr',
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: darkColor,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatNumber(double value, bool useTurkishSeparators) {
    if (!value.isFinite) return value.toString();
    final parts = value.toStringAsFixed(2).split('.');
    final grouping = useTurkishSeparators ? '.' : ',';
    final decimal = useTurkishSeparators ? ',' : '.';
    final integer = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}$grouping',
    );
    final fraction = parts.length > 1
        ? parts[1].replaceFirst(RegExp(r'0+$'), '')
        : '';
    return fraction.isEmpty ? integer : '$integer$decimal$fraction';
  }
}
