import 'package:flutter/material.dart';
import 'form_field_reveal.dart';
import 'added_field_focus.dart';
import 'package:provider/provider.dart';
import '../models/tabel_model.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/column_naming.dart';
import 'shared_structure_locked.dart';
import '../utils/app_feedback.dart';

class EditTableStructureDialog extends StatefulWidget {
  const EditTableStructureDialog({Key? key}) : super(key: key);

  @override
  State<EditTableStructureDialog> createState() =>
      _EditTableStructureDialogState();
}

class _EditTableStructureDialogState extends State<EditTableStructureDialog> {
  TextEditingController? _newFieldToFocus;

  late List<ColumnModel> _columns;
  late List<TextEditingController> _nameControllers;
  late List<TextEditingController> _constantValueControllers;
  late List<TextEditingController> _formulaControllers;
  late List<String?> _columnNameErrors;
  late List<String?> _constantValueErrors;
  late List<String?> _formulaErrors;
  late String _tableName;
  late TextEditingController _tableNameController;
  String? _tableNameError;

  // Yeni eklenen sütunlar için takip
  int _originalColumnCount = 0;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TableProvider>(context, listen: false);
    final currentTable = provider.currentTable!;

    _tableName = currentTable.tableName;
    _tableNameController = TextEditingController(text: _tableName);
    _originalColumnCount = currentTable.columns.length;

    // Mevcut sütunları kopyala
    _columns = currentTable.columns.map((col) => col.copyWith()).toList();

    // Controller'ları oluştur
    _nameControllers = _columns
        .map((col) => TextEditingController(text: col.name))
        .toList();
    _constantValueControllers = _columns
        .map(
          (col) =>
              TextEditingController(text: col.constantValue?.toString() ?? ''),
        )
        .toList();
    _formulaControllers = _columns
        .map((col) => TextEditingController(text: col.formula ?? ''))
        .toList();
    // growable: true sart. Varsayilan List.filled SABIT uzunlukta bir liste
    // dondurur; "Yeni Sutun" bu listelere add() cagirinca istisna firlatiyor
    // ve istisna setState'in icinde patladigi icin widget kirli
    // isaretlenmiyordu. Sonuc: ne ekran degisiyor ne de cokme oluyordu,
    // dugme sessizce calismiyordu.
    _columnNameErrors = List<String?>.filled(
      _columns.length,
      null,
      growable: true,
    );
    _constantValueErrors = List<String?>.filled(
      _columns.length,
      null,
      growable: true,
    );
    _formulaErrors = List<String?>.filled(
      _columns.length,
      null,
      growable: true,
    );
  }

  @override
  void dispose() {
    _tableNameController.dispose();
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    for (var controller in _constantValueControllers) {
      controller.dispose();
    }
    for (var controller in _formulaControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final tables = context.watch<TableProvider>();
    final id = tables.currentTable?.id;
    if (id != null && tables.isSharedTable(id) && !tables.isSharedOwner(id)) {
      return const SharedStructureLocked();
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildEditorHeader(
              context,
              icon: Icons.settings_rounded,
              title: loc.editTableStructure,
            ),
            Expanded(
              child: FormFocusScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tablo adı
                    TextField(
                      controller: _tableNameController,
                      onChanged: (value) {
                        _tableName = value;
                        if (_tableNameError != null) {
                          setState(() => _tableNameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).tableName,
                        errorText: _tableNameError,
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.table_chart,
                          color: AppTheme.readableAccent(context, Colors.blue),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sütunlar başlığı
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${loc.columns} (${_columns.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _addNewColumn,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(loc.newColumn),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Sütun listesi
                    ..._buildColumnList(),
                  ],
                ),
              ),
            ),
            _buildEditorFooter(
              context,
              cancelLabel: loc.cancel,
              saveLabel: loc.save,
              onSave: _saveChanges,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.darkBlue, AppTheme.primaryBlue],
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ],
    ),
  );

  Widget _buildEditorFooter(
    BuildContext context, {
    required String cancelLabel,
    required String saveLabel,
    required VoidCallback onSave,
  }) => Container(
    padding: const EdgeInsets.all(16),
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(cancelLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_rounded),
              label: Text(saveLabel),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _buildColumnList() {
    return _columns.asMap().entries.map((entry) {
      final index = entry.key;
      final column = entry.value;
      final isNewColumn = index >= _originalColumnCount;

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: isNewColumn
            ? AppTheme.tintedSurface(context, Colors.green)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sütun başlığı ve badge
              Row(
                children: [
                  _getColumnTypeIcon(column.columnType),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).columnN(index + 1),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isNewColumn)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppLocalizations.of(context).newBadge,
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  if (isNewColumn) ...[
                    SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: AppTheme.error,
                        size: 20,
                      ),
                      onPressed: () => _removeNewColumn(index),
                      tooltip: AppLocalizations.of(context).removeColumn,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // Sütun adı
              AddedFieldFocus(
                key: ValueKey(_nameControllers[index]),
                target: _nameControllers[index],
                pendingTarget: () => _newFieldToFocus,
                onFocused: (target) {
                  if (identical(_newFieldToFocus, target)) {
                    _newFieldToFocus = null;
                  }
                },
                builder: (focusNode) => TextField(
                  focusNode: focusNode,
                  controller: _nameControllers[index],
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).columnNameLabel,
                    errorText: _columnNameErrors[index],
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label),
                  ),
                  onChanged: (value) => setState(() {
                    column.name = value;
                    _columnNameErrors[index] = null;
                  }),
                ),
              ),

              // Yeni sütunlar için tip seçimi
              if (isNewColumn) ...[
                const SizedBox(height: 12),
                _buildColumnTypeSelector(index, column),
                _buildColumnTypeSettings(index, column),
              ] else ...[
                // Mevcut sütunlar için sadece tip gösterimi
                SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).typeName(_getColumnTypeName(column.columnType)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        AppLocalizations.of(context).cannotChange,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _getColumnTypeIcon(ColumnType type) {
    switch (type) {
      case ColumnType.normal:
        return const Icon(Icons.edit, color: Colors.blue, size: 20);
      case ColumnType.constant:
        return const Icon(Icons.pin, color: Colors.orange, size: 20);
      case ColumnType.formula:
        return const Icon(Icons.functions, color: Colors.purple, size: 20);
      case ColumnType.date:
        return const Icon(Icons.calendar_today, color: Colors.teal, size: 20);
      case ColumnType.time:
        return const Icon(Icons.access_time, color: Colors.indigo, size: 20);
      case ColumnType.autoNumber:
        return const Icon(
          Icons.format_list_numbered,
          color: Colors.brown,
          size: 20,
        );
    }
  }

  String _getColumnTypeName(ColumnType type) {
    switch (type) {
      case ColumnType.normal:
        return AppLocalizations.of(context).normal;
      case ColumnType.constant:
        return AppLocalizations.of(context).constantValue;
      case ColumnType.formula:
        return AppLocalizations.of(context).formula;
      case ColumnType.date:
        return AppLocalizations.of(context).date;
      case ColumnType.time:
        return AppLocalizations.of(context).time;
      case ColumnType.autoNumber:
        return AppLocalizations.of(context).autoNumber;
    }
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
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTypeChip(
                index,
                column,
                ColumnType.normal,
                AppLocalizations.of(context).normal,
                Icons.edit,
                Colors.blue,
              ),
              _buildTypeChip(
                index,
                column,
                ColumnType.constant,
                AppLocalizations.of(context).constant,
                Icons.pin,
                Colors.orange,
              ),
              _buildTypeChip(
                index,
                column,
                ColumnType.formula,
                AppLocalizations.of(context).formula,
                Icons.functions,
                Colors.purple,
              ),
              _buildTypeChip(
                index,
                column,
                ColumnType.date,
                AppLocalizations.of(context).date,
                Icons.calendar_today,
                Colors.teal,
              ),
              _buildTypeChip(
                index,
                column,
                ColumnType.time,
                AppLocalizations.of(context).time,
                Icons.access_time,
                Colors.indigo,
              ),
              _buildTypeChip(
                index,
                column,
                ColumnType.autoNumber,
                AppLocalizations.of(context).autoNumber,
                Icons.format_list_numbered,
                Colors.brown,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(
    int index,
    ColumnModel column,
    ColumnType type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = column.columnType == type;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        fontSize: 11,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            column.columnType = type;
            // Adi kendiliginden belli olan tiplerde ad da dolar;
            // kullanicinin kendi yazdigi ad ezilmez.
            final renamed = renamedForType(
              _nameControllers[index].text,
              type,
              AppLocalizations.of(context),
            );
            if (renamed != null) {
              _nameControllers[index].text = renamed;
              column.name = renamed;
            }
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
              column.isNumeric = true;
            }
          });
        }
      },
    );
  }

  Widget _buildColumnTypeSettings(int index, ColumnModel column) {
    switch (column.columnType) {
      case ColumnType.normal:
        return _buildNormalSettings(index, column);
      case ColumnType.constant:
        return _buildConstantSettings(index, column);
      case ColumnType.formula:
        return _buildFormulaSettings(index, column);
      case ColumnType.date:
      case ColumnType.time:
      case ColumnType.autoNumber:
        return const SizedBox(height: 8);
    }
  }

  Widget _buildNormalSettings(int index, ColumnModel column) {
    return Column(
      children: [
        SizedBox(height: 8),
        CheckboxListTile(
          title: Text(
            AppLocalizations.of(context).numericColumn,
            style: const TextStyle(fontSize: 13),
          ),
          value: column.isNumeric,
          onChanged: (value) =>
              setState(() => column.isNumeric = value ?? false),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildConstantSettings(int index, ColumnModel column) {
    return Column(
      children: [
        SizedBox(height: 12),
        TextField(
          controller: _constantValueControllers[index],
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).defaultValue,
            errorText: _constantValueErrors[index],
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.pin, color: Colors.orange),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            setState(() {
              column.constantValue = double.tryParse(value);
              _constantValueErrors[index] = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFormulaSettings(int index, ColumnModel column) {
    // Formül için kullanılabilir sütunlar (kendisi hariç)
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
        TextField(
          controller: _formulaControllers[index],
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).formulaLabel,
            hintText: AppLocalizations.of(context).formulaHint,
            errorText: _formulaErrors[index],
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.functions, color: Colors.purple),
          ),
          onChanged: (value) => setState(() {
            column.formula = value;
            _formulaErrors[index] = null;
          }),
        ),
        if (availableColumns.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).addColumnLabel,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableColumns.map((col) {
              return ActionChip(
                label: Text(
                  col.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                side: BorderSide(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                ),
                onPressed: () {
                  final current = _formulaControllers[index].text;
                  _formulaControllers[index].text = '$current{${col.name}}';
                  column.formula = _formulaControllers[index].text;
                },
              );
            }).toList(),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).addOperation,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['+', '-', '*', '/', '%', '(', ')'].map((op) {
              return ActionChip(
                label: Text(
                  op,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.formula,
                  ),
                ),
                backgroundColor: AppTheme.tintedSurface(
                  context,
                  AppTheme.formula,
                ),
                side: BorderSide(
                  color: AppTheme.formula.withValues(alpha: 0.3),
                ),
                onPressed: () {
                  final current = _formulaControllers[index].text;
                  _formulaControllers[index].text = '$current$op';
                  column.formula = _formulaControllers[index].text;
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _addNewColumn() {
    setState(() {
      final newColumn = ColumnModel(name: '');
      _columns.add(newColumn);
      _nameControllers.add(TextEditingController());
      _constantValueControllers.add(TextEditingController());
      _formulaControllers.add(TextEditingController());
      _columnNameErrors.add(null);
      _constantValueErrors.add(null);
      _formulaErrors.add(null);
      _newFieldToFocus = _nameControllers.last;
    });
  }

  void _removeNewColumn(int index) {
    if (index >= _originalColumnCount) {
      setState(() {
        _columns.removeAt(index);
        _nameControllers[index].dispose();
        _nameControllers.removeAt(index);
        _constantValueControllers[index].dispose();
        _constantValueControllers.removeAt(index);
        _formulaControllers[index].dispose();
        _formulaControllers.removeAt(index);
        _columnNameErrors.removeAt(index);
        _constantValueErrors.removeAt(index);
        _formulaErrors.removeAt(index);
      });
    }
  }

  Future<void> _saveChanges() async {
    // Validasyon
    _tableName = _tableNameController.text.trim();
    if (_tableName.isEmpty) {
      setState(() {
        _tableNameError = AppLocalizations.of(context).tableNameEmpty;
      });
      return;
    }

    setState(() {
      for (var i = 0; i < _columns.length; i++) {
        _columnNameErrors[i] = null;
        _constantValueErrors[i] = null;
        _formulaErrors[i] = null;
      }
    });

    // Sütun isimlerini güncelle
    for (int i = 0; i < _columns.length; i++) {
      _columns[i].name = _nameControllers[i].text.trim();

      if (_columns[i].name.isEmpty) {
        setState(() {
          _columnNameErrors[i] = AppLocalizations.of(
            context,
          ).columnNameEmpty(i + 1);
        });
        return;
      }

      // Yeni sütunlar için ek ayarları güncelle
      if (i >= _originalColumnCount) {
        if (_columns[i].isConstant) {
          _columns[i].constantValue = double.tryParse(
            _constantValueControllers[i].text,
          );
        }
        if (_columns[i].isFormula) {
          _columns[i].formula = _formulaControllers[i].text.trim().isEmpty
              ? null
              : _formulaControllers[i].text.trim();
        }
      }

      if (_columns[i].isConstant && _columns[i].constantValue == null) {
        setState(() {
          _constantValueErrors[i] = AppLocalizations.of(
            context,
          ).defaultValueRequired(_columns[i].name);
        });
        return;
      }
      if (_columns[i].isFormula && _columns[i].formula == null) {
        setState(() {
          _formulaErrors[i] = AppLocalizations.of(
            context,
          ).formulaRequired(_columns[i].name);
        });
        return;
      }
    }

    // Kaydet
    final provider = Provider.of<TableProvider>(context, listen: false);
    final success = await provider.updateTableStructure(
      _tableName,
      _columns,
      _originalColumnCount,
    );
    if (!mounted) return;

    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      final message = AppLocalizations.of(context).tableStructureUpdated;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.success),
      );
    } else {
      AppFeedback.showError(
        context,
        AppLocalizations.of(context).tableUpdateError,
      );
    }
  }
}
