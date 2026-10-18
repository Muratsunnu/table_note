import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/plan_limits.dart';
import '../l10n/app_localizations.dart';
import '../models/tabel_model.dart';
import '../providers/subscription_provider.dart';
import '../providers/table_provider.dart';
import '../providers/template_provider.dart';
import '../utils/number_display.dart';
import 'code_column_note.dart';
import 'create_table_dialog.dart';
import 'premium_gate.dart';
import 'shared_structure_locked.dart';
import 'template_management_dialog.dart';

/// Tabloyu tablonun üstünde kurmak: ekranda kurulan tablonun başlık satırı
/// durur, sonundaki + her basışta bir sütun ekler.
///
/// Sütunun kendisi klasik sütun formuyla ([CreateTableDialog.showColumn])
/// tanımlanır: ad, tip ve ayarlar alttan açılan bir kâğıtta, tablo arkada
/// görünürken girilir. Başlığa dokunmak o sütunun formunu yeniden açar;
/// başlığa basılı tutup sürüklemek sütunun yerini değiştirir.
class QuickTableBuilder extends StatefulWidget {
  const QuickTableBuilder({super.key})
    : _target = _BuilderTarget.table,
      template = null;

  /// Aynı ekranla yeni şablon kurmak.
  const QuickTableBuilder.template({super.key})
    : _target = _BuilderTarget.newTemplate,
      template = null;

  /// Açık tablonun yapısını aynı ekranla düzenlemek. Var olan sütunların
  /// adı değişir, yeri sürüklenerek değişir (ortak tabloda değişmez); türü
  /// değişmez ve kaldırılamazlar. Yeni sütunlar eklenip kaldırılabilir.
  const QuickTableBuilder.editTable({super.key})
    : _target = _BuilderTarget.editTable,
      template = null;

  /// Aynı ekranla var olan bir şablonu ya da hazır örneği düzenlemek.
  const QuickTableBuilder.editTemplate({
    super.key,
    required TemplateModel this.template,
  }) : _target = _BuilderTarget.editTemplate;

  final _BuilderTarget _target;

  /// Düzenlenen şablon.
  final TemplateModel? template;

  @override
  State<QuickTableBuilder> createState() => _QuickTableBuilderState();
}

/// Ekranın neyi kurduğu: tablo ya da şablon. Kurma biçimi aynıdır.
enum _BuilderTarget { table, editTable, newTemplate, editTemplate }

class _QuickTableBuilderState extends State<QuickTableBuilder> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _scroll = ScrollController();
  final _columns = <ColumnModel>[];

  /// Her sütunun düzenlenen tablodaki eski sırası; yeni sütunda null.
  /// Kayıtlar sütunlarıyla birlikte taşınır.
  final _origins = <int?>[];

  /// Düzenlenen tablonun en son kaydı: başlıkların altında örnek yerine
  /// gerçek değer görünür.
  List<String>? _lastRow;

  /// Ortak tabloda sunucu hücreleri sırayla eşler; sütunların yeri
  /// değişemez, yeni sütun sona eklenir.
  bool _fixedOrder = false;

  String? _nameError;
  String? _columnError;
  bool _saving = false;

  bool get _isTemplate =>
      widget._target == _BuilderTarget.newTemplate ||
      widget._target == _BuilderTarget.editTemplate;

  bool get _isEditing =>
      widget._target == _BuilderTarget.editTable ||
      widget._target == _BuilderTarget.editTemplate;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    if (template != null) {
      _name.text = template.templateName;
      _columns.addAll(template.columns.map((column) => column.copyWith()));
      _origins.addAll(List.filled(_columns.length, null));
    }
    if (widget._target == _BuilderTarget.editTable) {
      final tables = context.read<TableProvider>();
      final table = tables.currentTable;
      if (table != null) {
        _name.text = table.tableName;
        _columns.addAll(table.columns.map((column) => column.copyWith()));
        _origins.addAll([for (var i = 0; i < _columns.length; i++) i]);
        _lastRow = table.rows.isEmpty ? null : List.of(table.rows.last);
        _fixedOrder = tables.isSharedTable(table.id);
      }
    }
  }

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
      existing: editing != null && _origins[editing] != null,
    );
  }

  Future<void> _addColumn() async {
    final result = await _openColumnForm();
    final column = result?.column;
    if (!mounted || column == null) return;
    setState(() {
      _columns.add(column);
      _origins.add(null);
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
        _origins.removeAt(index);
      } else {
        final oldName = _columns[index].name;
        _columns[index] = result.column!;
        _renameInFormulas(oldName, result.column!.name);
      }
    });
  }

  /// Formüller sütunu adıyla bulur; ad değişince formüller de onu izler.
  void _renameInFormulas(String oldName, String newName) {
    if (oldName == newName) return;
    for (final column in _columns) {
      final formula = column.formula;
      if (formula == null || !formula.contains('{$oldName}')) continue;
      column.formula = formula.replaceAll('{$oldName}', '{$newName}');
    }
  }

  Future<void> _create() async {
    if (_saving) return;
    final loc = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(
        () => _nameError = _isTemplate
            ? loc.templateNameEmpty
            : loc.tableNameEmpty,
      );
      _nameFocus.requestFocus();
      return;
    }
    if (_columns.isEmpty) {
      setState(() => _columnError = loc.quickNeedColumn);
      return;
    }
    // Ücretsiz sınır doluysa kayıt denenmez; Premium ekranı açılır.
    if (_quota case (
      final used,
      final limit,
    ) when freeLimitReached(context, used: used, limit: limit)) {
      return;
    }
    // Premium ya da sınırlardan önceki sürümden gelen kullanıcı; yalnızca
    // yeni bir şey kurulurken sorulur.
    bool isPremium() => context.read<SubscriptionProvider>().hasUnlimitedPlan;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final Future<bool> saving = switch (widget._target) {
      _BuilderTarget.table => context.read<TableProvider>().createTable(
        name,
        _columns,
        isPremium: isPremium(),
      ),
      _BuilderTarget.editTable =>
        context.read<TableProvider>().restructureTable(
          name,
          _columns,
          _origins,
        ),
      _BuilderTarget.newTemplate =>
        context.read<TemplateProvider>().createTemplate(
          name,
          _columns,
          isPremium: isPremium(),
        ),
      _BuilderTarget.editTemplate =>
        context.read<TemplateProvider>().updateTemplate(
          widget.template!.id,
          name,
          _columns,
        ),
    };
    final saved = await saving;
    if (!mounted) return;
    if (saved) {
      navigator.pop();
      if (widget._target == _BuilderTarget.editTable) {
        messenger.showSnackBar(
          SnackBar(content: Text(loc.tableStructureUpdated)),
        );
      }
    } else {
      setState(() => _saving = false);
      final message = switch (widget._target) {
        _BuilderTarget.table => loc.tableCreateFailed,
        _BuilderTarget.editTable => loc.tableUpdateError,
        _BuilderTarget.newTemplate => loc.templateCreateFailed,
        _BuilderTarget.editTemplate => loc.templateUpdateFailed,
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Yeni bir tablo ya da şablon kurulurken ücretsiz kullanımın durumu;
  /// düzenlemede sınır yoktur.
  (int, int)? get _quota => switch (widget._target) {
    _BuilderTarget.table => (
      context.read<TableProvider>().ownedTableCount,
      PlanLimits.freeTables,
    ),
    _BuilderTarget.newTemplate => (
      context.read<TemplateProvider>().templates.length,
      PlanLimits.freeTemplates,
    ),
    _ => null,
  };

  /// Oluşturma düğmesinin altındaki "4/5 ücretsiz".
  Widget? get _quotaNote => switch (widget._target) {
    _BuilderTarget.table => FreeQuotaNote(
      used: context.watch<TableProvider>().ownedTableCount,
      limit: PlanLimits.freeTables,
    ),
    _BuilderTarget.newTemplate => FreeQuotaNote(
      used: context.watch<TemplateProvider>().templates.length,
      limit: PlanLimits.freeTemplates,
    ),
    _ => null,
  };

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
    setState(() {
      _columns.insert(to, _columns.removeAt(from));
      _origins.insert(to, _origins.removeAt(from));
    });
  }

  /// Başlığın altındaki hücre: düzenlenen tabloda son kaydın değeri,
  /// yoksa örnek.
  String _cell(AppLocalizations loc, int index) {
    final origin = _origins[index];
    final row = _lastRow;
    if (origin != null && row != null && origin < row.length) {
      final value = row[origin].trim();
      if (value.isNotEmpty) return value;
    }
    return _sample(loc, _columns[index]);
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
                  enabled: !_saving && _columns.length > 1 && !_fixedOrder,
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
                                  _cell(loc, index),
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
    if (widget._target == _BuilderTarget.editTable) {
      // Ortak tablonun yapısını yalnızca paylaşan kişi değiştirir.
      final tables = context.watch<TableProvider>();
      final id = tables.currentTable?.id;
      if (id != null && tables.isSharedTable(id) && !tables.isSharedOwner(id)) {
        return const SharedStructureLocked();
      }
    }
    return Scaffold(
      appBar: AppBar(
        // Uygulamadaki diğer form ekranlarıyla aynı görünüm.
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        titleSpacing: 0,
        title: Text(switch (widget._target) {
          _BuilderTarget.table => loc.newTable,
          _BuilderTarget.editTable => loc.editTableStructure,
          _BuilderTarget.newTemplate => loc.createNewTemplateTitle,
          _BuilderTarget.editTemplate => loc.editTemplate,
        }, style: Theme.of(context).textTheme.titleLarge),
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
                    // Düzenlerken ad zaten dolu; klavye kendiliğinden açılmaz.
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    decoration: InputDecoration(
                      labelText: _isTemplate ? loc.templateName : loc.tableName,
                      hintText: _isTemplate || _isEditing
                          ? null
                          : loc.tableNameHint,
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
                          : _fixedOrder
                          ? loc.sharedColumnOrderHint
                          : _columns.length == 1
                          ? loc.quickMoreHint
                          : '${loc.quickMoreHint} ${loc.quickReorderHint}',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  // Şablon kurarken ya da tabloyu düzenlerken şablona
                  // yönlendirmek anlamsızdır.
                  if (widget._target == _BuilderTarget.table) ...[
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('quick-create'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _saving ? null : _create,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(switch (widget._target) {
                      _BuilderTarget.table => loc.createTable,
                      _BuilderTarget.editTable => loc.save,
                      _BuilderTarget.newTemplate => loc.templateCreate,
                      _BuilderTarget.editTemplate => loc.save,
                    }),
                  ),
                  if (_quotaNote case final note?) note,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
