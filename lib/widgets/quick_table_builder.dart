import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/tabel_model.dart';
import '../providers/subscription_provider.dart';
import '../providers/table_provider.dart';
import '../utils/number_display.dart';
import 'code_column_note.dart';
import 'create_table_dialog.dart';
import 'template_management_dialog.dart';

/// Tabloyu tablonun üstünde kurmak: ekranda kurulan tablonun başlık satırı
/// durur, sonundaki + her basışta bir sütun ekler.
///
/// Sütunun kendisi klasik sütun formuyla ([CreateTableDialog.showColumn])
/// tanımlanır: ad, tip ve ayarlar alttan açılan bir kâğıtta, tablo arkada
/// görünürken girilir. Başlığa dokunmak o sütunun formunu yeniden açar;
/// başlığa basılı tutup sürüklemek sütunun yerini değiştirir.
class QuickTableBuilder extends StatefulWidget {
  const QuickTableBuilder({super.key});

  @override
  State<QuickTableBuilder> createState() => _QuickTableBuilderState();
}

class _QuickTableBuilderState extends State<QuickTableBuilder> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _scroll = ScrollController();
  final _columns = <ColumnModel>[];

  String? _nameError;
  String? _columnError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<ColumnFormResult?> _openColumnForm({int? editing}) {
    FocusManager.instance.primaryFocus?.unfocus();
    return CreateTableDialog.showColumn(
      context,
      column: editing == null ? null : _columns[editing],
      siblings: [
        for (var index = 0; index < _columns.length; index++)
          if (index != editing) _columns[index],
      ],
      columnNumber: (editing ?? _columns.length) + 1,
    );
  }

  Future<void> _addColumn() async {
    final result = await _openColumnForm();
    final column = result?.column;
    if (!mounted || column == null) return;
    setState(() {
      _columns.add(column);
      _columnError = null;
    });
    // Yeni başlık ve + görünür kalsın.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _editColumn(int index) async {
    final result = await _openColumnForm(editing: index);
    if (!mounted || result == null) return;
    setState(() {
      if (result.removed) {
        _columns.removeAt(index);
      } else {
        _columns[index] = result.column!;
      }
    });
  }

  Future<void> _create() async {
    if (_saving) return;
    final loc = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = loc.tableNameEmpty);
      _nameFocus.requestFocus();
      return;
    }
    if (_columns.isEmpty) {
      setState(() => _columnError = loc.quickNeedColumn);
      return;
    }
    final tables = context.read<TableProvider>();
    // Premium ya da sınırlardan önceki sürümden gelen kullanıcı.
    final isPremium = context.read<SubscriptionProvider>().hasUnlimitedPlan;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final created = await tables.createTable(
      name,
      _columns,
      isPremium: isPremium,
    );
    if (!mounted) return;
    if (created) {
      navigator.pop();
    } else {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(loc.tableCreateFailed)));
    }
  }

  void _openTemplates() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const TemplateManagementDialog(),
      ),
    );
  }

  /// Başlığın altında sütunun ne tuttuğu yazar.
  String _note(AppLocalizations loc, ColumnModel column) {
    final language = loc.locale.languageCode;
    return switch (column.columnType) {
      ColumnType.constant => loc.kindConstantNote(
        formatGroupedNumber(column.constantValue ?? 0, language),
      ),
      ColumnType.formula => loc.kindFormulaNote,
      ColumnType.date => loc.kindDateNote,
      ColumnType.time => loc.kindTimeNote,
      ColumnType.autoNumber => loc.kindAutoNumberNote,
      ColumnType.code => loc.kindCodeNote,
      ColumnType.normal =>
        column.isNumeric ? loc.kindNumberNote : loc.kindTextNote,
    };
  }

  IconData _icon(ColumnModel column) => switch (column.columnType) {
    ColumnType.constant => Icons.pin_outlined,
    ColumnType.formula => Icons.functions,
    ColumnType.date => Icons.calendar_today_outlined,
    ColumnType.time => Icons.access_time,
    ColumnType.autoNumber => Icons.format_list_numbered,
    ColumnType.code => codeColumnIcon,
    ColumnType.normal =>
      column.isNumeric ? Icons.tag_rounded : Icons.notes_rounded,
  };

  /// Kayıt eklenince hücrede ne görüneceğinin örneği.
  String _sample(AppLocalizations loc, ColumnModel column) {
    final now = DateTime.now();
    final language = loc.locale.languageCode;
    String two(int value) => value.toString().padLeft(2, '0');
    return switch (column.columnType) {
      ColumnType.constant => formatGroupedNumber(
        column.constantValue ?? 0,
        language,
      ),
      ColumnType.formula => '=',
      ColumnType.date => '${two(now.day)}.${two(now.month)}.${now.year}',
      ColumnType.time => '${two(now.hour)}:${two(now.minute)}',
      ColumnType.autoNumber => '1',
      ColumnType.code => '0012',
      ColumnType.normal => column.isNumeric ? '123' : loc.quickSampleText,
    };
  }

  Widget _headerCell(BuildContext context, int index) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final column = _columns[index];
    return InkWell(
      key: ValueKey('quick-column-$index'),
      onTap: _saving ? null : () => _editColumn(index),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              column.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon(column), size: 12, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  _note(loc, column),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _moveColumn(int from, int to) {
    setState(() => _columns.insert(to, _columns.removeAt(from)));
  }

  /// Kurulan tablo: başlıklar, altlarında örnek bir kayıt ve sonda +.
  /// Başlığa basılı tutup sürükleyince sütunun yeri değişir.
  Widget _table(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final divider = BorderSide(color: colors.outlineVariant);
    // Yazı büyütülünce hücreler de büyür.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final headerHeight = 58 * scale;
    final sampleHeight = 44 * scale;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            height: headerHeight + sampleHeight,
            child: ReorderableListView.builder(
              key: const ValueKey('quick-table'),
              scrollController: _scroll,
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              // Her platformda aynı: basılı tut, sürükle.
              buildDefaultDragHandles: false,
              onReorderItem: _moveColumn,
              itemCount: _columns.length,
              itemBuilder: (context, index) {
                final column = _columns[index];
                return ReorderableDelayedDragStartListener(
                  // Sütun adları tekildir; sıra değişince öğe adıyla izlenir.
                  key: ValueKey('quick-item-${column.name}'),
                  index: index,
                  enabled: !_saving && _columns.length > 1,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: headerHeight,
                          child: Ink(
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              border: Border(right: divider),
                            ),
                            child: _headerCell(context, index),
                          ),
                        ),
                        SizedBox(
                          height: sampleHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              border: Border(right: divider),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  _sample(loc, column),
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              // Her basış sona bir sütun ekler.
              footer: Ink(
                color: colors.primaryContainer.withValues(alpha: 0.45),
                child: InkWell(
                  key: const ValueKey('quick-add-column'),
                  onTap: _saving ? null : _addColumn,
                  child: Tooltip(
                    message: loc.addColumn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: colors.primary,
                            size: 26,
                          ),
                          if (_columns.isEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              loc.addColumn,
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        // Uygulamadaki diğer form ekranlarıyla aynı görünüm.
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        titleSpacing: 0,
        title: Text(
          loc.newTable,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  TextField(
                    key: const ValueKey('quick-table-name'),
                    controller: _name,
                    focusNode: _nameFocus,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    decoration: InputDecoration(
                      labelText: loc.tableName,
                      hintText: loc.tableNameHint,
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _table(context),
                  ),
                  const SizedBox(height: 10),
                  if (_columnError != null)
                    Text(
                      _columnError!,
                      key: const ValueKey('quick-column-error'),
                      style: TextStyle(color: colors.error, fontSize: 13),
                    )
                  else
                    Text(
                      _columns.isEmpty
                          ? loc.quickEmptyHint
                          : _columns.length == 1
                          ? loc.quickMoreHint
                          : '${loc.quickMoreHint} ${loc.quickReorderHint}',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('quick-templates'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: _saving ? null : _openTemplates,
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: Text(loc.startFromExample),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                key: const ValueKey('quick-create'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _saving ? null : _create,
                icon: const Icon(Icons.check_rounded),
                label: Text(loc.createTable),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
