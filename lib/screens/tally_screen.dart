import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/tally_model.dart';
import '../providers/tally_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_tally_dialog.dart';
import '../widgets/tally_summary_dialog.dart';

class TallyScreen extends StatefulWidget {
  const TallyScreen({Key? key}) : super(key: key);

  @override
  State<TallyScreen> createState() => _TallyScreenState();
}

class _TallyScreenState extends State<TallyScreen> {
  // Yatay: gün başlıkları, gün hücreleri gövdesini takip eder (tek yön sync)
  final ScrollController _bodyHScroll = ScrollController();
  final ScrollController _headerHScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _bodyHScroll.addListener(_syncHeaderH);
  }

  void _syncHeaderH() {
    if (_headerHScroll.hasClients && _headerHScroll.offset != _bodyHScroll.offset) {
      _headerHScroll.jumpTo(_bodyHScroll.offset);
    }
  }

  @override
  void dispose() {
    _bodyHScroll.dispose();
    _headerHScroll.dispose();
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
        return Column(
          children: [
            _buildHeader(context, table, loc),
            _buildStatusLegend(table),
            Expanded(child: _buildGrid(context, table, provider)),
            _buildBottomBar(context, provider, loc),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grid_on_rounded, size: 64, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 24),
            Text(loc.tallyEmptyTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(loc.tallyEmptySubtitle, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.menu_rounded, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(loc.openMenuToCreate,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TallyTableModel table, AppLocalizations loc) {
    final dateFormat = '${table.startDate.day}/${table.startDate.month}/${table.startDate.year}'
        ' - ${table.endDate.day}/${table.endDate.month}/${table.endDate.year}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.lightBlue, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.grid_on_rounded, color: AppTheme.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(table.tableName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(dateFormat, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('${table.items.length} ${loc.tallyItems} • ${table.dayCount} ${loc.tallyDays}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryBlue),
            tooltip: loc.edit,
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend(TallyTableModel table) {
    if (table.statuses.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: table.statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = table.statuses[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(s.colorValue).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(s.colorValue).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(s.colorValue), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('${s.code} - ${s.label}', style: TextStyle(fontSize: 11, color: Color(s.colorValue), fontWeight: FontWeight.w600)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(BuildContext context, TallyTableModel table, TallyProvider provider) {
    final days = table.allDays;
    final items = table.items;

    if (items.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).tallyNoItems, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
      );
    }

    const double seqColWidth = 36;
    const double nameColWidth = 120;
    const double dayColWidth = 44;
    const double rowHeight = 44;
    const double headerHeight = 48;

    Widget seqCell(int itemIndex) {
      return Container(
        width: seqColWidth,
        height: rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: itemIndex.isEven ? Colors.white : AppTheme.background,
          border: Border(
            bottom: BorderSide(color: AppTheme.divider.withValues(alpha: 0.3)),
            right: BorderSide(color: AppTheme.divider.withValues(alpha: 0.3)),
          ),
        ),
        child: Text(
          '${itemIndex + 1}',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
      );
    }

    Widget nameCell(int itemIndex, TallyItemModel item) {
      return GestureDetector(
        onTap: () => _showSummary(context, provider, itemIndex),
        onLongPress: () => _showItemOptions(context, provider, itemIndex, item),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: nameColWidth,
          height: rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: itemIndex.isEven ? Colors.white : AppTheme.background,
            border: Border(bottom: BorderSide(color: AppTheme.divider.withValues(alpha: 0.3))),
          ),
          child: Text(item.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      );
    }

    Widget dayHeaderCell(DateTime day) {
      return Container(
        width: dayColWidth,
        height: headerHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.divider.withValues(alpha: 0.5))),
          color: day.weekday >= 6 ? Colors.orange.withValues(alpha: 0.08) : AppTheme.lightBlue,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkBlue)),
            Text(_shortDayName(day, context),
                style: TextStyle(
                    fontSize: 9,
                    color: day.weekday >= 6 ? Colors.orange : AppTheme.textSecondary)),
          ],
        ),
      );
    }

    Widget dayCell(int itemIndex, DateTime day) {
      final key = TallyTableModel.dateKey(day);
      final code = items[itemIndex].entries[key];
      final status = code != null ? table.getStatusByCode(code) : null;

      return GestureDetector(
        onTap: () => provider.cycleCellStatus(itemIndex, day),
        onLongPress: () => _showStatusPicker(context, provider, itemIndex, day),
        child: Container(
          width: dayColWidth,
          height: rowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: AppTheme.divider.withValues(alpha: 0.3))),
            color: status != null ? Color(status.colorValue).withValues(alpha: 0.15) : null,
          ),
          child: status != null
              ? Text(status.code,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(status.colorValue),
                  ))
              : null,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))
        ],
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
                    decoration: const BoxDecoration(
                      color: AppTheme.lightBlue,
                      border: Border(
                        right: BorderSide(color: Color(0x33000000), width: 0.5),
                      ),
                    ),
                    child: const Text(
                      '#',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.darkBlue),
                    ),
                  ),
                  // İsim başlığı (sticky)
                  Container(
                    width: nameColWidth,
                    height: headerHeight,
                    color: AppTheme.lightBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppLocalizations.of(context).tallyItemHeader,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.darkBlue),
                    ),
                  ),
                  // Gün başlıkları (yatay scroll, gövdeyi takip eder)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _headerHScroll,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: days.map(dayHeaderCell).toList(),
                      ),
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
                                color: AppTheme.divider.withValues(alpha: 0.6), width: 1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(2, 0),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: seqColWidth,
                              child: Column(
                                children: [
                                  for (int i = 0; i < items.length; i++) seqCell(i),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: nameColWidth,
                              child: Column(
                                children: [
                                  for (int i = 0; i < items.length; i++) nameCell(i, items[i]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sağ: günler (yatay scroll). Dikey scroll dışarıdan geliyor.
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _bodyHScroll,
                          child: SizedBox(
                            width: days.length * dayColWidth,
                            child: Column(
                              children: [
                                for (int itemIndex = 0; itemIndex < items.length; itemIndex++)
                                  Container(
                                    height: rowHeight,
                                    decoration: BoxDecoration(
                                      color: itemIndex.isEven
                                          ? Colors.white
                                          : AppTheme.background,
                                      border: Border(
                                          bottom: BorderSide(
                                              color: AppTheme.divider.withValues(alpha: 0.3))),
                                    ),
                                    child: Row(
                                      children: days.map((day) => dayCell(itemIndex, day)).toList(),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, TallyProvider provider, AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton.icon(
          onPressed: () => _showAddItemDialog(context, provider, loc),
          icon: const Icon(Icons.add_rounded),
          label: Text(loc.tallyAddItem),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  // ============== DİALOGLAR ==============

  void _showEditDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const EditTallyDialog());
  }

  void _showAddItemDialog(BuildContext context, TallyProvider provider, AppLocalizations loc) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tallyAddItem),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: loc.tallyItemName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await provider.addItem(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: Text(loc.add),
          ),
        ],
      ),
    );
  }

  void _showSummary(BuildContext context, TallyProvider provider, int itemIndex) {
    showDialog(
      context: context,
      builder: (_) => TallySummaryDialog(itemIndex: itemIndex),
    );
  }

  void _showItemOptions(BuildContext context, TallyProvider provider, int itemIndex, TallyItemModel item) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded, color: AppTheme.primaryBlue),
              title: Text(loc.tallySummary),
              onTap: () { Navigator.pop(ctx); _showSummary(context, provider, itemIndex); },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primaryBlue),
              title: Text(loc.tallyRenameItem),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameItemDialog(context, provider, itemIndex, item.name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppTheme.error),
              title: Text(loc.tallyDeleteItem, style: const TextStyle(color: AppTheme.error)),
              onTap: () async {
                Navigator.pop(ctx);
                await provider.removeItem(itemIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameItemDialog(BuildContext context, TallyProvider provider, int itemIndex, String currentName) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tallyRenameItem),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: loc.tallyItemName, border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await provider.renameItem(itemIndex, controller.text);
                Navigator.pop(ctx);
              }
            },
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }

  void _showStatusPicker(BuildContext context, TallyProvider provider, int itemIndex, DateTime date) {
    final table = provider.currentTable!;
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...table.statuses.map((s) => ListTile(
                  leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: Color(s.colorValue), borderRadius: BorderRadius.circular(6)),
                      child: Center(child: Text(s.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
                  title: Text(s.label),
                  onTap: () { Navigator.pop(ctx); provider.setCellStatus(itemIndex, date, s.code); },
                )),
            ListTile(
              leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                  child: const Center(child: Icon(Icons.close, size: 18, color: Colors.grey))),
              title: Text(loc.tallyClear),
              onTap: () { Navigator.pop(ctx); provider.setCellStatus(itemIndex, date, null); },
            ),
            const SizedBox(height: 8),
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
