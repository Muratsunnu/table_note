import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/table_provider.dart';
import '../utils/quick_options.dart';

/// Bir sütunun hızlı seçim çipleri: dokununca alanı doldurur, yanındaki ×
/// seçeneği kaldırır. Seçenekler tabloya sık girilen değerlerden gelir
/// ([TableProvider.quickOptions]).
class QuickOptionChips extends StatelessWidget {
  const QuickOptionChips({
    super.key,
    required this.columnIndex,
    required this.selected,
    required this.onSelected,
  });

  final int columnIndex;

  /// Alanda şu an yazan değer; eşleşen çip seçili görünür.
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tables = context.watch<TableProvider>();
    final options = tables.quickOptions(columnIndex);
    if (options.isEmpty) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    // Alanda farklı harflerle yazılmış olsa da aynı çip seçili görünür.
    final current = quickOptionKey(selected);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final option in options)
            InputChip(
              key: ValueKey('quick-option-$columnIndex-$option'),
              label: Text(option),
              selected: quickOptionKey(option) == current,
              showCheckmark: false,
              selectedColor: colors.primaryContainer,
              labelStyle: TextStyle(
                color: quickOptionKey(option) == current
                    ? colors.onPrimaryContainer
                    : colors.onSurface,
              ),
              onPressed: () => onSelected(option),
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
              deleteButtonTooltipMessage: loc.quickOptionRemove,
              onDeleted: () => tables.dismissQuickOption(columnIndex, option),
            ),
        ],
      ),
    );
  }
}
