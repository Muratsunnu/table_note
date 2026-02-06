import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/table_list_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/create_table_dialog.dart';
import '../widgets/add_row_dialog.dart';
import '../widgets/template_management_dialog.dart';
import '../widgets/column_sums_widget.dart';
import '../widgets/table_search_dialog.dart';
import '../widgets/export_dialog.dart';
import '../widgets/table_drawer.dart';

class TableScreen extends StatefulWidget {
  @override
  _TableScreenState createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      drawer: const TableDrawer(),
      body: Consumer<TableProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!provider.hasTables) {
            return EmptyStateWidget(
              onCreateTable: () => _showCreateTableDialog(context),
            );
          }

          return Column(
            children: [
              // Tablo başlık kartı
              _buildTableHeader(provider),
              
              // Arama çubuğu
              _buildSearchBar(provider),
              
              // Tablo içeriği
              Expanded(
                child: TableListWidget(),
              ),
              
              // Toplam widget
              const ColumnSumsWidget(),
              
              // Kayıt ekle butonu
              _buildAddRowButton(),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: Consumer<TableProvider>(
        builder: (context, provider, child) {
          return IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'Menü',
          );
        },
      ),
      title: const Text('Table Note'),
      actions: [
        Consumer<TableProvider>(
          builder: (context, provider, child) {
            if (!provider.hasTables) return const SizedBox();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tablolar arası arama
                IconButton(
                  icon: const Icon(Icons.manage_search_rounded),
                  onPressed: () => _showSearchDialog(context),
                  tooltip: 'Tablo Bul',
                ),
                // Çıktı al
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () => _showExportDialog(context),
                  tooltip: 'Çıktı Al',
                ),
                // Daha fazla
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Daha Fazla',
                  onSelected: (value) => _handleMenuAction(value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'new_table',
                      child: ListTile(
                        leading: Icon(Icons.add_circle_outline),
                        title: Text('Yeni Tablo'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'templates',
                      child: ListTile(
                        leading: Icon(Icons.article_outlined),
                        title: Text('Şablonlar'),
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

  Widget _buildTableHeader(TableProvider provider) {
    final table = provider.currentTable;
    if (table == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          // Tablo ikonu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.table_chart_rounded,
              color: AppTheme.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          
          // Tablo bilgisi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  table.tableName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.list_alt_rounded,
                      '${table.rows.length} kayıt',
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.view_column_rounded,
                      '${table.columns.length} sütun',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Arama butonu
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
                  color: _isSearching ? AppTheme.primaryBlue.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isSearching ? Icons.search_off_rounded : Icons.search_rounded,
                  color: _isSearching ? AppTheme.primaryBlue : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 4),
          
          // Tablo değiştir butonu
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
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
                  hintText: 'Tabloda ara...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            provider.clearSearch();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                  ),
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
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAddRowButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton.icon(
          onPressed: () => _showAddRowDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Kayıt Ekle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'new_table':
        _showCreateTableDialog(context);
        break;
      case 'templates':
        _showTemplateDialog(context);
        break;
    }
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TableSearchDialog(),
    );
  }

  void _showCreateTableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateTableDialog(),
    );
  }

  void _showAddRowDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddRowDialog(),
    );
  }

  void _showTemplateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TemplateManagementDialog(),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ExportDialog(),
    );
  }
}