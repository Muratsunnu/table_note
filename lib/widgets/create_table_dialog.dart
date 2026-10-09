import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'form_field_reveal.dart';
import 'add_column_card.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import '../providers/table_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/template_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/column_naming.dart';
import '../l10n/ux_localizations.dart';
import '../services/form_draft_store.dart';
import '../utils/app_feedback.dart';
import 'form_draft_guard.dart';

class CreateTableDialog extends StatefulWidget {
  const CreateTableDialog({Key? key}) : super(key: key);

  @override
  State<CreateTableDialog> createState() => _CreateTableDialogState();
}

class _CreateTableDialogState extends State<CreateTableDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _tableNameController = TextEditingController();
  final _tableNameFocus = FocusNode();
  final _fieldReveal = FieldRevealController();
  final _draft = FormDraftStore('create_table');
  late final String _emptyDraft;
  String? _lastDraftSnapshot;
  bool _restoringDraft = true;
  bool _restoredDraft = false;
  bool _draftCaptureQueued = false;
  bool _draftCompleted = false;
  bool _isSaving = false;
  String? _tableNameError;
  final List<ColumnModel> _columns = [ColumnModel(name: '')];

  // Controller listeleri
  final List<TextEditingController> _columnControllers = [];
  final List<TextEditingController> _autoFillControllers = [];
  final List<TextEditingController> _constantValueControllers = [];
  final List<TextEditingController> _formulaControllers = [];
  // TabBarView can retain the previous page during its transition. Keep its
  // inputs alive until this form is disposed instead of guessing a frame delay.
  final List<TextEditingController> _retiredControllers = [];
  final List<FocusNode> _retiredFocusNodes = [];
  final List<bool> _showAutoFill = [];
  final List<bool> _showAdvanced = [];
  final List<GlobalKey> _columnKeys = [];
  final List<FocusNode> _columnFocus = [];
  final List<FocusNode> _constantFocus = [];
  final List<FocusNode> _formulaFocus = [];
  final List<String?> _columnNameErrors = [];
  final List<String?> _constantValueErrors = [];
  final List<String?> _formulaErrors = [];
  final ScrollController _manualScrollController = ScrollController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _initializeControllersForColumn(_columns[0]);
    _tableNameController.addListener(_queueDraft);
    _emptyDraft = jsonEncode(_draftSnapshot());
    _lastDraftSnapshot = _emptyDraft;
    unawaited(_restoreDraft());
  }

  void _initializeControllersForColumn(ColumnModel col) {
    _columnControllers.add(TextEditingController(text: col.name));
    _autoFillControllers.add(
      TextEditingController(text: col.autoFillOptions.join(', ')),
    );
    _constantValueControllers.add(
      TextEditingController(text: col.constantValue?.toString() ?? ''),
    );
    _formulaControllers.add(TextEditingController(text: col.formula ?? ''));
    _showAutoFill.add(col.autoFillOptions.isNotEmpty);
    _showAdvanced.add(false);
    _columnKeys.add(GlobalKey());
    _columnFocus.add(FocusNode());
    _constantFocus.add(FocusNode());
    _formulaFocus.add(FocusNode());
    _columnControllers.last.addListener(_queueDraft);
    _autoFillControllers.last.addListener(_queueDraft);
    _constantValueControllers.last.addListener(_queueDraft);
    _formulaControllers.last.addListener(_queueDraft);
    _columnNameErrors.add(null);
    _constantValueErrors.add(null);
    _formulaErrors.add(null);
  }

  @override
  void dispose() {
    _fieldReveal.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _persistDraft();
    _draft.dispose();
    _tableNameController.dispose();
    _tableNameFocus.dispose();
    _tabController.dispose();
    _manualScrollController.dispose();
    for (var c in _columnControllers) c.dispose();
    for (var c in _autoFillControllers) c.dispose();
    for (var c in _constantValueControllers) c.dispose();
    for (var c in _formulaControllers) c.dispose();
    for (final controller in _retiredControllers) {
      controller.dispose();
    }
    for (final focus in [
      ..._columnFocus,
      ..._constantFocus,
      ..._formulaFocus,
      ..._retiredFocusNodes,
    ]) {
      focus.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _persistDraft();
      unawaited(_draft.flush());
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _queueDraft();
  }

  Map<String, dynamic> _draftSnapshot() => {
    'name': _tableNameController.text,
    'columns': List.generate(
      _columns.length,
      (i) => {
        ..._columns[i].toJson(),
        'name': _columnControllers[i].text,
        'autoFillText': _autoFillControllers[i].text,
        'constantText': _constantValueControllers[i].text,
        'formula': _formulaControllers[i].text,
      },
    ),
  };

  void _queueDraft() {
    if (_restoringDraft || _draftCompleted || _draftCaptureQueued) return;
    _draftCaptureQueued = true;
    scheduleMicrotask(() {
      _draftCaptureQueued = false;
      if (mounted) _persistDraft();
    });
  }

  void _persistDraft() {
    if (_restoringDraft || _draftCompleted) return;
    final snapshot = _draftSnapshot();
    final serialized = jsonEncode(snapshot);
    if (serialized == _lastDraftSnapshot) return;
    _lastDraftSnapshot = serialized;
    if (serialized == _emptyDraft) {
      unawaited(_draft.clear());
    } else {
      _draft.schedule(snapshot);
    }
  }

  Future<void> _restoreDraft() async {
    final data = await _draft.read();
    if (!mounted) return;
    if (data != null) {
      try {
        _applyDraft(data);
        _restoredDraft = true;
      } catch (_) {
        _applyDraft(Map<String, dynamic>.from(jsonDecode(_emptyDraft)));
      }
    }
    setState(() => _restoringDraft = false);
  }

  void _applyDraft(Map<String, dynamic> data) {
    final columns = (data['columns'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (columns.isEmpty) return;
    final models = columns.map(ColumnModel.fromJson).toList();
    _clearColumnControllers();
    _tableNameController.text = data['name'] as String? ?? '';
    _columns
      ..clear()
      ..addAll(models);
    for (var i = 0; i < models.length; i++) {
      _initializeControllersForColumn(models[i]);
      _autoFillControllers[i].text =
          columns[i]['autoFillText'] as String? ?? '';
      _constantValueControllers[i].text =
          columns[i]['constantText'] as String? ?? '';
      _showAutoFill[i] = _autoFillControllers[i].text.isNotEmpty;
    }
  }

  void _clearColumnControllers() {
    _fieldReveal.dispose();
    _retireColumnInputs(
      [
        ..._columnControllers,
        ..._autoFillControllers,
        ..._constantValueControllers,
        ..._formulaControllers,
      ],
      [..._columnFocus, ..._constantFocus, ..._formulaFocus],
    );
    _columnControllers.clear();
    _autoFillControllers.clear();
    _constantValueControllers.clear();
    _formulaControllers.clear();
    _columnFocus.clear();
    _constantFocus.clear();
    _formulaFocus.clear();
    _columnKeys.clear();
    _showAutoFill.clear();
    _showAdvanced.clear();
    _columnNameErrors.clear();
    _constantValueErrors.clear();
    _formulaErrors.clear();
  }

  void _retireColumnInputs(
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
  ) {
    for (final controller in controllers) {
      controller.removeListener(_queueDraft);
    }
    for (final focus in focusNodes) {
      if (focus.hasFocus) focus.unfocus();
    }
    _retiredControllers.addAll(controllers);
    _retiredFocusNodes.addAll(focusNodes);
  }

  Future<void> _discardDraft() async {
    _restoringDraft = true;
    setState(() {
      _applyDraft(Map<String, dynamic>.from(jsonDecode(_emptyDraft)));
      _tableNameError = null;
      _restoredDraft = false;
      _lastDraftSnapshot = _emptyDraft;
    });
    await _draft.clear();
    if (mounted) setState(() => _restoringDraft = false);
  }

  @override
  Widget build(BuildContext context) {
    return FormDraftGuard(
      isSaving: _isSaving || _restoringDraft,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildManualCreateTab(), _buildTemplateTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.darkBlue, AppTheme.primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).createNewTable,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: AppTheme.primaryBlue,
              indicatorWeight: 3,
              tabs: [
                Tab(text: AppLocalizations.of(context).manualCreate),
                Tab(text: AppLocalizations.of(context).createFromTemplate),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualCreateTab() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: FormFocusScrollView(
            controller: _manualScrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_restoredDraft) ...[
                  _buildDraftNotice(),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _tableNameController,
                  focusNode: _tableNameFocus,
                  onChanged: (_) {
                    if (_tableNameError != null) {
                      setState(() => _tableNameError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).tableName,
                    hintText: AppLocalizations.of(context).tableNameHint,
                    errorText: _tableNameError,
                    prefixIcon: const Icon(Icons.table_chart_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.view_column_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).columns,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.help_outline_rounded, size: 18),
                      label: Text(AppLocalizations.of(context).help),
                      onPressed: _showHelpDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._buildColumnWidgets(),
                const SizedBox(height: 6),
                // Listenin sonunda sıradaki sütunun yeri durur; dokununca eklenir.
                AddColumnCard(onTap: _isSaving ? null : _addColumn),
              ],
            ),
          ),
        ),
        _buildManualFooter(),
      ],
    );
  }

  Widget _buildManualFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).addColumn),
              onPressed: _isSaving ? null : _addColumn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isSaving
                    ? AppLocalizations.of(context).savingProgress
                    : AppLocalizations.of(context).createTable,
              ),
              onPressed: _isSaving ? null : _createTable,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftNotice() {
    final loc = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            const Icon(Icons.restore_rounded, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(loc.draftRestored)),
            TextButton(onPressed: _discardDraft, child: Text(loc.discardDraft)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildColumnWidgets() {
    return _columns.asMap().entries.map((entry) {
      final index = entry.key;
      final column = entry.value;

      // Controller senkronizasyonu
      while (_columnControllers.length <= index) {
        _initializeControllersForColumn(ColumnModel(name: ''));
      }

      return Card(
        key: _columnKeys[index],
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sütun adı ve silme butonu
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _columnControllers[index],
                      focusNode: _columnFocus[index],
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        ).columnN(index + 1),
                        hintText: AppLocalizations.of(context).columnName,
                        errorText: _columnNameErrors[index],
                        border: const OutlineInputBorder(),
                        prefixIcon: _getColumnTypeIcon(column.columnType),
                      ),
                      onChanged: (value) {
                        setState(() {
                          column.name = value;
                          _columnNameErrors[index] = null;
                        });
                      },
                    ),
                  ),
                  if (_columns.length > 1) ...[
                    SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppTheme.error),
                      onPressed: () => _removeColumn(index),
                      tooltip: AppLocalizations.of(context).deleteColumn,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _columnTypeLabel(column.columnType),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _showAdvanced[index] = !_showAdvanced[index],
                    ),
                    icon: Icon(
                      _showAdvanced[index]
                          ? Icons.expand_less_rounded
                          : Icons.tune_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _showAdvanced[index]
                          ? AppLocalizations.of(context).hideAdvancedSettings
                          : AppLocalizations.of(context).advancedSettings,
                    ),
                  ),
                ],
              ),
              if (_showAdvanced[index]) ...[
                const SizedBox(height: 8),
                _buildColumnTypeSelector(index, column),
                _buildColumnTypeSettings(index, column),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _getColumnTypeIcon(ColumnType type) {
    final color = Theme.of(context).colorScheme.primary;
    switch (type) {
      case ColumnType.normal:
        return Icon(Icons.edit_outlined, color: color);
      case ColumnType.constant:
        return Icon(Icons.pin_outlined, color: color);
      case ColumnType.formula:
        return Icon(Icons.functions, color: color);
      case ColumnType.date:
        return Icon(Icons.calendar_today_outlined, color: color);
      case ColumnType.time:
        return Icon(Icons.access_time, color: color);
      case ColumnType.autoNumber:
        return Icon(Icons.format_list_numbered, color: color);
    }
  }

  String _columnTypeLabel(ColumnType type) {
    final loc = AppLocalizations.of(context);
    return switch (type) {
      ColumnType.normal => loc.normal,
      ColumnType.constant => loc.constantValue,
      ColumnType.formula => loc.formula,
      ColumnType.date => loc.date,
      ColumnType.time => loc.time,
      ColumnType.autoNumber => loc.autoNumber,
    };
  }

  Widget _buildColumnTypeSelector(int index, ColumnModel column) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).columnType,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.normal,
                label: AppLocalizations.of(context).normal,
                icon: Icons.edit,
                color: Colors.blue,
                tooltip: AppLocalizations.of(context).manualInput,
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.constant,
                label: AppLocalizations.of(context).constantValue,
                icon: Icons.pin,
                color: Colors.orange,
                tooltip: AppLocalizations.of(context).defaultValueComes,
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.formula,
                label: AppLocalizations.of(context).formula,
                icon: Icons.functions,
                color: Colors.purple,
                tooltip: AppLocalizations.of(context).autoCalculated,
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.date,
                label: AppLocalizations.of(context).date,
                icon: Icons.calendar_today,
                color: Colors.teal,
                tooltip: AppLocalizations.of(context).todaysDateAuto,
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.time,
                label: AppLocalizations.of(context).time,
                icon: Icons.access_time,
                color: Colors.indigo,
                tooltip: AppLocalizations.of(context).currentTimeAuto,
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.autoNumber,
                label: AppLocalizations.of(context).autoNumber,
                icon: Icons.format_list_numbered,
                color: Colors.brown,
                tooltip: AppLocalizations.of(context).autoIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required int index,
    required ColumnModel column,
    required ColumnType type,
    required String label,
    required IconData icon,
    required Color color,
    required String tooltip,
  }) {
    final isSelected = column.columnType == type;

    return Tooltip(
      message: tooltip,
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : AppTheme.readableAccent(context, color),
            ),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selectedColor: Theme.of(context).colorScheme.primary,
        checkmarkColor: Theme.of(context).colorScheme.onPrimary,
        labelStyle: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              column.columnType = type;
              // Adi kendiliginden belli olan tiplerde ad da dolar;
              // kullanicinin kendi yazdigi ad ezilmez.
              final renamed = renamedForType(
                _columnControllers[index].text,
                type,
                AppLocalizations.of(context),
              );
              if (renamed != null) {
                _columnControllers[index].text = renamed;
                column.name = renamed;
              }
              // Tip değişince ilgili alanları temizle
              if (type == ColumnType.normal) {
                column.constantValue = null;
                column.formula = null;
                column.isNumeric = false;
              } else if (type == ColumnType.constant) {
                column.formula = null;
                column.isNumeric = true;
              } else if (type == ColumnType.formula) {
                column.constantValue = null;
                column.isNumeric = true;
              } else if (type == ColumnType.date || type == ColumnType.time) {
                column.constantValue = null;
                column.formula = null;
                column.isNumeric = false;
              } else if (type == ColumnType.autoNumber) {
                column.constantValue = null;
                column.formula = null;
                column.isNumeric = true; // Sayısal olarak işaretliyoruz
              }
            });
          }
        },
      ),
    );
  }

  Widget _buildColumnTypeSettings(int index, ColumnModel column) {
    switch (column.columnType) {
      case ColumnType.normal:
        return _buildNormalColumnSettings(index, column);
      case ColumnType.constant:
        return _buildConstantColumnSettings(index, column);
      case ColumnType.formula:
        return _buildFormulaColumnSettings(index, column);
      case ColumnType.date:
        return _buildDateColumnSettings(column);
      case ColumnType.time:
        return _buildTimeColumnSettings(column);
      case ColumnType.autoNumber:
        return _buildAutoNumberColumnSettings(column);
    }
  }

  Widget _buildNormalColumnSettings(int index, ColumnModel column) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Sayısal checkbox
        CheckboxListTile(
          title: Text(AppLocalizations.of(context).numericColumn),
          subtitle: Text(AppLocalizations.of(context).numericColumnDesc),
          value: column.isNumeric,
          onChanged: (value) {
            setState(() => column.isNumeric = value ?? false);
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),

        // Otomatik doldurma seçenekleri
        if (column.autoFillOptions.isNotEmpty || _showAutoFill[index]) ...[
          SizedBox(height: 8),
          TextField(
            controller: _autoFillControllers[index],
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).quickSelectionList,
              hintText: AppLocalizations.of(context).quickSelectionHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.list),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    column.autoFillOptions = [];
                    _autoFillControllers[index].clear();
                    _showAutoFill[index] = false;
                  });
                },
              ),
            ),
            onChanged: (value) {
              column.autoFillOptions = value
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
            },
          ),
        ] else ...[
          SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.list, size: 18),
            label: Text(AppLocalizations.of(context).addQuickSelectionList),
            onPressed: () => setState(() => _showAutoFill[index] = true),
          ),
        ],
      ],
    );
  }

  Widget _buildConstantColumnSettings(int index, ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.tintedSurface(context, Colors.orange),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppTheme.readableAccent(context, Colors.orange),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).defaultValueInfo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              TextField(
                controller: _constantValueControllers[index],
                focusNode: _constantFocus[index],
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).defaultValue,
                  hintText: AppLocalizations.of(context).defaultValueHint,
                  errorText: _constantValueErrors[index],
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) {
                  setState(() {
                    column.constantValue = _parseConstant(value);
                    _constantValueErrors[index] = null;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormulaColumnSettings(int index, ColumnModel column) {
    // Formülde kullanılabilecek sütunlar (kendisi hariç, sadece dolu isimli olanlar)
    final availableColumns = _columns
        .asMap()
        .entries
        .where((e) => e.key != index && e.value.name.trim().isNotEmpty)
        .map((e) => e.value)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.tintedSurface(context, Colors.purple),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppTheme.readableAccent(context, Colors.purple),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).formulaAutoCalcInfo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Formül girişi
              TextField(
                controller: _formulaControllers[index],
                focusNode: _formulaFocus[index],
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).formulaLabel,
                  hintText: AppLocalizations.of(context).formulaHint,
                  errorText: _formulaErrors[index],
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.functions),
                  helperText: AppLocalizations.of(context).operationsHint,
                  helperMaxLines: 2,
                ),
                onChanged: (value) {
                  setState(() {
                    column.formula = value;
                    _formulaErrors[index] = null;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Kullanılabilir sütunlar
              if (availableColumns.isNotEmpty) ...[
                Text(
                  AppLocalizations.of(context).clickToAddColumn,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: availableColumns.map((col) {
                    return ActionChip(
                      avatar: Icon(
                        col.isEffectivelyNumeric
                            ? Icons.numbers
                            : Icons.text_fields,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                      label: Text(
                        col.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      side: BorderSide(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      ),
                      onPressed: () {
                        final currentText = _formulaControllers[index].text;
                        _formulaControllers[index].text =
                            '$currentText{${col.name}}';
                        column.formula = _formulaControllers[index].text;
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // İşlem butonları
              Text(
                AppLocalizations.of(context).addOperation,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildOperatorChip(
                    index,
                    column,
                    '+',
                    AppLocalizations.of(context).addition,
                  ),
                  _buildOperatorChip(
                    index,
                    column,
                    '-',
                    AppLocalizations.of(context).subtraction,
                  ),
                  _buildOperatorChip(
                    index,
                    column,
                    '*',
                    AppLocalizations.of(context).multiplication,
                  ),
                  _buildOperatorChip(
                    index,
                    column,
                    '/',
                    AppLocalizations.of(context).division,
                  ),
                  _buildOperatorChip(
                    index,
                    column,
                    '%',
                    AppLocalizations.of(context).percentage,
                  ),
                  _buildOperatorChip(
                    index,
                    column,
                    '(',
                    AppLocalizations.of(context).openParen,
                  ),
                  _buildOperatorChip(
                    index,
                    column,
                    ')',
                    AppLocalizations.of(context).closeParen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorChip(
    int index,
    ColumnModel column,
    String op,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: ActionChip(
        label: Text(
          op,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.readableAccent(context, AppTheme.formula),
          ),
        ),
        backgroundColor: AppTheme.tintedSurface(context, AppTheme.formula),
        side: BorderSide(color: AppTheme.formula.withValues(alpha: 0.3)),
        onPressed: () {
          final currentText = _formulaControllers[index].text;
          _formulaControllers[index].text = '$currentText$op';
          column.formula = _formulaControllers[index].text;
        },
      ),
    );
  }

  Widget _buildDateColumnSettings(ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.tintedSurface(context, Colors.teal),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: AppTheme.readableAccent(context, Colors.teal),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).autoDate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).autoDateDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).example(_getCurrentDateFormatted()),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeColumnSettings(ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.tintedSurface(context, Colors.indigo),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                color: AppTheme.readableAccent(context, Colors.indigo),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).autoTime,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).autoTimeDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).example(_getCurrentTimeFormatted()),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoNumberColumnSettings(ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.tintedSurface(context, Colors.brown),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.format_list_numbered,
                color: AppTheme.readableAccent(context, Colors.brown),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).autoNumberTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).autoNumberDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppLocalizations.of(context).example('1, 2, 3, 4...'),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getCurrentDateFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }

  String _getCurrentTimeFormatted() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _addColumn() {
    if (_isSaving) return;
    setState(() {
      final newColumn = ColumnModel(name: '');
      _columns.add(newColumn);
      _initializeControllersForColumn(newColumn);
    });
    _revealColumn(_columns.length - 1, _columnFocus.last);
  }

  void _removeColumn(int index) {
    setState(() {
      _columns.removeAt(index);
      _retireColumnInputs(
        [
          _columnControllers.removeAt(index),
          _autoFillControllers.removeAt(index),
          _constantValueControllers.removeAt(index),
          _formulaControllers.removeAt(index),
        ],
        [
          _columnFocus.removeAt(index),
          _constantFocus.removeAt(index),
          _formulaFocus.removeAt(index),
        ],
      );
      _columnKeys.removeAt(index);
      _showAdvanced.removeAt(index);
      _showAutoFill.removeAt(index);
      _columnNameErrors.removeAt(index);
      _constantValueErrors.removeAt(index);
      _formulaErrors.removeAt(index);
    });
  }

  Future<void> _createTable() async {
    if (_isSaving || _restoringDraft) return;
    // Controller'lardan verileri senkronize et
    for (int i = 0; i < _columns.length; i++) {
      _columns[i].name = _columnControllers[i].text.trim();
      _columns[i].autoFillOptions = _autoFillControllers[i].text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      _columns[i].constantValue = _parseConstant(
        _constantValueControllers[i].text,
      );
      _columns[i].formula = _formulaControllers[i].text.trim().isEmpty
          ? null
          : _formulaControllers[i].text.trim();
    }

    final tableName = _tableNameController.text.trim();

    // Validasyon
    if (tableName.isEmpty) {
      setState(() {
        _tableNameError = AppLocalizations.of(context).tableNameEmpty;
      });
      _tableNameFocus.requestFocus();
      if (_manualScrollController.hasClients) {
        _manualScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    setState(() {
      for (var i = 0; i < _columns.length; i++) {
        _columnNameErrors[i] = null;
        _constantValueErrors[i] = null;
        _formulaErrors[i] = null;
      }
    });

    final unnamedIndex = _columns.indexWhere((col) => col.name.isEmpty);
    if (unnamedIndex != -1) {
      setState(() {
        _columnNameErrors[unnamedIndex] = AppLocalizations.of(
          context,
        ).columnNameEmpty(unnamedIndex + 1);
      });
      _revealColumn(unnamedIndex, _columnFocus[unnamedIndex]);
      return;
    }

    final validColumns = _columns;

    // Formül validasyonu
    for (var i = 0; i < validColumns.length; i++) {
      final col = validColumns[i];
      if (col.isFormula && (col.formula == null || col.formula!.isEmpty)) {
        setState(() {
          _formulaErrors[i] = AppLocalizations.of(
            context,
          ).formulaRequired(col.name);
          _showAdvanced[i] = true;
        });
        _revealColumn(i, _formulaFocus[i]);
        return;
      }
      if (col.isConstant && col.constantValue == null) {
        setState(() {
          _constantValueErrors[i] = AppLocalizations.of(
            context,
          ).defaultValueRequired(col.name);
          _showAdvanced[i] = true;
        });
        _revealColumn(i, _constantFocus[i]);
        return;
      }
    }

    // Tablo oluştur
    final provider = Provider.of<TableProvider>(context, listen: false);
    // Premium ya da sınırlardan önceki sürümden gelen kullanıcı.
    final isPremium = context.read<SubscriptionProvider>().hasUnlimitedPlan;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    try {
      final success = await provider.createTable(
        tableName,
        validColumns,
        isPremium: isPremium,
      );
      if (!mounted) return;
      if (success) {
        _draftCompleted = true;
        await _draft.clear();
        if (mounted) Navigator.pop(context);
      } else {
        _showErrorSnackBar(AppLocalizations.of(context).tableCreateFailed);
      }
    } catch (_) {
      if (mounted)
        _showErrorSnackBar(AppLocalizations.of(context).tableCreateFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double? _parseConstant(String text) {
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  void _revealColumn(int index, FocusNode focus) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          index >= _columnKeys.length ||
          ![
            ..._columnFocus,
            ..._constantFocus,
            ..._formulaFocus,
          ].contains(focus)) {
        return;
      }
      _fieldReveal.reveal(focus);
    });
  }

  Widget _buildTemplateTab() {
    return Consumer<TemplateProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!provider.hasTemplates) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 60,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).noTemplatesYet,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(AppLocalizations.of(context).manualCreate),
                    onPressed: () => _tabController.animateTo(0),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.templates.length,
          itemBuilder: (context, index) {
            final template = provider.templates[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.table_chart,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  template.templateName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocalizations.of(
                    context,
                  ).nColumns(template.columns.length),
                ),
                onTap: () => _createTableFromTemplate(template),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            );
          },
        );
      },
    );
  }

  void _createTableFromTemplate(TemplateModel template) {
    // Şablonu manuel sekmeye yükle: ad + sütunları doldur, sekmeyi değiştir.
    // Kullanıcı düzenleyip tek "Oluştur" butonuyla tabloyu oluşturur.
    setState(() {
      // Eski controller'ları temizle
      _clearColumnControllers();
      _tableNameError = null;

      // Şablon verisini yükle
      _tableNameController.text = template.templateName;
      _columns
        ..clear()
        ..addAll(template.columns.map((c) => c.copyWith()));
      for (final col in _columns) {
        _initializeControllersForColumn(col);
      }
    });
    _tabController.animateTo(0);
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.of(context).columnTypes)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                icon: Icons.edit,
                color: Colors.blue,
                title: AppLocalizations.of(context).normalColumn,
                description: AppLocalizations.of(context).normalColumnDesc,
              ),
              const Divider(),
              _buildHelpItem(
                icon: Icons.pin,
                color: Colors.orange,
                title: AppLocalizations.of(context).constantColumnTitle,
                description: AppLocalizations.of(context).constantColumnDesc,
              ),
              const Divider(),
              _buildHelpItem(
                icon: Icons.functions,
                color: Colors.purple,
                title: AppLocalizations.of(context).formulaColumnTitle,
                description: AppLocalizations.of(context).formulaColumnDesc,
              ),
              const Divider(),
              SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).exampleFormulas,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8),
              _buildFormulaExample(
                '{Kg}*{Birim Fiyat}',
                AppLocalizations.of(context).multiplyKgPrice,
              ),
              _buildFormulaExample(
                '{Fiyat}+{Fiyat}%18',
                AppLocalizations.of(context).priceVat,
              ),
              _buildFormulaExample(
                '{Brüt}-{Dara}',
                AppLocalizations.of(context).netWeight,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).understood),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.readableAccent(context, color), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaExample(String formula, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.tintedSurface(context, Colors.purple),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              formula,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.readableAccent(context, Colors.purple),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    AppFeedback.showError(context, message);
  }
}
