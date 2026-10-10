import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import '../services/shared_sync_service.dart';
import '../widgets/backup_reminder.dart';
import '../widgets/compact_layout.dart';
import '../widgets/edit_access.dart';
import '../widgets/leave_shared_table.dart';
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
import '../widgets/share_file_sheet.dart';
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
  // Ekran çevrilince gövde ağaçta yer değiştirir; durumu (arama, kaydırma)
  // bu anahtarla taşınır.
  final GlobalKey _bodyKey = GlobalKey();
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
    // Yan çevrilmiş telefonda yükseklik azdır: sekmeler ve kayıt ekleme
    // düğmesi yandaki çubuğa geçer, alt çubuklar tabloya yer bırakır.
    final compact = isCompactHeight(context);
    final body = KeyedSubtree(
      key: _bodyKey,
      child: _currentTab == 0 ? _buildTableBody() : const TallyScreen(),
    );
    return Scaffold(
      key: _scaffoldKey,
      appBar: _currentTab == 0 ? _buildTableAppBar() : _buildTallyAppBar(),
      drawer: TableDrawer(onTabChanged: _selectTab),
      // Yan kenarlardaki çentik payı her iki düzende de gövdeden düşülür.
      body: compact
          ? Row(
              children: [
                _buildNavigationRail(loc),
                const VerticalDivider(width: 1),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeLeft: true,
                    child: SafeArea(top: false, child: body),
                  ),
                ),
              ],
            )
          : SafeArea(
              top: false,
              bottom: false,
              // Yedekleme hatırlatması iki sekmenin de üstüne iner.
              child: Column(
                children: [
                  const BackupReminderCard(),
                  Expanded(child: body),
                ],
              ),
            ),
      bottomNavigationBar: compact
          ? null
          : NavigationBar(
              selectedIndex: _currentTab,
              onDestinationSelected: _selectTab,
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

  void _selectTab(int tab) {
    setState(() => _currentTab = tab);
    StorageService.saveLastActiveTab(tab);
  }

  Widget _buildNavigationRail(AppLocalizations loc) {
    return SafeArea(
      top: false,
      right: false,
      bottom: false,
      // Çok alçak ekranda çubuk taşmak yerine kayar.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: _currentTab,
                onDestinationSelected: _selectTab,
                labelType: NavigationRailLabelType.all,
                leading: _buildRailActions(loc),
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.table_chart_outlined),
                    selectedIcon: const Icon(Icons.table_chart_rounded),
                    label: Text(loc.tablesTab),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.grid_on_outlined),
                    selectedIcon: const Icon(Icons.grid_on_rounded),
                    label: Text(loc.tallyTab),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Alt çubuktaki kayıt ekleme düğmelerinin yan çubuktaki karşılığı.
  Widget? _buildRailActions(AppLocalizations loc) {
    if (_currentTab == 1) {
      final tallies = context.watch<TallyProvider>();
      final tally = tallies.currentTable;
      if (tally == null) return null;
      if (!tallies.canEditCurrent) {
        return RequestEditAccessIconButton(tableId: tally.id);
      }
      return IconButton.filled(
        tooltip: loc.tallyAddItem,
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const AddTallyItemDialog(),
        ),
        icon: const Icon(Icons.add_rounded),
      );
    }
    final tables = context.watch<TableProvider>();
    final table = tables.currentTable;
    if (table == null) return null;
    if (tables.isSharedViewer(table.id)) {
      return RequestEditAccessIconButton(tableId: table.id);
    }
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          tooltip: loc.addRecord,
          onPressed: () => _showAddRowDialog(context),
          icon: const Icon(Icons.add_rounded),
        ),
        const SizedBox(height: 4),
        IconButton.filledTonal(
          tooltip: loc.voiceFill,
          onPressed: () => _startVoiceAdd(isPremium),
          icon: Icon(isPremium ? Icons.mic_rounded : Icons.lock_rounded),
        ),
      ],
    );
  }

  void _startVoiceAdd(bool isPremium) {
    if (isPremium) {
      _showVoiceAddRowDialog(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
    }
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
        final compact = isCompactHeight(context);
        // Başlık ve arama en fazla ekranın yarısını alır, gerekirse kayar;
        // klavye açıkken de tabloya yer kalır ve hiçbir şey taşmaz.
        return LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .55,
                ),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    children: [
                      _buildTableHeader(provider, compact: compact),
                      _buildSearchBar(provider),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: MinHeightClip(
                  minHeight: 168,
                  child: Column(
                    children: [
                      Expanded(child: TableListWidget()),
                      const ColumnSumsWidget(),
                    ],
                  ),
                ),
              ),
              if (!compact) _buildAddRowButton(),
            ],
          ),
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
        Consumer2<TableProvider, SharedSyncService>(
          builder: (context, provider, sync, _) {
            final table = provider.currentTable;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Kodla katılan kişi tabloyu başkasına açamaz; düğme yalnızca
                // tablonun sahibinde ve henüz paylaşılmamış tabloda durur.
                if (table != null &&
                    (!provider.isSharedTable(table.id) ||
                        provider.isSharedOwner(table.id)))
                  _shareButton(
                    shared: provider.isSharedOwner(table.id),
                    pendingRequests: sync.accessFor(table.id).pendingRequests,
                    onPressed: () => ShareTableSheet.show(
                      context,
                      tableId: table.id,
                      isTally: false,
                    ),
                  ),
                // İndirme değil paylaşma: çoğu kişi dosyayı cihazına almak
                // değil birine göndermek istiyor.
                if (provider.hasTables)
                  IconButton(
                    key: const ValueKey('share-file'),
                    icon: Icon(Icons.adaptive.share_rounded),
                    onPressed: () => _shareTableFile(provider),
                    tooltip: loc.shareAsFile,
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
  Widget _shareButton({
    required bool shared,
    required int pendingRequests,
    required VoidCallback onPressed,
  }) {
    final loc = AppLocalizations.of(context);
    final icon = Icon(
      shared ? Icons.group_rounded : Icons.person_add_alt_1_outlined,
    );
    return IconButton(
      key: const ValueKey('share-table'),
      // Yanıt bekleyen yetki talebi varsa simgenin üstünde sayısı görünür.
      icon: pendingRequests > 0
          ? Badge(label: Text('$pendingRequests'), child: icon)
          : icon,
      tooltip: pendingRequests > 0
          ? loc.editRequests
          : shared
          ? loc.joinCode
          : loc.invitePeople,
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
        Consumer2<TallyProvider, SharedSyncService>(
          builder: (context, provider, sync, _) {
            final tally = provider.currentTable;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tally != null &&
                    (!provider.isSharedTally(tally.id) ||
                        provider.isSharedOwner(tally.id)))
                  _shareButton(
                    shared: provider.isSharedOwner(tally.id),
                    pendingRequests: sync.accessFor(tally.id).pendingRequests,
                    onPressed: () => ShareTableSheet.show(
                      context,
                      tableId: tally.id,
                      isTally: true,
                    ),
                  ),
                if (provider.hasTables)
                  IconButton(
                    key: const ValueKey('share-file'),
                    icon: Icon(Icons.adaptive.share_rounded),
                    onPressed: () => _shareTallyFile(provider),
                    tooltip: loc.shareAsFile,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Çeteleyi dosya olarak paylaşma kâğıdı.
  void _shareTallyFile(TallyProvider provider) {
    final table = provider.currentTable;
    if (table == null) return;
    final loc = AppLocalizations.of(context);
    ShareFileSheet.show(
      context,
      name: table.tableName,
      summary:
          '${table.items.length} ${loc.tallyItems} • '
          '${table.dayCount} ${loc.tallyDays}',
      icon: Icons.grid_on_rounded,
      formats: [
        ShareFileFormat(
          label: 'PDF',
          description: loc.pdfDesc,
          icon: Icons.picture_as_pdf_rounded,
          color: AppTheme.error,
          create: () => ExportService.exportTallyPdf(table, loc: loc),
        ),
        ShareFileFormat(
          label: 'CSV',
          description: loc.csvDesc,
          icon: Icons.description_rounded,
          color: AppTheme.success,
          create: () => ExportService.exportTallyCsv(table),
        ),
      ],
    );
  }

  /// Tabloyu dosya olarak paylaşma kâğıdı.
  void _shareTableFile(TableProvider provider) {
    final table = provider.currentTable;
    if (table == null) return;
    final loc = AppLocalizations.of(context);
    ShareFileSheet.show(
      context,
      name: table.tableName,
      summary: loc.recordsAndColumns(table.rows.length, table.columns.length),
      icon: Icons.table_chart_rounded,
      formats: [
        ShareFileFormat(
          label: 'PDF',
          description: loc.pdfDesc,
          icon: Icons.picture_as_pdf_rounded,
          color: AppTheme.error,
          create: () => ExportService.exportToPdf(
            table,
            loc: loc,
            columnSums: provider.calculateFilteredColumnSums(),
          ),
        ),
        ShareFileFormat(
          label: 'CSV',
          description: loc.csvDesc,
          icon: Icons.description_rounded,
          color: AppTheme.success,
          create: () => ExportService.exportToCsv(table, loc: loc),
        ),
      ],
    );
  }

  // ============== TABLO ORTAK METOTLAR (DEĞİŞMEDİ) ==============

  Widget _buildTableHeader(TableProvider provider, {bool compact = false}) {
    final table = provider.currentTable;
    if (table == null) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context);
    return TableSectionHeader(
      title: table.tableName,
      summary: loc.nRecords(table.rows.length),
      compact: compact,
      footer: const BackupStatusLine(),
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
              // Katılınan tablo silinmez, ondan ayrılınır.
              Icon(
                _isJoined(provider)
                    ? Icons.logout_rounded
                    : Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 10),
              Text(
                _isJoined(provider) ? loc.leaveShared : loc.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Açık tablo kodla katılınmış bir tablo mu (sahibi başkası).
  bool _isJoined(TableProvider provider) {
    final table = provider.currentTable;
    return table != null &&
        provider.isSharedTable(table.id) &&
        !provider.isSharedOwner(table.id);
  }

  void _confirmTableDeletion(TableProvider provider) {
    final table = provider.currentTable;
    if (table == null) return;
    if (_isJoined(provider)) {
      leaveSharedTableFlow(
        context,
        tableId: table.id,
        tableName: table.tableName,
        isTally: false,
      );
      return;
    }
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

  /// Arama kutusunun altındaki tek satırlık ipucu: kutu boşken tek sütunda
  /// aramanın nasıl yapıldığını öğretir, öyle yazıldığında da anlaşıldığını
  /// doğrular.
  String? _searchHelper(TableProvider provider) {
    final loc = AppLocalizations.of(context);
    final table = provider.currentTable;
    if (table == null || table.columns.isEmpty) return null;
    final scoped = provider.searchColumnIndex;
    if (scoped != null && scoped < table.columns.length) {
      return loc.searchingInColumn(table.columns[scoped].name);
    }
    if (_searchController.text.isNotEmpty) return null;
    return loc.searchColumnHint(table.columns.first.name.toLowerCase());
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
                  helperText: _searchHelper(provider),
                  helperMaxLines: 2,
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
    final tables = context.watch<TableProvider>();
    final table = tables.currentTable;
    // Yalnızca görüntüleyen kişide kayıt eklenmez; aynı yerde yetki istenir.
    final viewOnly = table != null && tables.isSharedViewer(table.id);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: viewOnly
            ? SizedBox(
                width: double.infinity,
                child: RequestEditAccessButton(tableId: table.id),
              )
            : Row(
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
                    onPressed: () => _startVoiceAdd(isPremium),
                    padding: const EdgeInsets.all(14),
                    tooltip: AppLocalizations.of(context).voiceFill,
                    icon: Icon(
                      isPremium ? Icons.mic_rounded : Icons.lock_rounded,
                    ),
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
}
