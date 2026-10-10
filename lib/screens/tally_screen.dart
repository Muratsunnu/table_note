import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/backup_reminder.dart';
import '../widgets/compact_layout.dart';
import '../widgets/edit_access.dart';
import '../widgets/leave_shared_table.dart';
import '../l10n/app_localizations.dart';
import '../models/tally_model.dart';
import '../models/overview_grid.dart';
import '../models/tally_sort_preference.dart';
import '../providers/tally_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_tally_dialog.dart';
import '../widgets/add_tally_item_dialog.dart';
import '../widgets/table_section_header.dart';
import '../widgets/tally_summary_dialog.dart';
import '../widgets/tally_overall_summary_dialog.dart';
import '../widgets/tally_bulk_edit_dialog.dart';
import '../widgets/create_tally_dialog.dart';
import '../widgets/grid_overview_screen.dart';
import 'premium_screen.dart';
import '../widgets/shared_sync_indicator.dart';

class TallyScreen extends StatefulWidget {
  const TallyScreen({Key? key}) : super(key: key);

  @override
  State<TallyScreen> createState() => _TallyScreenState();
}

class _TallyScreenState extends State<TallyScreen> {
  // Yatay: gün başlıkları, gün hücreleri gövdesini takip eder (tek yön sync)
  final ScrollController _bodyHScroll = ScrollController();
  final ScrollController _headerHScroll = ScrollController();
  final TextEditingController _itemSearchController = TextEditingController();
  final FocusNode _itemSearchFocus = FocusNode();
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _bodyHScroll.addListener(_syncHeaderH);
  }

  void _syncHeaderH() {
    if (_headerHScroll.hasClients &&
        _headerHScroll.offset != _bodyHScroll.offset) {
      _headerHScroll.jumpTo(_bodyHScroll.offset);
    }
  }

  @override
  void dispose() {
    _bodyHScroll.dispose();
    _headerHScroll.dispose();
    _itemSearchController.dispose();
    _itemSearchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Consumer<TallyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!provider.hasTables) {
          return _buildEmptyState(context, loc);
        }

        final table = provider.currentTable!;
        // Yan çevrilmiş telefonda başlık tek satıra iner, durum etiketleri
        // araç satırına katılır; kayıt ekleme düğmesi yandaki çubuktadır.
        final compact = isCompactHeight(context);
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
                      _buildHeader(
                        context,
                        table,
                        provider,
                        loc,
                        compact: compact,
                      ),
                      if (!compact) _buildStatusLegend(table),
                      _buildQuickTools(
                        context,
                        provider,
                        trailing: compact ? _statusChips(table) : const [],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildGrid(context, table, provider)),
              if (!compact) _buildBottomBar(context, provider, loc),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations loc) {
    return Center(
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.grid_on_rounded,
                size: 64,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc.tallyEmptyTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.tallyEmptySubtitle,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const CreateTallyDialog(),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(loc.tallyCreate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    TallyTableModel table,
    TallyProvider provider,
    AppLocalizations loc, {
    bool compact = false,
  }) {
    final material = MaterialLocalizations.of(context);
    final dateFormat =
        '${material.formatShortDate(table.startDate)} – '
        '${material.formatShortDate(table.endDate)}';

    return TableSectionHeader(
      title: table.tableName,
      summary: loc.nRecords(table.items.length),
      detail: dateFormat,
      compact: compact,
      footer: const BackupStatusLine(),
      // Ortak olmayan cetelede hicbir sey cizmez.
      titleTrailing: const SharedSyncIndicator(isTally: true),
      actions: [
        IconButton(
          tooltip: loc.locale.languageCode == 'en'
              ? 'Whole tally'
              : 'Çetelenin tamamı',
          icon: const Icon(Icons.zoom_out_map_rounded),
          // Always the whole tally in the on-screen order, search aside.
          onPressed: () => GridOverviewScreen.open(
            context,
            buildTallyOverview(
              table,
              provider.sortedItemIndices,
              language: loc.locale.languageCode,
              itemHeader: loc.tallyItemHeader,
              today: DateTime.now(),
            ),
          ),
        ),
        IconButton(
          tooltip: _isSearchOpen ? loc.closeSearch : loc.searchPersonOrItem,
          isSelected: _isSearchOpen,
          icon: const Icon(Icons.search_rounded),
          selectedIcon: const Icon(Icons.search_off_rounded),
          onPressed: () => _toggleSearch(provider),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded),
          tooltip: loc.moreActions,
          onSelected: (value) {
            if (value == 'summary') {
              _runPremium(
                () => showDialog(
                  context: context,
                  builder: (_) => const TallyOverallSummaryDialog(),
                ),
              );
            } else if (value == 'reorder') {
              _runPremium(() => _showReorderDialog(context));
            } else if (value == 'edit') {
              _showEditDialog(context);
            } else if (value == 'delete') {
              _showDeleteDialog(context, provider);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'summary', child: Text(loc.overallSummary)),
            PopupMenuItem(value: 'reorder', child: Text(loc.reorderRows)),
            PopupMenuItem(value: 'edit', child: Text(loc.edit)),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  // Katılınan çetele silinmez, ondan ayrılınır.
                  Icon(
                    _isJoined(provider)
                        ? Icons.logout_rounded
                        : Icons.delete_outline,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isJoined(provider) ? loc.leaveShared : loc.delete,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// [trailing] araçların yanına, aynı kaydırılabilir satıra eklenir.
  Widget _buildQuickTools(
    BuildContext context,
    TallyProvider provider, {
    List<Widget> trailing = const [],
  }) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          if (_isSearchOpen) ...[
            TextField(
              controller: _itemSearchController,
              focusNode: _itemSearchFocus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _itemSearchFocus.unfocus(),
              onChanged: provider.setItemSearchQuery,
              decoration: InputDecoration(
                hintText: loc.searchPersonOrItem,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: loc.closeSearch,
                  onPressed: () => _toggleSearch(provider),
                  icon: const Icon(Icons.close_rounded),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Yalnızca görüntüleyen kişide işaretleme araçları durmaz.
                  if (provider.canEditCurrent) ...[
                    FilledButton.tonalIcon(
                      onPressed: () => _runPremium(
                        () => showDialog(
                          context: context,
                          builder: (_) => const TallyBulkEditDialog(),
                        ),
                      ),
                      icon: const Icon(Icons.select_all_rounded),
                      label: Text(loc.bulkMark),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: provider.canUndo
                          ? provider.undoLastEdit
                          : null,
                      tooltip: loc.undoLastAction,
                      icon: const Icon(Icons.undo_rounded),
                    ),
                    IconButton(
                      onPressed: provider.canRedo
                          ? provider.redoLastEdit
                          : null,
                      tooltip: loc.redoLastAction,
                      icon: const Icon(Icons.redo_rounded),
                    ),
                  ],
                  _buildSortMenu(context, provider),
                  if (trailing.isNotEmpty) const SizedBox(width: 8),
                  ...trailing,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ad ya da bir durumun sayısına göre sıralama. Etkin sıralama, simgedeki
  /// noktadan ve menüdeki işaretten anlaşılır.
  Widget _buildSortMenu(BuildContext context, TallyProvider provider) {
    final table = provider.currentTable;
    if (table == null) return const SizedBox.shrink();
    final tr = AppLocalizations.of(context).locale.languageCode != 'en';
    final current = provider.currentSort;
    final options = <(String, TallySortPreference?)>[
      (tr ? 'Elle belirlenen sıra' : 'Custom order', null),
      (
        tr ? 'İsim (A → Z)' : 'Name (A → Z)',
        const TallySortPreference.byName(ascending: true),
      ),
      (
        tr ? 'İsim (Z → A)' : 'Name (Z → A)',
        const TallySortPreference.byName(ascending: false),
      ),
      for (final status in table.statuses) ...[
        (
          tr ? 'En çok: ${status.label}' : 'Most: ${status.label}',
          TallySortPreference.byStatus(status.code, ascending: false),
        ),
        (
          tr ? 'En az: ${status.label}' : 'Fewest: ${status.label}',
          TallySortPreference.byStatus(status.code, ascending: true),
        ),
      ],
    ];
    return PopupMenuButton<int>(
      tooltip: tr ? 'Sırala' : 'Sort',
      icon: Badge(
        isLabelVisible: current != null,
        smallSize: 8,
        // Red would read as an error; this only says "a sort is on".
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(
          Icons.sort_rounded,
          color: current != null ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      onSelected: (index) => provider.setSort(options[index].$2),
      itemBuilder: (context) => [
        for (var i = 0; i < options.length; i++)
          CheckedPopupMenuItem<int>(
            value: i,
            checked: options[i].$2 == current,
            child: Text(options[i].$1),
          ),
      ],
    );
  }

  void _toggleSearch(TallyProvider provider) {
    if (_isSearchOpen) {
      _itemSearchFocus.unfocus();
      _itemSearchController.clear();
      setState(() => _isSearchOpen = false);
      provider.setItemSearchQuery('');
    } else {
      setState(() => _isSearchOpen = true);
      _itemSearchFocus.requestFocus();
    }
  }

  void _runPremium(VoidCallback action) {
    if (context.read<SubscriptionProvider>().isPremium) {
      action();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
    }
  }

  Widget _buildStatusLegend(TallyTableModel table) {
    if (table.statuses.isEmpty) return const SizedBox();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _statusChips(table)),
      ),
    );
  }

  List<Widget> _statusChips(TallyTableModel table) {
    return [
      for (final s in table.statuses)
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Color(s.colorValue).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color(s.colorValue).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.readableAccent(context, Color(s.colorValue)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${s.code} - ${s.label}',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(s.colorValue),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildGrid(
    BuildContext context,
    TallyTableModel table,
    TallyProvider provider,
  ) {
    final days = table.allDays;
    final items = table.items;
    final itemIndices = provider.filteredItemIndices;
    final gridLineColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.55);

    if (itemIndices.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).tallyNoItems,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 15,
          ),
        ),
      );
    }

    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final seqColWidth = 36 * scale.clamp(1.0, 1.5);
    final nameColWidth = (MediaQuery.sizeOf(context).width * .30).clamp(
      88.0,
      160.0,
    );
    final dayColWidth = 48 * scale.clamp(1.0, 2.0);
    // Yüksekliği dar ekranda satırlar alçalır; dokunma alanı 44'ün altına inmez.
    final compact = isCompactHeight(context);
    final rowHeight = (compact ? 44 : 52) * scale.clamp(1.0, 3.0);
    final headerHeight = (compact ? 40 : 52) * scale.clamp(1.0, 3.0);

    Widget seqCell(int itemIndex) {
      return Container(
        width: seqColWidth,
        height: rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.tableRowColor(context, itemIndex),
          border: Border(
            bottom: BorderSide(color: gridLineColor, width: 0.6),
            right: BorderSide(color: gridLineColor, width: 0.6),
          ),
        ),
        child: Text(
          '${itemIndex + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    Widget nameCell(int visibleIndex, int itemIndex, TallyItemModel item) {
      return GestureDetector(
        onTap: () => _showSummary(context, provider, itemIndex),
        // Ad değiştirme ve silme yalnızca düzenleyebilen kişide.
        onLongPress: provider.canEditCurrent
            ? () => _showItemOptions(context, provider, itemIndex, item)
            : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: nameColWidth,
          height: rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppTheme.tableRowColor(context, visibleIndex),
            border: Border(
              bottom: BorderSide(color: gridLineColor, width: 0.6),
            ),
          ),
          child: Text(
            item.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    Widget dayHeaderCell(DateTime day) {
      final today = DateTime.now();
      final isToday =
          day.year == today.year &&
          day.month == today.month &&
          day.day == today.day;
      return Container(
        width: dayColWidth,
        height: headerHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: gridLineColor, width: 0.6)),
          color: isToday
              ? Colors.amber.withValues(alpha: 0.35)
              : day.weekday >= 6
              ? Colors.orange.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              _shortDayName(day, context),
              style: TextStyle(
                fontSize: 9,
                color: day.weekday >= 6
                    ? Colors.orange
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    Widget dayCell(int itemIndex, DateTime day) {
      final key = TallyTableModel.dateKey(day);
      final code = items[itemIndex].entries[key];
      final status = code != null ? table.getStatusByCode(code) : null;
      final today = DateTime.now();
      final isToday =
          day.year == today.year &&
          day.month == today.month &&
          day.day == today.day;

      return Semantics(
        button: true,
        label:
            '${items[itemIndex].name}, '
            '${MaterialLocalizations.of(context).formatFullDate(day)}, '
            '${status?.label ?? AppLocalizations.of(context).tallyClear}',
        onTap: () =>
            _editCell(provider, () => provider.cycleCellStatus(itemIndex, day)),
        onLongPress: () => _editCell(
          provider,
          () => _showStatusPicker(context, provider, itemIndex, day),
        ),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => _editCell(
            provider,
            () => provider.cycleCellStatus(itemIndex, day),
          ),
          onLongPress: () => _editCell(
            provider,
            () => _showStatusPicker(context, provider, itemIndex, day),
          ),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: dayColWidth,
            height: rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: gridLineColor, width: 0.6),
              ),
              color: status != null
                  ? Color(status.colorValue).withValues(alpha: 0.15)
                  : isToday
                  ? Colors.amber.withValues(alpha: 0.12)
                  : null,
            ),
            child: status != null
                ? Text(
                    status.code,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.readableAccent(
                        context,
                        Color(status.colorValue),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      );
    }

    return MinHeightClip(
      minHeight: headerHeight + rowHeight + 16,
      child: Container(
        margin: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // === ÜST BAŞLIK SATIRI (dikey kaymaz) ===
              SizedBox(
                height: headerHeight,
                child: Row(
                  children: [
                    // Sıra başlığı (sticky)
                    Container(
                      width: seqColWidth,
                      height: headerHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        border: Border(
                          right: BorderSide(color: gridLineColor, width: 0.6),
                        ),
                      ),
                      child: Text(
                        '#',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    // İsim başlığı (sticky); dokununca ada göre sıralar.
                    Material(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: InkWell(
                        onTap: provider.toggleNameSort,
                        child: Container(
                          width: nameColWidth,
                          height: headerHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  AppLocalizations.of(context).tallyItemHeader,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              if (provider.currentSort?.isByName ?? false) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  provider.currentSort!.ascending
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Gün başlıkları (yatay scroll, gövdeyi takip eder)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _headerHScroll,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Row(children: days.map(dayHeaderCell).toList()),
                      ),
                    ),
                  ],
                ),
              ),
              // === GÖVDE: TEK DİKEY SCROLL (her iki sütunu da kapsar) ===
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sol: sabit sıra + isim sütunları (yatay kaymaz)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: gridLineColor,
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: seqColWidth,
                                child: Column(
                                  children: [
                                    for (int i = 0; i < itemIndices.length; i++)
                                      seqCell(i),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: nameColWidth,
                                child: Column(
                                  children: [
                                    for (int i = 0; i < itemIndices.length; i++)
                                      nameCell(
                                        i,
                                        itemIndices[i],
                                        items[itemIndices[i]],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Sağ: günler (yatay scroll). Dikey scroll dışarıdan geliyor.
                        Expanded(
                          child: Scrollbar(
                            controller: _bodyHScroll,
                            thumbVisibility: days.length > 5,
                            scrollbarOrientation: ScrollbarOrientation.bottom,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _bodyHScroll,
                              child: SizedBox(
                                width: days.length * dayColWidth,
                                child: Column(
                                  children: [
                                    for (int i = 0; i < itemIndices.length; i++)
                                      Container(
                                        height: rowHeight,
                                        decoration: BoxDecoration(
                                          color: AppTheme.tableRowColor(
                                            context,
                                            i,
                                          ),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: gridLineColor,
                                              width: 0.6,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: days
                                              .map(
                                                (day) => dayCell(
                                                  itemIndices[i],
                                                  day,
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildBottomBar(
    BuildContext context,
    TallyProvider provider,
    AppLocalizations loc,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        // Yalnızca görüntüleyen kişide öğe eklenmez; aynı yerde yetki istenir.
        child: provider.canEditCurrent
            ? FilledButton.icon(
                onPressed: () => _showAddItemDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(loc.tallyAddItem),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : SizedBox(
                width: double.infinity,
                child: RequestEditAccessButton(
                  tableId: provider.currentTable!.id,
                ),
              ),
      ),
    );
  }

  /// Hücreye dokunma: düzenleyebilen kişide işaretler, görüntüleyen kişide
  /// neden bir şey olmadığını söyler.
  void _editCell(TallyProvider provider, VoidCallback edit) {
    if (provider.canEditCurrent) {
      edit();
    } else {
      showViewOnlyNotice(context, tableId: provider.currentTable!.id);
    }
  }

  // ============== DİALOGLAR ==============

  void _showEditDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const EditTallyDialog(),
      ),
    );
  }

  /// Açık çetele kodla katılınmış bir çetele mi (sahibi başkası).
  bool _isJoined(TallyProvider provider) {
    final table = provider.currentTable;
    return table != null &&
        provider.isSharedTally(table.id) &&
        !provider.isSharedOwner(table.id);
  }

  void _showDeleteDialog(BuildContext context, TallyProvider provider) {
    final loc = AppLocalizations.of(context);
    final table = provider.currentTable!;
    if (_isJoined(provider)) {
      leaveSharedTableFlow(
        context,
        tableId: table.id,
        tableName: table.tableName,
        isTally: true,
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.tallyDeleteTable),
        content: Text(loc.deleteTableConfirm(table.tableName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          FilledButton(
            // Pencere önce kapanır: ikinci bir dokunuş başka bir kaydı silemez.
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.deleteTable(provider.currentIndex);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const AddTallyItemDialog(),
    );
  }

  void _showSummary(
    BuildContext context,
    TallyProvider provider,
    int itemIndex,
  ) {
    showDialog(
      context: context,
      builder: (_) => TallySummaryDialog(itemIndex: itemIndex),
    );
  }

  void _showItemOptions(
    BuildContext context,
    TallyProvider provider,
    int itemIndex,
    TallyItemModel item,
  ) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.bar_chart_rounded,
                color: AppTheme.primaryBlue,
              ),
              title: Text(loc.tallySummary),
              onTap: () {
                Navigator.pop(ctx);
                _showSummary(context, provider, itemIndex);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.edit_rounded,
                color: AppTheme.primaryBlue,
              ),
              title: Text(loc.tallyRenameItem),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameItemDialog(context, provider, itemIndex, item.name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppTheme.error),
              title: Text(
                loc.tallyDeleteItem,
                style: const TextStyle(color: AppTheme.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                _showDeleteItemDialog(context, provider, itemIndex, item.name);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameItemDialog(
    BuildContext context,
    TallyProvider provider,
    int itemIndex,
    String currentName,
  ) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: currentName);
    String? fieldError;
    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(loc.tallyRenameItem),
          content: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (_) {
              if (fieldError != null) {
                setDialogState(() => fieldError = null);
              }
            },
            decoration: InputDecoration(
              labelText: loc.tallyItemName,
              errorText: fieldError,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) {
                  setDialogState(() => fieldError = loc.recordNameRequired);
                  return;
                }
                await provider.renameItem(itemIndex, controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(loc.save),
            ),
          ],
        ),
      ),
    );
    Navigator.of(context, rootNavigator: true).push(route);
    route.completed.whenComplete(controller.dispose);
  }

  void _showDeleteItemDialog(
    BuildContext context,
    TallyProvider provider,
    int itemIndex,
    String name,
  ) {
    final loc = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.tallyDeleteItem),
        content: Text(loc.tallyDeleteItemConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            // Pencere önce kapanır: ikinci bir dokunuş başka bir kaydı silemez.
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.removeItem(itemIndex);
            },
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  void _showStatusPicker(
    BuildContext context,
    TallyProvider provider,
    int itemIndex,
    DateTime date,
  ) {
    final table = provider.currentTable!;
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${date.day}/${date.month}/${date.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ...table.statuses.map(
              (s) => ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(s.colorValue),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      s.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                title: Text(s.label),
                onTap: () {
                  Navigator.pop(ctx);
                  provider.setCellStatus(itemIndex, date, s.code);
                },
              ),
            ),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(Icons.close, size: 18, color: Colors.grey),
                ),
              ),
              title: Text(loc.tallyClear),
              onTap: () {
                Navigator.pop(ctx);
                provider.setCellStatus(itemIndex, date, null);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReorderDialog(BuildContext context) {
    final provider = context.read<TallyProvider>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).reorderRows),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width * .8,
            height: 420,
            child: ReorderableListView.builder(
              itemCount: provider.currentTable!.items.length,
              onReorder: (oldIndex, newIndex) async {
                await provider.reorderItem(oldIndex, newIndex);
                setDialogState(() {});
              },
              itemBuilder: (context, index) {
                final item = provider.currentTable!.items[index];
                return ListTile(
                  key: ValueKey(item.id),
                  leading: const Icon(Icons.drag_handle_rounded),
                  title: Text(item.name),
                );
              },
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).done),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDayName(DateTime date, BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    const trDays = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];
    const enDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return isEn ? enDays[date.weekday - 1] : trDays[date.weekday - 1];
  }
}
