import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tabel_model.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import 'edit_row_dialog.dart';

class TableListWidget extends StatelessWidget {
  const TableListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        final currentTable = provider.currentTable!;
        final displayRows = provider.filteredRows;
        final originalIndices = provider.isFiltering
            ? provider.filteredRowIndices
            : List.generate(currentTable.rows.length, (i) => i);

        if (displayRows.isEmpty) {
          return _buildEmptyState(provider);
        }

        return Column(
          children: [
            // Filtre bilgisi
            if (provider.isFiltering) _buildFilterInfo(context, provider),

            // Tablo
            Expanded(
              child: _buildDataTable(context, currentTable, displayRows, originalIndices, provider),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 18, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                children: [
                  const TextSpan(text: 'Filtre: '),
                  TextSpan(
                    text: '"${provider.searchQuery}"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: ' (${provider.filteredRowCount}/${provider.totalRowCount})',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => provider.clearSearch(),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 18, color: AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TableProvider provider) {
    if (provider.isFiltering) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sonuç bulunamadı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${provider.searchQuery}" ile eşleşen kayıt yok',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_rounded,
              size: 48,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tablo boş',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'İlk kaydınızı eklemek için\naşağıdaki butona dokunun',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.lightBlue),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkBlue,
                fontSize: 14,
              ),
              dataTextStyle: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              columnSpacing: 24,
              horizontalMargin: 16,
              dividerThickness: 1,
              columns: _buildColumns(currentTable),
              rows: _buildRows(context, currentTable, displayRows, originalIndices, provider),
            ),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns(TableModel table) {
    return [
      ...table.columns.map((col) {
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
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  col.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }),
      const DataColumn(
        label: Text(''),
      ),
    ];
  }

  List<DataRow> _buildRows(
    BuildContext context,
    TableModel table,
    List<List<String>> displayRows,
    List<int> originalIndices,
    TableProvider provider,
  ) {
    return displayRows.asMap().entries.map((entry) {
      final displayIndex = entry.key;
      final row = entry.value;
      final originalIndex = originalIndices[displayIndex];

      return DataRow(
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (displayIndex.isEven) return Colors.white;
          return AppTheme.background;
        }),
        cells: [
          ...row.asMap().entries.map((cellEntry) {
            final value = cellEntry.value;
            return DataCell(
              _buildCellContent(value, provider.searchQuery),
              onTap: () => _showEditDialog(context, originalIndex, row),
            );
          }),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppTheme.primaryBlue,
                  onPressed: () => _showEditDialog(context, originalIndex, row),
                  tooltip: 'Düzenle',
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppTheme.error,
                  onPressed: () => _showDeleteDialog(context, originalIndex, provider),
                  tooltip: 'Sil',
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildCellContent(String text, String searchQuery) {
    if (text.isEmpty) {
      return const Text(
        '-',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }

    if (searchQuery.isEmpty) {
      return Text(text);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(text);
    }

    final endIndex = startIndex + searchQuery.length;

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              backgroundColor: Colors.yellow[300],
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, int rowIndex, List<String> currentData) {
    showDialog(
      context: context,
      builder: (context) => EditRowDialog(
        rowIndex: rowIndex,
        currentData: currentData,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int rowIndex, TableProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Kaydı Sil'),
          ],
        ),
        content: const Text('Bu kaydı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await provider.deleteRow(rowIndex);
              Navigator.pop(context);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}