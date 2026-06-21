import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/table_list_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/add_row_dialog.dart';
import '../widgets/template_management_dialog.dart';
import '../widgets/column_sums_widget.dart';
import '../widgets/table_search_dialog.dart';
import '../widgets/export_dialog.dart';
import '../widgets/table_drawer.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../l10n/app_localizations.dart';
import 'tally_screen.dart';

class TableScreen extends StatefulWidget {
  @override
  _TableScreenState createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadLastTab();
  }

  Future<void> _loadLastTab() async {
    final tab = await StorageService.loadLastActiveTab();
    if (mounted) setState(() => _currentTab = tab);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: _currentTab == 0 ? _buildTableAppBar() : _buildTallyAppBar(),
      drawer: TableDrawer(onTabChanged: (tab) {
        setState(() => _currentTab = tab);
        StorageService.saveLastActiveTab(tab);
      }),
      body: _currentTab == 0 ? _buildTableBody() : const TallyScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() => _currentTab = index);
          StorageService.saveLastActiveTab(index);
        },
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.textSecondary,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.table_chart_rounded),
            label: loc.tableNote,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.grid_on_rounded),
            label: loc.tallyTab,
          ),
        ],
      ),
    );
  }

  // ============== TABLO TAB ==============

  Widget _buildTableBody() {
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!provider.hasTables) {
          return const EmptyStateWidget();
        }
        return Column(
          children: [
            _buildTableHeader(provider),
            _buildSearchBar(provider),
            Expanded(child: TableListWidget()),
            const ColumnSumsWidget(),
            _buildAddRowButton(),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildTableAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: AppLocalizations.of(context).menu,
      ),
      title: Text(AppLocalizations.of(context).tableNote),
      actions: [
        Consumer<TableProvider>(
          builder: (context, provider, child) {
            if (!provider.hasTables) return const SizedBox();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.manage_search_rounded),
                  onPressed: () => _showSearchDialog(context),
                  tooltip: AppLocalizations.of(context).findTable,
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () => _showExportDialog(context),
                  tooltip: AppLocalizations.of(context).exportData,
                ),
                IconButton(
                  icon: const Icon(Icons.article_outlined),
                  onPressed: () => _showTemplateDialog(context),
                  tooltip: AppLocalizations.of(context).templates,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ============== ÇETELE TAB ==============

  PreferredSizeWidget _buildTallyAppBar() {
    final loc = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: loc.menu,
      ),
      title: Text(loc.tallyTab),
      actions: [
        Consumer<TallyProvider>(
          builder: (context, provider, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (provider.hasTables)
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () => _showTallyExportDialog(context, provider),
                    tooltip: loc.exportData,
                  ),
                if (provider.hasTables)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteTallyDialog(context, provider);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading:
                              Icon(Icons.delete_outline, color: AppTheme.error),
                          title: Text(loc.delete,
                              style: const TextStyle(color: AppTheme.error)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showDeleteTallyDialog(BuildContext context, TallyProvider provider) {
    final loc = AppLocalizations.of(context);
    if (!provider.hasTables) return;
    final table = provider.currentTable!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppTheme.error),
            const SizedBox(width: 8),
            Text(loc.tallyDeleteTable),
          ],
        ),
        content: Text(loc.deleteTableConfirm(table.tableName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteTable(provider.currentIndex);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  void _showTallyExportDialog(BuildContext context, TallyProvider provider) {
    if (!provider.hasTables) return;
    final loc = AppLocalizations.of(context);
    final table = provider.currentTable!;
    bool isExporting = false;
    String? exportedFilePath;
    String? exportFormat;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppTheme.lightBlue,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.download_rounded,
                    color: AppTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(loc.exportTitle,
                      style: const TextStyle(fontSize: 18))),
            ],
          ),
          content: isExporting
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(loc.creatingFile,
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                )
              : exportedFilePath != null
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green[600], size: 48),
                          const SizedBox(height: 12),
                          Text(
                            loc.fileCreated(exportFormat!.toUpperCase()),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await ExportService.shareFile(exportedFilePath!,
                                    '${table.tableName} - ${exportFormat!.toUpperCase()}');
                              },
                              icon: const Icon(Icons.share),
                              label: Text(loc.shareWhatsApp),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final savedPath =
                                    await ExportService.saveToDownloads(
                                        exportedFilePath!);
                                if (savedPath != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(children: [
                                        const Icon(Icons.check,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(loc.fileSaved(
                                                savedPath.split('/').last))),
                                      ]),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(loc.fileSaveFailed),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              },
                              icon: const Icon(Icons.save_alt),
                              label: Text(loc.saveToDevice),
                              style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                exportedFilePath = null;
                                exportFormat = null;
                              });
                            },
                            child: Text(loc.selectAnotherFormat),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppTheme.lightBlue,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.grid_on_rounded,
                                  color: AppTheme.primaryBlue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(table.tableName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16)),
                                    Text(
                                        '${table.items.length} ${loc.tallyItems} • ${table.dayCount} ${loc.tallyDays}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(loc.selectFormat,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        _buildExportOption(
                          icon: Icons.description,
                          title: 'CSV',
                          subtitle: loc.csvDesc,
                          color: Colors.green,
                          onTap: () async {
                            setDialogState(() => isExporting = true);
                            try {
                              final path =
                                  await ExportService.exportTallyCsv(table);
                              setDialogState(() {
                                isExporting = false;
                                exportedFilePath = path;
                                exportFormat = 'csv';
                              });
                            } catch (e) {
                              setDialogState(() => isExporting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('${loc.error}: $e'),
                                      backgroundColor: Colors.red));
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildExportOption(
                          icon: Icons.picture_as_pdf,
                          title: 'PDF',
                          subtitle: loc.pdfDesc,
                          color: Colors.red,
                          onTap: () async {
                            setDialogState(() => isExporting = true);
                            try {
                              final path = await ExportService.exportTallyPdf(
                                  table,
                                  loc: loc);
                              setDialogState(() {
                                isExporting = false;
                                exportedFilePath = path;
                                exportFormat = 'pdf';
                              });
                            } catch (e) {
                              setDialogState(() => isExporting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('${loc.error}: $e'),
                                      backgroundColor: Colors.red));
                            }
                          },
                        ),
                      ],
                    ),
          actions: [
            if (!isExporting)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(exportedFilePath != null ? loc.close : loc.cancel),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  // ============== TABLO ORTAK METOTLAR (DEĞİŞMEDİ) ==============

  Widget _buildTableHeader(TableProvider provider) {
    final table = provider.currentTable;
    if (table == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.table_chart_rounded,
                color: AppTheme.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(table.tableName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip(
                        Icons.list_alt_rounded,
                        AppLocalizations.of(context)
                            .nRecords(table.rows.length)),
                    SizedBox(width: 12),
                    _buildInfoChip(
                        Icons.view_column_rounded,
                        AppLocalizations.of(context)
                            .nColumns(table.columns.length)),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    provider.clearSearch();
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isSearching
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                    _isSearching
                        ? Icons.search_off_rounded
                        : Icons.search_rounded,
                    color: _isSearching
                        ? AppTheme.primaryBlue
                        : AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.swap_horiz_rounded,
                      color: AppTheme.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(TableProvider provider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isSearching ? 60 : 0,
      child: _isSearching
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchInTable,
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.primaryBlue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            provider.clearSearch();
                            setState(() {});
                          })
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryBlue, width: 2)),
                ),
                onChanged: (value) {
                  provider.setSearchQuery(value);
                  setState(() {});
                },
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(text,
            style:
                const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildAddRowButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: SafeArea(
        top: false,
        child: ElevatedButton.icon(
          onPressed: () => _showAddRowDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(AppLocalizations.of(context).addRecord),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) =>
      showDialog(context: context, builder: (_) => TableSearchDialog());
  void _showAddRowDialog(BuildContext context) =>
      showDialog(context: context, builder: (_) => AddRowDialog());
  void _showTemplateDialog(BuildContext context) => showDialog(
      context: context, builder: (_) => const TemplateManagementDialog());
  void _showExportDialog(BuildContext context) =>
      showDialog(context: context, builder: (_) => const ExportDialog());
}