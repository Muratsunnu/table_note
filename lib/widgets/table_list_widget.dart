import 'edit_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tabel_model.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import '../utils/number_display.dart';
import 'edit_row_dialog.dart';
import '../l10n/app_localizations.dart';

class TableListWidget extends StatelessWidget {
  const TableListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        final currentTable = provider.currentTable;
        if (currentTable == null) return const SizedBox.shrink();
        // Arama ve sıralama birlikte uygulanır; kayıtlı satır sırası değişmez.
        final originalIndices = provider.visibleRowIndices;
        final displayRows = provider.visibleRows;

        return Column(
          children: [
            // Filtre bilgisi
            if (provider.isFiltering) _buildFilterInfo(context, provider),

            // Tablo
            Expanded(
              child: displayRows.isEmpty || currentTable.columns.isEmpty
                  ? _buildEmptyState(context, provider)
                  : _buildDataTable(
                      context,
                      currentTable,
                      displayRows,
                      originalIndices,
                      provider,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterInfo(BuildContext context, TableProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.tintedSurface(context, AppTheme.warning),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_list_rounded,
            size: 18,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(text: '${AppLocalizations.of(context).filter}: '),
                  TextSpan(
                    text: '"${provider.searchLabel}"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        ' (${provider.filteredRowCount}/${provider.totalRowCount})',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: provider.clearSearch,
            tooltip: AppLocalizations.of(context).closeSearch,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TableProvider provider) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                provider.isFiltering
                    ? Icons.search_off_rounded
                    : Icons.inbox_outlined,
                size: 40,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              provider.isFiltering ? loc.noResults : loc.tableEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.isFiltering
                  ? loc.noMatchingRecord(provider.searchLabel)
                  : loc.tapToAddFirst,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    TableModel currentTable,
    List<List<String>> displayRows,
    List<int> originalIndices,
    TableProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Tablo ekrandan darsa ortada küçük kalmaz, genişliği doldurur.
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.primaryContainer,
                  ),
                  headingTextStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 14,
                  ),
                  dataTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  dividerThickness: 1,
                  sortColumnIndex: provider.sortColumnIndex,
                  sortAscending: provider.sortAscending,
                  columns: _buildColumns(context, currentTable, provider),
                  rows: _buildRows(
                    context,
                    currentTable,
                    displayRows,
                    originalIndices,
                    provider,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns(
    BuildContext context,
    TableModel table,
    TableProvider provider,
  ) {
    return [
      ...table.columns.asMap().entries.map((columnEntry) {
        final columnIndex = columnEntry.key;
        final col = columnEntry.value;
        IconData? icon;
        Color? iconColor;

        if (col.isFormula) {
          icon = Icons.functions_rounded;
          iconColor = AppTheme.formula;
        } else if (col.isConstant) {
          icon = Icons.push_pin_rounded;
          iconColor = AppTheme.warning;
        } else if (col.isDate) {
          icon = Icons.calendar_today_rounded;
          iconColor = AppTheme.teal;
        } else if (col.isTime) {
          icon = Icons.access_time_rounded;
          iconColor = Colors.indigo;
        } else if (col.isAutoNumber) {
          icon = Icons.tag_rounded;
          iconColor = AppTheme.brown;
        } else if (col.isNumeric) {
          icon = Icons.numbers_rounded;
          iconColor = AppTheme.success;
        }

        return DataColumn(
          // Üçüncü dokunuş sıralamayı kaldırır; yön provider'da yönetilir.
          onSort: (tappedIndex, ascending) => provider.toggleSort(columnIndex),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: AppTheme.readableAccent(context, iconColor!),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(child: Text(col.name, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }),
      const DataColumn(label: Text('')),
    ];
  }

  List<DataRow> _buildRows(
    BuildContext context,
    TableModel table,
    List<List<String>> displayRows,
    List<int> originalIndices,
    TableProvider provider,
  ) {
    final language = AppLocalizations.of(context).locale.languageCode;
    // Yalnızca görüntüleyen kişide satır düzenlenmez: dokunmak nedenini
    // söyler, düzenle ve sil düğmeleri de çizilmez.
    final canEdit = provider.canEditCurrent;

    return displayRows.asMap().entries.map((entry) {
      final displayIndex = entry.key;
      final row = entry.value;
      final originalIndex = originalIndices[displayIndex];

      return DataRow(
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          return AppTheme.tableRowColor(context, displayIndex);
        }),
        cells: [
          ...List.generate(table.columns.length, (columnIndex) {
            final value = columnIndex < row.length ? row[columnIndex] : '';
            // Miktarlar okunaklı olsun diye ayraçlı gösterilir; düzenleme
            // diyaloğuna her zaman ham satır (`row`) gider.
            final shown = showsGroupedNumbers(table.columns[columnIndex])
                ? (formatNumericCell(value, language: language) ?? value)
                : value;
            return DataCell(
              _buildCellContent(
                context,
                shown,
                // Arama bir sütuna sınırlıysa öteki sütunlarda eşleşme
                // vurgulanmaz.
                provider.searchTermFor(columnIndex),
                raw: value,
                language: language,
              ),
              onTap: () => canEdit
                  ? _showEditDialog(context, originalIndex, row)
                  : showViewOnlyNotice(context, tableId: table.id),
            );
          }),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canEdit) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppTheme.primaryBlue,
                    onPressed: () =>
                        _showEditDialog(context, originalIndex, row),
                    tooltip: AppLocalizations.of(context).edit,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AppTheme.error,
                    onPressed: () =>
                        _showDeleteDialog(context, originalIndex, provider),
                    tooltip: AppLocalizations.of(context).delete,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildCellContent(
    BuildContext context,
    String text,
    String searchQuery, {
    required String raw,
    required String language,
  }) {
    if (text.isEmpty) {
      return Text(
        '-',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    if (searchQuery.isEmpty) {
      return Text(text);
    }

    // Someone looking for 35.000 types 35000, so the match is found in the
    // value as entered and then mapped onto the grouped text on screen.
    final span = highlightSpanIn(
      raw: raw,
      shown: text,
      query: searchQuery,
      language: language,
    );
    if (span == null) {
      return Text(text);
    }
    final (startIndex, endIndex) = span;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
        ),
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    int rowIndex,
    List<String> currentData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            EditRowDialog(rowIndex: rowIndex, currentData: currentData),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    int rowIndex,
    TableProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.delete_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.of(context).deleteRecord)),
          ],
        ),
        content: Text(AppLocalizations.of(context).deleteRecordConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await provider.deleteRow(rowIndex);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
  }
}
