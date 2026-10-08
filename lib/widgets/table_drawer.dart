import 'leave_shared_table.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../providers/subscription_provider.dart';
import '../config/plan_limits.dart';
import '../theme/app_theme.dart';
import 'create_table_dialog.dart';
import 'table_search_dialog.dart';
import 'edit_table_structure_dialog.dart';
import 'edit_tally_dialog.dart';
import 'create_tally_dialog.dart';
import 'template_management_dialog.dart';
import 'tally_template_management_dialog.dart';
import '../l10n/app_localizations.dart';
import '../screens/join_shared_table_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/premium_screen.dart';

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
                    _buildSectionHeader(
                      context,
                      Icons.table_chart_rounded,
                      AppLocalizations.of(context).tablesTab,
                      isTally: false,
                    ),
                    _buildNormalTableList(context),

                    const Divider(height: 24),

                    // Çetele Tabloları bölümü
                    _buildSectionHeader(
                      context,
                      Icons.grid_on_rounded,
                      AppLocalizations.of(context).tallyTab,
                      isTally: true,
                    ),
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
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.table_chart_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).myTables,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context).selectOrCreateTable,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    IconData icon,
    String title, {
    required bool isTally,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            tooltip: isTally
                ? AppLocalizations.of(context).searchTally
                : AppLocalizations.of(context).searchTable,
            onPressed: () => _showTableSearch(context, isTally: isTally),
            icon: const Icon(Icons.manage_search_rounded),
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }

  // ============== NORMAL TABLOLAR ==============

  Future<void> _showTableSearch(
    BuildContext context, {
    required bool isTally,
  }) async {
    final scaffold = Scaffold.of(context);
    final screenContext = scaffold.context;
    final selected = await showDialog<bool>(
      context: screenContext,
      builder: (_) => TableSearchDialog(isTally: isTally),
    );
    if (screenContext.mounted && selected == true) {
      scaffold.closeDrawer();
      onTabChanged?.call(isTally ? 1 : 0);
    }
  }

  Widget _buildNormalTableList(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, _) {
        if (!provider.hasTables) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              AppLocalizations.of(context).noTablesYet,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
                color: isActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive
                    ? Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      )
                    : null,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primaryBlue
                          : Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.table_chart_rounded,
                      color: isActive
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    table.tableName,
                    style: TextStyle(
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isActive
                          ? AppTheme.primaryBlue
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context).recordsAndColumns(
                      table.rows.length,
                      table.columns.length,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive
                          ? AppTheme.primaryBlue.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isActive
                      ? IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          color: AppTheme.primaryBlue,
                          onPressed: () =>
                              _showTableOptions(context, provider, index),
                          tooltip: AppLocalizations.of(context).moreActions,
                        )
                      : null,
                  onTap: () {
                    provider.changeTable(index);
                    onTabChanged?.call(0); // Tablo tab'ına geç
                    Navigator.pop(context);
                  },
                  onLongPress: () =>
                      _showTableOptions(context, provider, index),
                ),
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
            child: Text(
              AppLocalizations.of(context).tallyEmptyTitle,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
            final dateRange =
                '${table.startDate.day}/${table.startDate.month} - ${table.endDate.day}/${table.endDate.month}';
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive
                    ? Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      )
                    : null,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primaryBlue
                          : Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.grid_on_rounded,
                      color: isActive
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    table.tableName,
                    style: TextStyle(
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isActive
                          ? AppTheme.primaryBlue
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${table.items.length} ${AppLocalizations.of(context).tallyItems} • $dateRange',
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive
                          ? AppTheme.primaryBlue.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    provider.changeTable(index);
                    onTabChanged?.call(1); // Çetele tab'ına geç
                    Navigator.pop(context);
                  },
                  onLongPress: () =>
                      _showTallyOptions(context, provider, index),
                  trailing: isActive
                      ? IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          color: AppTheme.primaryBlue,
                          tooltip: AppLocalizations.of(context).moreActions,
                          onPressed: () =>
                              _showTallyOptions(context, provider, index),
                        )
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============== TABLO SEÇENEKLERİ ==============

  void _showTableOptions(
    BuildContext context,
    TableProvider provider,
    int index,
  ) {
    final table = provider.tables[index];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.table_chart_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        table.tableName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.success,
                ),
                title: Text(AppLocalizations.of(context).switchToTable),
                onTap: () {
                  provider.changeTable(index);
                  onTabChanged?.call(0);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.settings_outlined,
                  color: AppTheme.primaryBlue,
                ),
                title: Text(AppLocalizations.of(context).editStructure),
                onTap: () {
                  final navigator = Navigator.of(context);
                  provider.changeTable(index);
                  onTabChanged?.call(0);
                  navigator.pop();
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const EditTableStructureDialog(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.error,
                ),
                title: Text(
                  // Katılınan tablo silinmez, ondan ayrılınır.
                  _joinedTable(provider, index)
                      ? AppLocalizations.of(context).leaveShared
                      : AppLocalizations.of(context).deleteTable,
                  style: const TextStyle(color: AppTheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, provider, index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTallyOptions(
    BuildContext context,
    TallyProvider provider,
    int index,
  ) {
    final table = provider.tables[index];
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.grid_on_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        table.tableName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.success,
                ),
                title: Text(loc.switchToTable),
                onTap: () {
                  provider.changeTable(index);
                  onTabChanged?.call(1);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.settings_outlined,
                  color: AppTheme.primaryBlue,
                ),
                title: Text(loc.edit),
                onTap: () {
                  final navigator = Navigator.of(context);
                  provider.changeTable(index);
                  onTabChanged?.call(1);
                  navigator.pop();
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const EditTallyDialog(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.error,
                ),
                title: Text(
                  _joinedTally(provider, index)
                      ? loc.leaveShared
                      : loc.tallyDeleteTable,
                  style: const TextStyle(color: AppTheme.error),
                ),
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

  bool _joinedTable(TableProvider provider, int index) {
    final id = provider.tables[index].id;
    return provider.isSharedTable(id) && !provider.isSharedOwner(id);
  }

  bool _joinedTally(TallyProvider provider, int index) {
    final id = provider.tables[index].id;
    return provider.isSharedTally(id) && !provider.isSharedOwner(id);
  }

  void _showDeleteConfirmation(
    BuildContext context,
    TableProvider provider,
    int index,
  ) {
    final table = provider.tables[index];
    if (_joinedTable(provider, index)) {
      leaveSharedTableFlow(
        context,
        tableId: table.id,
        tableName: table.tableName,
        isTally: false,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppTheme.error),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).deleteTable),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).deleteTableConfirm(table.tableName),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.coloredCardDecoration(AppTheme.error),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).nRecordsPermanentDelete(table.rows.length),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () async {
              await provider.deleteTable(index);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
  }

  void _showDeleteTallyConfirmation(
    BuildContext context,
    TallyProvider provider,
    int index,
  ) {
    final table = provider.tables[index];
    if (_joinedTally(provider, index)) {
      leaveSharedTableFlow(
        context,
        tableId: table.id,
        tableName: table.tableName,
        isTally: true,
      );
      return;
    }
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () async {
              await provider.deleteTable(index);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  // ============== FOOTER ==============

  Widget _buildFooter(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    final atLimit =
                        context.read<TableProvider>().tables.length >=
                        PlanLimits.freeTables;
                    if (!context.read<SubscriptionProvider>().isPremium &&
                        atLimit) {
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => const PremiumScreen(),
                        ),
                      );
                      return;
                    }
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const CreateTableDialog(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.table_chart_rounded, size: 18),
                  label: Text(
                    loc.newTable,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    final atLimit =
                        context.read<TallyProvider>().tables.length >=
                        PlanLimits.freeTallies;
                    if (!context.read<SubscriptionProvider>().isPremium &&
                        atLimit) {
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => const PremiumScreen(),
                        ),
                      );
                      return;
                    }
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const CreateTallyDialog(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.grid_on_rounded, size: 18),
                  label: Text(
                    loc.tallyCreate,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const TemplateManagementDialog(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.article_outlined, size: 16),
                  label: Text(
                    loc.templates,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const TallyTemplateManagementDialog(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.article_outlined, size: 16),
                  label: Text(
                    loc.tallyTemplates,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Katilan kisinin hesabi ve Premium'u yok, yani bulut ekranindan
          // geciremez; giris noktasi burada olmali.
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => const JoinSharedTableScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.group_add_outlined, size: 20),
              label: Text(loc.joinTable),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings_outlined, size: 20),
              label: Text(loc.settings),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
