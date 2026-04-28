import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../theme/app_theme.dart';
import 'create_table_dialog.dart';
import 'edit_table_structure_dialog.dart';
import 'template_management_dialog.dart';
import 'create_tally_dialog.dart';
import '../l10n/app_localizations.dart';
import '../screens/settings_screen.dart';

class TableDrawer extends StatelessWidget {
  final ValueChanged<int>? onTabChanged;

  const TableDrawer({Key? key, this.onTabChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Normal Tablolar bölümü
                    _buildSectionHeader(context, Icons.table_chart_rounded, AppLocalizations.of(context).tableNote),
                    _buildNormalTableList(context),
                    
                    const Divider(height: 24),
                    
                    // Çetele Tabloları bölümü
                    _buildSectionHeader(context, Icons.grid_on_rounded, AppLocalizations.of(context).tallyTab),
                    _buildTallyTableList(context),
                  ],
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.gradientDecoration(radius: 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).myTables, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(AppLocalizations.of(context).selectOrCreateTable, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // ============== NORMAL TABLOLAR ==============

  Widget _buildNormalTableList(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, _) {
        if (!provider.hasTables) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(AppLocalizations.of(context).noTablesYet, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: provider.tables.length,
          itemBuilder: (context, index) {
            final table = provider.tables[index];
            final isActive = index == provider.currentTableIndex;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.lightBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive ? Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)) : null,
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryBlue : AppTheme.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.table_chart_rounded, color: isActive ? Colors.white : AppTheme.textSecondary, size: 18),
                ),
                title: Text(table.tableName, style: TextStyle(fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, color: isActive ? AppTheme.primaryBlue : AppTheme.textPrimary, fontSize: 14)),
                subtitle: Text(AppLocalizations.of(context).recordsAndColumns(table.rows.length, table.columns.length),
                    style: TextStyle(fontSize: 11, color: isActive ? AppTheme.primaryBlue.withValues(alpha: 0.7) : AppTheme.textSecondary)),
                trailing: isActive
                    ? IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        color: AppTheme.primaryBlue,
                        onPressed: () {
                          Navigator.pop(context);
                          showDialog(context: context, builder: (_) => const EditTableStructureDialog());
                        },
                        tooltip: AppLocalizations.of(context).editStructure,
                      )
                    : null,
                onTap: () {
                  provider.changeTable(index);
                  onTabChanged?.call(0); // Tablo tab'ına geç
                  Navigator.pop(context);
                },
                onLongPress: () => _showTableOptions(context, provider, index),
              ),
            );
          },
        );
      },
    );
  }

  // ============== ÇETELE TABLOLARI ==============

  Widget _buildTallyTableList(BuildContext context) {
    return Consumer<TallyProvider>(
      builder: (context, provider, _) {
        if (!provider.hasTables) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(AppLocalizations.of(context).tallyNoItems, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: provider.tables.length,
          itemBuilder: (context, index) {
            final table = provider.tables[index];
            final isActive = index == provider.currentIndex;
            final dateRange = '${table.startDate.day}/${table.startDate.month} - ${table.endDate.day}/${table.endDate.month}';
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? Colors.teal.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive ? Border.all(color: Colors.teal.withValues(alpha: 0.3)) : null,
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.teal : AppTheme.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.grid_on_rounded, color: isActive ? Colors.white : AppTheme.textSecondary, size: 18),
                ),
                title: Text(table.tableName, style: TextStyle(fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, color: isActive ? Colors.teal : AppTheme.textPrimary, fontSize: 14)),
                subtitle: Text('${table.items.length} ${AppLocalizations.of(context).tallyItems} • $dateRange',
                    style: TextStyle(fontSize: 11, color: isActive ? Colors.teal.withValues(alpha: 0.7) : AppTheme.textSecondary)),
                onTap: () {
                  provider.changeTable(index);
                  onTabChanged?.call(1); // Çetele tab'ına geç
                  Navigator.pop(context);
                },
                onLongPress: () => _showTallyOptions(context, provider, index),
              ),
            );
          },
        );
      },
    );
  }

  // ============== TABLO SEÇENEKLERİ ==============

  void _showTableOptions(BuildContext context, TableProvider provider, int index) {
    final table = provider.tables[index];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.table_chart_rounded, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(child: Text(table.tableName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                ]),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppTheme.success),
                title: Text(AppLocalizations.of(context).switchToTable),
                onTap: () { provider.changeTable(index); Navigator.pop(context); Navigator.pop(context); },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: AppTheme.primaryBlue),
                title: Text(AppLocalizations.of(context).editStructure),
                onTap: () {
                  provider.changeTable(index);
                  Navigator.pop(context);
                  Navigator.pop(context);
                  showDialog(context: context, builder: (_) => const EditTableStructureDialog());
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                title: Text(AppLocalizations.of(context).deleteTable, style: const TextStyle(color: AppTheme.error)),
                onTap: () { Navigator.pop(context); _showDeleteConfirmation(context, provider, index); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTallyOptions(BuildContext context, TallyProvider provider, int index) {
    final table = provider.tables[index];
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.grid_on_rounded, color: Colors.teal),
                  const SizedBox(width: 12),
                  Expanded(child: Text(table.tableName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                ]),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppTheme.success),
                title: Text(loc.switchToTable),
                onTap: () {
                  provider.changeTable(index);
                  onTabChanged?.call(1);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                title: Text(loc.tallyDeleteTable, style: const TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteTallyConfirmation(context, provider, index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TableProvider provider, int index) {
    final table = provider.tables[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_rounded, color: AppTheme.error),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context).deleteTable),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).deleteTableConfirm(table.tableName)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.coloredCardDecoration(AppTheme.error),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppTheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(AppLocalizations.of(context).nRecordsPermanentDelete(table.rows.length), style: const TextStyle(fontSize: 13, color: AppTheme.error))),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context).cancel)),
          ElevatedButton(
            onPressed: () async { await provider.deleteTable(index); Navigator.pop(context); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
  }

  void _showDeleteTallyConfirmation(BuildContext context, TallyProvider provider, int index) {
    final table = provider.tables[index];
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_rounded, color: AppTheme.error),
          const SizedBox(width: 8),
          Text(loc.tallyDeleteTable),
        ]),
        content: Text(loc.deleteTableConfirm(table.tableName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
          ElevatedButton(
            onPressed: () async { await provider.deleteTable(index); Navigator.pop(context); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  // ============== FOOTER ==============

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); showDialog(context: context, builder: (_) => CreateTableDialog()); },
              icon: const Icon(Icons.add_rounded),
              label: Text(AppLocalizations.of(context).newTable),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(context); showDialog(context: context, builder: (_) => const TemplateManagementDialog()); },
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: Text(AppLocalizations.of(context).templates, style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(context); showDialog(context: context, builder: (_) => const CreateTallyDialog()); },
                  icon: const Icon(Icons.grid_on_rounded, size: 18),
                  label: Text(AppLocalizations.of(context).tallyTab, style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); },
              icon: const Icon(Icons.settings_outlined, size: 20),
              label: Text(AppLocalizations.of(context).settings),
              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
