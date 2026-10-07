import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/share_table_sheet.dart';
import '../widgets/shared_sync_indicator.dart';
import '../widgets/table_list_widget.dart';
import '../models/overview_grid.dart';
import '../widgets/grid_overview_screen.dart';
import '../widgets/table_section_header.dart';
import '../widgets/edit_table_structure_dialog.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/add_row_dialog.dart';
import '../widgets/voice_add_row_dialog.dart';
import '../widgets/csv_import_dialog.dart';
import '../widgets/template_management_dialog.dart';
import '../widgets/column_sums_widget.dart';
import '../widgets/export_dialog.dart';
import '../widgets/table_drawer.dart';
import '../widgets/create_table_dialog.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ux_localizations.dart';
import 'tally_screen.dart';
import 'premium_screen.dart';
import '../services/home_widget_service.dart';
import '../widgets/add_tally_item_dialog.dart';

class TableScreen extends StatefulWidget {
  @override
  _TableScreenState createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  int _currentTab = 0;
  bool _widgetRequestScheduled = false;
  bool _widgetSelectedTab = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final widgets = context.watch<HomeWidgetService>();
    final tables = context.watch<TableProvider>();
    final tallies = context.watch<TallyProvider>();
    if (widgets.pending == null ||
        tables.isLoading ||
        tallies.isLoading ||
        _widgetRequestScheduled ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _widgetRequestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _widgetRequestScheduled = false;
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final request = widgets.pending;
      if (request == null) return;
      widgets.consume(request);
      final index = request.kind == 'table'
          ? tables.tables.indexWhere((table) => table.id == request.tableId)
          : tallies.tables.indexWhere((table) => table.id == request.tableId);
      if (index < 0) {
        final tr = AppLocalizations.of(context).locale.languageCode != 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr
                  ? 'Bu tablo artık mevcut değil. Widget seçimini değiştir.'
                  : 'This table no longer exists. Change the widget selection.',
            ),
          ),
        );
        return;
      }
      if (_scaffoldKey.currentState?.isDrawerOpen == true) {
        _scaffoldKey.currentState!.closeDrawer();
      }
      if (request.kind == 'table') {
        tables.changeTable(index);
        tables.setSearchQuery('');
      } else {
        tallies.changeTable(index);
      }
      setState(() {
        _widgetSelectedTab = true;
        _currentTab = request.kind == 'table' ? 0 : 1;
        _isSearching = false;
        _searchController.clear();
      });
      StorageService.saveLastActiveTab(_currentTab);
      if (request.add) {
        if (request.kind == 'table') {
          _showAddRowDialog(context);
        } else {
          showDialog<void>(
            context: context,
            builder: (_) => const AddTallyItemDialog(),
          );
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLastTab();
  }

  Future<void> _loadLastTab() async {
    final tab = await StorageService.loadLastActiveTab();
    if (mounted && !_widgetSelectedTab) setState(() => _currentTab = tab);
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
      drawer: TableDrawer(
        onTabChanged: (tab) {
          setState(() => _currentTab = tab);
          StorageService.saveLastActiveTab(tab);
        },
      ),
      body: _currentTab == 0 ? _buildTableBody() : const TallyScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() => _currentTab = index);
          StorageService.saveLastActiveTab(index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.table_chart_outlined),
            selectedIcon: const Icon(Icons.table_chart_rounded),
            label: loc.tablesTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_on_outlined),
            selectedIcon: const Icon(Icons.grid_on_rounded),
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
          return EmptyStateWidget(onCreate: () => _showCreateTable(context));
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
    final loc = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: loc.menu,
      ),
      title: Text(loc.tableNote),
      actions: [
        Consumer<TableProvider>(
          builder: (context, provider, _) {
            final table = provider.currentTable;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Kodla katılan kişi tabloyu başkasına açamaz; düğme yalnızca
                // tablonun sahibinde ve henüz paylaşılmamış tabloda durur.
                if (table != null && provider.sharedRole(table.id) != 'editor')
                  _shareButton(
                    shared: provider.isSharedOwner(table.id),
                    onPressed: () => ShareTableSheet.show(
                      context,
                      tableId: table.id,
                      isTally: false,
                    ),
                  ),
                if (provider.hasTables)
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () => _showExportDialog(context),
                    tooltip: loc.exportData,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Tabloya bakarken tek dokunuşla paylaşım: kodu vermek için ayarlara
  /// girmek gerekmez. Paylaşımdaki tabloda simge dolu görünür.
  Widget _shareButton({required bool shared, required VoidCallback onPressed}) {
    final loc = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey('share-table'),
      icon: Icon(
        shared ? Icons.group_rounded : Icons.person_add_alt_1_outlined,
      ),
      tooltip: shared ? loc.joinCode : loc.share,
      onPressed: onPressed,
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
            final tally = provider.currentTable;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tally != null && provider.sharedRole(tally.id) != 'editor')
                  _shareButton(
                    shared: provider.isSharedOwner(tally.id),
                    onPressed: () => ShareTableSheet.show(
                      context,
                      tableId: tally.id,
                      isTally: true,
                    ),
                  ),
                if (provider.hasTables)
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () => _showTallyExportDialog(context, provider),
                    tooltip: loc.exportData,
                  ),
              ],
            );
          },
        ),
      ],
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
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.exportTitle,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: isExporting
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      loc.creatingFile,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : exportedFilePath != null
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.tintedSurface(context, Colors.green),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.readableAccent(context, Colors.green),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loc.fileCreated(exportFormat!.toUpperCase()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.readableAccent(context, Colors.green),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await ExportService.shareFile(
                              exportedFilePath!,
                              '${table.tableName} - ${exportFormat!.toUpperCase()}',
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: Text(loc.shareWhatsApp),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final savedPath =
                                await ExportService.saveToDownloads(
                                  exportedFilePath!,
                                );
                            if (savedPath != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          loc.fileSaved(
                                            savedPath.split('/').last,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(loc.fileSaveFailed),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.save_alt),
                          label: Text(loc.saveToDevice),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.grid_on_rounded,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  table.tableName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${table.items.length} ${loc.tallyItems} • ${table.dayCount} ${loc.tallyDays}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.selectFormat,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildExportOption(
                      icon: Icons.description,
                      title: 'CSV',
                      subtitle: loc.csvDesc,
                      color: Colors.green,
                      onTap: () async {
                        setDialogState(() => isExporting = true);
                        try {
                          final path = await ExportService.exportTallyCsv(
                            table,
                          );
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
                              backgroundColor: Colors.red,
                            ),
                          );
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
                            loc: loc,
                          );
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
                              backgroundColor: Colors.red,
                            ),
                          );
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

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ============== TABLO ORTAK METOTLAR (DEĞİŞMEDİ) ==============

  Widget _buildTableHeader(TableProvider provider) {
    final table = provider.currentTable;
    if (table == null) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context);
    return TableSectionHeader(
      title: table.tableName,
      summary: loc.nRecords(table.rows.length),
      // Ortak olmayan tabloda hicbir sey cizmez.
      titleTrailing: const SharedSyncIndicator(),
      actions: [
        IconButton(
          tooltip: loc.locale.languageCode == 'en'
              ? 'Whole table'
              : 'Tablonun tamamı',
          icon: const Icon(Icons.zoom_out_map_rounded),
          // Always the whole table in the on-screen order, search aside.
          onPressed: table.columns.isEmpty
              ? null
              : () => GridOverviewScreen.open(
                  context,
                  buildTableOverview(
                    table,
                    provider.sortedRowIndices,
                    language: loc.locale.languageCode,
                  ),
                ),
        ),
        IconButton(
          tooltip: loc.searchInTable,
          isSelected: _isSearching,
          selectedIcon: const Icon(Icons.search_off_rounded),
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                provider.clearSearch();
              }
            });
          },
        ),
        _buildTableActions(provider),
      ],
    );
  }

  Widget _buildTableActions(TableProvider provider) {
    final loc = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded),
      tooltip: loc.moreActions,
      onSelected: (value) {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const EditTableStructureDialog(),
            ),
          );
        } else if (value == 'delete') {
          _confirmTableDeletion(provider);
        } else if (value == 'import') {
          context.read<SubscriptionProvider>().isPremium
              ? _showCsvImportDialog(context)
              : Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
        } else if (value == 'templates') {
          _showTemplateDialog(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: Text(loc.editStructure)),
        PopupMenuItem(value: 'import', child: Text(loc.importCsv)),
        PopupMenuItem(value: 'templates', child: Text(loc.templates)),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 10),
              Text(
                loc.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmTableDeletion(TableProvider provider) {
    final table = provider.currentTable;
    if (table == null) return;
    final loc = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.deleteTable),
        content: Text(loc.deleteTableConfirmFull(table.tableName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () async {
              final index = provider.tables.indexOf(table);
              if (index < 0) return;
              await provider.deleteTable(index);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(TableProvider provider) {
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: _isSearching
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchInTable,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: AppLocalizations.of(context).clear,
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            provider.clearSearch();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  provider.setSearchQuery(value);
                  setState(() {});
                },
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildAddRowButton() {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _showAddRowDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(AppLocalizations.of(context).addRecord),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => isPremium
                  ? _showVoiceAddRowDialog(context)
                  : Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                    ),
              padding: const EdgeInsets.all(14),
              tooltip: AppLocalizations.of(context).voiceFill,
              icon: Icon(isPremium ? Icons.mic_rounded : Icons.lock_rounded),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRowDialog(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AddRowDialog(),
    ),
  );
  void _showCreateTable(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CreateTableDialog(),
    ),
  );
  void _showVoiceAddRowDialog(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const VoiceAddRowDialog(),
    ),
  );
  void _showCsvImportDialog(BuildContext context) =>
      showDialog(context: context, builder: (_) => const CsvImportDialog());
  void _showTemplateDialog(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const TemplateManagementDialog(),
    ),
  );
  void _showExportDialog(BuildContext context) =>
      showDialog(context: context, builder: (_) => const ExportDialog());
}
