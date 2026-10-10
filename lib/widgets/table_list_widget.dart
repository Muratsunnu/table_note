import 'dart:math' as math;

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

  // Satırlar yalnızca ekrana geldikçe çizilir: binlerce satırlık tabloda da
  // açılış ve her değişiklik anlıktır. Hazır DataTable bütün satırları baştan
  // çizdiği için bin satırda saniyelerce takılıyordu.
  static const double _headingHeight = 56;
  static const double _rowHeight = 48;
  static const double _edgeMargin = 16;
  // İki sütun arasındaki boşluğun yarısı; komşu hücreyle birlikte 24 eder.
  static const double _cellGap = 12;
  static const double _sortArrowSpace = 18;
  static const double _actionButton = 40;

  Widget _buildDataTable(
    BuildContext context,
    TableModel currentTable,
    List<List<String>> displayRows,
    List<int> originalIndices,
    TableProvider provider,
  ) {
    final theme = Theme.of(context);
    final language = AppLocalizations.of(context).locale.languageCode;
    // Yalnızca görüntüleyen kişide satır düzenlenmez: dokunmak nedenini
    // söyler, düzenle ve sil düğmeleri de çizilmez.
    final canEdit = provider.canEditCurrent;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final rowHeight = _rowHeight * scale.clamp(1.0, 1.6);
    final headingHeight = _headingHeight * scale.clamp(1.0, 1.6);
    final cellStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(color: theme.colorScheme.onSurface, fontSize: 14);
    final headingStyle = cellStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onPrimaryContainer,
    );
    final natural = _columnWidths(
      context,
      currentTable,
      language: language,
      cellStyle: cellStyle,
      headingStyle: headingStyle,
    );
    final actionsWidth =
        _cellGap + (canEdit ? 2 * _actionButton : 0) + _edgeMargin;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
          builder: (context, constraints) {
            // Tablo ekrandan darsa ortada küçük kalmaz: artan yer sütunlara
            // eşit dağıtılır.
            final naturalTotal = natural.fold<double>(
              actionsWidth,
              (sum, width) => sum + width,
            );
            final extra =
                math.max(0.0, constraints.maxWidth - naturalTotal) /
                (natural.length + 1);
            final widths = [for (final width in natural) width + extra];
            final height = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : headingHeight + displayRows.length * rowHeight;

            return SingleChildScrollView(
              // Başka tabloya geçince liste en baştan başlar.
              key: ValueKey('table-${currentTable.id}'),
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: naturalTotal + extra * (natural.length + 1),
                height: height,
                child: DefaultTextStyle(
                  style: cellStyle,
                  child: Column(
                    children: [
                      _buildHeading(
                        context,
                        currentTable,
                        provider,
                        widths: widths,
                        height: headingHeight,
                        style: headingStyle,
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemExtent: rowHeight,
                          itemCount: displayRows.length,
                          itemBuilder: (context, displayIndex) => _buildRow(
                            context,
                            currentTable,
                            provider,
                            row: displayRows[displayIndex],
                            displayIndex: displayIndex,
                            originalIndex: originalIndices[displayIndex],
                            widths: widths,
                            actionsWidth: actionsWidth + extra,
                            language: language,
                            canEdit: canEdit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Her sütunun, başlığı ve en geniş hücresi sığacak genişliği.
  ///
  /// Bütün hücreleri ölçmek yerine sütun başına en uzun birkaç yazı ölçülür;
  /// yazı uzunluğu genişliğe çok yakın bir sıralama verir. Görünen satırlar
  /// değil tablonun tamamı hesaba katılır: arama yaparken sütunlar oynamaz.
  List<double> _columnWidths(
    BuildContext context,
    TableModel table, {
    required String language,
    required TextStyle cellStyle,
    required TextStyle headingStyle,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // Aramada eşleşen kısım kalın yazılır; genişlik buna göre ayrılır.
    final widest = cellStyle.copyWith(fontWeight: FontWeight.w600);
    const candidates = 6;

    return [
      for (var index = 0; index < table.columns.length; index++)
        () {
          final column = table.columns[index];
          final longest = <String>[];
          var shortest = 0;
          for (final row in table.rows) {
            if (index >= row.length) continue;
            final value = row[index];
            if (longest.length < candidates) {
              longest.add(value);
            } else if (value.length > longest[shortest].length) {
              longest[shortest] = value;
            } else {
              continue;
            }
            shortest = 0;
            for (var i = 1; i < longest.length; i++) {
              if (longest[i].length < longest[shortest].length) shortest = i;
            }
          }

          var content = measure('-', cellStyle);
          for (final value in longest) {
            if (value.isEmpty) continue;
            final shown = showsGroupedNumbers(column)
                ? (formatNumericCell(value, language: language) ?? value)
                : value;
            content = math.max(content, measure(shown, widest));
          }
          final heading =
              (_columnIcon(context, column) == null ? 0 : 22) +
              measure(column.name, headingStyle) +
              _sortArrowSpace;
          return (index == 0 ? _edgeMargin : _cellGap) +
              math.max(content, heading).ceilToDouble() +
              2 +
              _cellGap;
        }(),
    ];
  }

  /// Sütun türünü gösteren küçük simge ve rengi; düz yazı sütununda yoktur.
  (IconData, Color)? _columnIcon(BuildContext context, ColumnModel column) {
    if (column.isFormula) return (Icons.functions_rounded, AppTheme.formula);
    if (column.isConstant) return (Icons.push_pin_rounded, AppTheme.warning);
    if (column.isDate) return (Icons.calendar_today_rounded, AppTheme.teal);
    if (column.isTime) return (Icons.access_time_rounded, Colors.indigo);
    if (column.isAutoNumber) return (Icons.tag_rounded, AppTheme.brown);
    if (column.isNumeric) return (Icons.numbers_rounded, AppTheme.success);
    return null;
  }

  EdgeInsetsDirectional _cellPadding(int columnIndex) =>
      EdgeInsetsDirectional.only(
        start: columnIndex == 0 ? _edgeMargin : _cellGap,
        end: _cellGap,
      );

  /// Başlık satırı. Liste dikey kayarken yerinde kalır.
  Widget _buildHeading(
    BuildContext context,
    TableModel table,
    TableProvider provider, {
    required List<double> widths,
    required double height,
    required TextStyle style,
  }) {
    final colors = Theme.of(context).colorScheme;
    final sorted = provider.sortColumnIndex;
    return SizedBox(
      height: height,
      child: ColoredBox(
        color: colors.primaryContainer,
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            children: [
              for (var index = 0; index < table.columns.length; index++)
                SizedBox(
                  width: widths[index],
                  height: height,
                  child: InkWell(
                    // Üçüncü dokunuş sıralamayı kaldırır; yön provider'da
                    // yönetilir.
                    onTap: () => provider.toggleSort(index),
                    child: Padding(
                      padding: _cellPadding(index),
                      child: Row(
                        children: [
                          if (_columnIcon(context, table.columns[index]) case (
                            final icon,
                            final color,
                          )) ...[
                            Icon(
                              icon,
                              size: 16,
                              color: AppTheme.readableAccent(context, color),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              table.columns[index].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: style,
                            ),
                          ),
                          // Ok için yer hep ayrılır: sıralama açılıp
                          // kapanırken sütunlar oynamaz.
                          SizedBox(
                            width: _sortArrowSpace,
                            child: sorted == index
                                ? Icon(
                                    provider.sortAscending
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 16,
                                    color: style.color,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    TableModel table,
    TableProvider provider, {
    required List<String> row,
    required int displayIndex,
    required int originalIndex,
    required List<double> widths,
    required double actionsWidth,
    required String language,
    required bool canEdit,
  }) {
    final loc = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.tableRowColor(context, displayIndex),
        border: Border(bottom: Divider.createBorderSide(context, width: 1)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => canEdit
              ? _showEditDialog(context, originalIndex, row)
              : showViewOnlyNotice(context, tableId: table.id),
          child: Row(
            children: [
              for (var index = 0; index < table.columns.length; index++)
                SizedBox(
                  width: widths[index],
                  child: Padding(
                    padding: _cellPadding(index),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: () {
                        final value = index < row.length ? row[index] : '';
                        // Miktarlar okunaklı olsun diye ayraçlı gösterilir;
                        // düzenleme diyaloğuna her zaman ham satır gider.
                        final shown = showsGroupedNumbers(table.columns[index])
                            ? (formatNumericCell(value, language: language) ??
                                  value)
                            : value;
                        return _buildCellContent(
                          context,
                          shown,
                          // Arama bir sütuna sınırlıysa öteki sütunlarda
                          // eşleşme vurgulanmaz.
                          provider.searchTermFor(index),
                          raw: value,
                          language: language,
                        );
                      }(),
                    ),
                  ),
                ),
              SizedBox(
                width: actionsWidth,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: _cellGap,
                    end: _edgeMargin,
                  ),
                  child: canEdit
                      ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: AppTheme.primaryBlue,
                              onPressed: () =>
                                  _showEditDialog(context, originalIndex, row),
                              tooltip: loc.edit,
                              visualDensity: VisualDensity.compact,
                              splashRadius: 20,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                              color: AppTheme.error,
                              onPressed: () => _showDeleteDialog(
                                context,
                                originalIndex,
                                provider,
                              ),
                              tooltip: loc.delete,
                              visualDensity: VisualDensity.compact,
                              splashRadius: 20,
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    // Hücre sabit genişlikte: yazı alt satıra kaymaz, sığmazsa kısalır.
    Text plain() => Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    if (searchQuery.isEmpty) {
      return plain();
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
      return plain();
    }
    final (startIndex, endIndex) = span;

    return Text.rich(
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      TextSpan(
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
            // Pencere önce kapanır: ikinci bir dokunuş başka bir kaydı silemez.
            onPressed: () {
              Navigator.pop(context);
              provider.deleteRow(rowIndex);
            },
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
  }
}
