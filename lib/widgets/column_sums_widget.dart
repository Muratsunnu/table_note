import 'package:flutter/material.dart';
import 'compact_layout.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/column_balance.dart';
import 'starting_value_field.dart';

class ColumnSumsWidget extends StatelessWidget {
  const ColumnSumsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        if (!provider.hasTables) return const SizedBox();

        final sums = provider.calculateFilteredColumnSums();

        if (sums.isEmpty) return const SizedBox();
        // Başlangıç değeri verilmiş sütunların kalanı; toplamların yanında.
        final balances = provider.columnBalances;

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

        // Yüksekliği dar ekranda tek satır: toplamlar yana kayar.
        if (isCompactHeight(context)) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isFiltering
                      ? Icons.filter_list_rounded
                      : Icons.functions_rounded,
                  color: darkColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in sums.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _sumChip(
                              context,
                              entry,
                              accentColor,
                              darkColor,
                            ),
                          ),
                        for (final balance in balances)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _remainingChip(context, provider, balance),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

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
                  children: [
                    for (final entry in sums.entries)
                      _sumChip(context, entry, accentColor, darkColor),
                    for (final balance in balances)
                      _remainingChip(context, provider, balance),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sumChip(
    BuildContext context,
    MapEntry<String, double> entry,
    Color accentColor,
    Color darkColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Uzun sütun adı kutunun dışına taşmaz, kısalır.
          Flexible(
            child: Text(
              entry.key,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: darkColor.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatNumber(
              entry.value,
              Localizations.localeOf(context).languageCode == 'tr',
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
  }

  /// "harcama · kalan 62.500". Aşıldıysa kırmızıya döner ve eksiye geçer:
  /// "harcama · kalan -1.050". Sütunları değiştirebilen kişi dokunarak
  /// başlangıç değerini günceller.
  Widget _remainingChip(
    BuildContext context,
    TableProvider provider,
    ColumnBalance balance,
  ) {
    final loc = AppLocalizations.of(context);
    final ink = AppTheme.readableAccent(
      context,
      balance.isExceeded ? AppTheme.error : AppTheme.primaryBlue,
    );
    final editable = provider.canEditStructure;
    final label = loc.remainingOf(balance.name);
    return Material(
      color: AppTheme.tintedSurface(
        context,
        balance.isExceeded ? AppTheme.error : AppTheme.primaryBlue,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: ink.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('remaining-${balance.columnIndex}'),
        onTap: editable
            ? () => showStartingValueDialog(context, balance)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  // Arama yaparken de tablonun tamamına bakar; bunu söyler.
                  provider.isFiltering
                      ? '$label (${loc.wholeTableNote})'
                      : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ink, fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatNumber(
                  balance.remaining,
                  Localizations.localeOf(context).languageCode == 'tr',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ink,
                  fontSize: 15,
                ),
              ),
              if (editable) ...[
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 14, color: ink),
              ],
            ],
          ),
        ),
      ),
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
