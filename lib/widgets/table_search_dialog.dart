import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ux_localizations.dart';

class TableSearchDialog extends StatefulWidget {
  const TableSearchDialog({super.key, this.isTally = false});

  final bool isTally;

  @override
  State<TableSearchDialog> createState() => _TableSearchDialogState();
}

class _TableSearchDialogState extends State<TableSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.darkBlue, AppTheme.primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isTally
                          ? AppLocalizations.of(context).searchTally
                          : AppLocalizations.of(context).searchTable,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                    tooltip: AppLocalizations.of(context).close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Arama kutusu
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.isTally
                      ? AppLocalizations.of(context).typeTallyName
                      : AppLocalizations.of(context).typeTableName,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          tooltip: AppLocalizations.of(context).clear,
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),

            // Sonuçlar
            Expanded(
              child: Consumer2<TableProvider, TallyProvider>(
                builder: (context, provider, tallyProvider, child) {
                  final entries = _tableEntries(
                    context,
                    provider,
                    tallyProvider,
                  );
                  final filteredTables = entries.where((table) {
                    return table.tableName.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (entries.isEmpty) {
                    return _buildEmptyState(
                      icon: widget.isTally
                          ? Icons.grid_on_rounded
                          : Icons.table_chart_outlined,
                      title: widget.isTally
                          ? AppLocalizations.of(context).tallyEmptyTitle
                          : AppLocalizations.of(context).noTablesCreated,
                      subtitle: widget.isTally
                          ? AppLocalizations.of(context).tallyEmptySubtitle
                          : AppLocalizations.of(context).createYourFirst,
                    );
                  }

                  if (filteredTables.isEmpty && _searchQuery.isNotEmpty) {
                    return _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      title: AppLocalizations.of(context).noResults,
                      subtitle: AppLocalizations.of(
                        context,
                      ).noMatchingTable(_searchQuery),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredTables.length,
                    itemBuilder: (context, index) {
                      final table = filteredTables[index];
                      final originalIndex = table.index;
                      final isActive =
                          originalIndex ==
                          (widget.isTally
                              ? tallyProvider.currentIndex
                              : provider.currentTableIndex);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: isActive ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isActive
                              ? const BorderSide(
                                  color: AppTheme.primaryBlue,
                                  width: 2,
                                )
                              : BorderSide(
                                  color: Theme.of(context).dividerColor,
                                ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.isTally
                                  ? Icons.grid_on_rounded
                                  : Icons.table_chart_rounded,
                              color: isActive
                                  ? AppTheme.primaryBlue
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: _buildHighlightedText(
                            table.tableName,
                            _searchQuery,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              table.subtitle,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          trailing: isActive
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tintedSurface(
                                      context,
                                      AppTheme.success,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context).active,
                                    style: TextStyle(
                                      color: AppTheme.successForeground,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          onTap: () {
                            if (widget.isTally) {
                              tallyProvider.changeTable(originalIndex);
                            } else {
                              provider.changeTable(originalIndex);
                            }
                            Navigator.pop(context, true);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Alt bilgi
            Consumer2<TableProvider, TallyProvider>(
              builder: (context, provider, tallyProvider, child) {
                final entries = _tableEntries(context, provider, tallyProvider);
                final filteredCount = entries
                    .where(
                      (t) => t.tableName.toLowerCase().contains(_searchQuery),
                    )
                    .length;
                final totalCount = entries.length;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _searchQuery.isEmpty
                            ? AppLocalizations.of(
                                context,
                              ).totalNTables(totalCount)
                            : AppLocalizations.of(
                                context,
                              ).showingNofM(filteredCount, totalCount),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<({int index, String tableName, String subtitle})> _tableEntries(
    BuildContext context,
    TableProvider provider,
    TallyProvider tallyProvider,
  ) {
    final loc = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    if (widget.isTally) {
      return [
        for (final entry in tallyProvider.tables.asMap().entries)
          (
            index: entry.key,
            tableName: entry.value.tableName,
            subtitle:
                '${entry.value.items.length} ${loc.tallyItems} • '
                '${material.formatShortDate(entry.value.startDate)} – '
                '${material.formatShortDate(entry.value.endDate)}',
          ),
      ];
    }
    return [
      for (final entry in provider.tables.asMap().entries)
        (
          index: entry.key,
          tableName: entry.value.tableName,
          subtitle: loc.recordsAndColumns(
            entry.value.rows.length,
            entry.value.columns.length,
          ),
        ),
    ];
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // Arama sorgusunu vurgulayan text widget
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
    }

    final endIndex = startIndex + query.length;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              backgroundColor: Colors.yellow[300],
              color: Colors.black,
            ),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }
}
