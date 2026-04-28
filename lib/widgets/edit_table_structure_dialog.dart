import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tabel_model.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class EditTableStructureDialog extends StatefulWidget {
  const EditTableStructureDialog({Key? key}) : super(key: key);

  @override
  State<EditTableStructureDialog> createState() => _EditTableStructureDialogState();
}

class _EditTableStructureDialogState extends State<EditTableStructureDialog> {
  late List<ColumnModel> _columns;
  late List<TextEditingController> _nameControllers;
  late List<TextEditingController> _constantValueControllers;
  late List<TextEditingController> _formulaControllers;
  late String _tableName;
  late TextEditingController _tableNameController;
  
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
    _nameControllers = _columns.map((col) => TextEditingController(text: col.name)).toList();
    _constantValueControllers = _columns.map((col) => 
      TextEditingController(text: col.constantValue?.toString() ?? '')).toList();
    _formulaControllers = _columns.map((col) => 
      TextEditingController(text: col.formula ?? '')).toList();
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
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.lightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings_rounded, color: AppTheme.primaryBlue, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).editTableStructure,
              style: TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tablo adı
              TextField(
                controller: _tableNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).tableName,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.table_chart, color: Colors.blue[700]),
                ),
                onChanged: (value) => _tableName = value,
              ),
              
              const SizedBox(height: 20),
              
              // Sütunlar başlığı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${AppLocalizations.of(context).columns} (${_columns.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addNewColumn,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppLocalizations.of(context).newColumn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        ElevatedButton.icon(
          onPressed: _saveChanges,
          icon: const Icon(Icons.save),
          label: Text(AppLocalizations.of(context).save),
        ),
      ],
    );
  }

  List<Widget> _buildColumnList() {
    return _columns.asMap().entries.map((entry) {
      final index = entry.key;
      final column = entry.value;
      final isNewColumn = index >= _originalColumnCount;
      
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: isNewColumn ? Colors.green[50] : null,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
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
              TextField(
                controller: _nameControllers[index],
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).columnNameLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label),
                ),
                onChanged: (value) => column.name = value,
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
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).typeName(_getColumnTypeName(column.columnType)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        AppLocalizations.of(context).cannotChange,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
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
        return const Icon(Icons.format_list_numbered, color: Colors.brown, size: 20);
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
        color: Colors.grey[100],
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
              _buildTypeChip(index, column, ColumnType.normal, AppLocalizations.of(context).normal, Icons.edit, Colors.blue),
              _buildTypeChip(index, column, ColumnType.constant, AppLocalizations.of(context).constant, Icons.pin, Colors.orange),
              _buildTypeChip(index, column, ColumnType.formula, AppLocalizations.of(context).formula, Icons.functions, Colors.purple),
              _buildTypeChip(index, column, ColumnType.date, AppLocalizations.of(context).date, Icons.calendar_today, Colors.teal),
              _buildTypeChip(index, column, ColumnType.time, AppLocalizations.of(context).time, Icons.access_time, Colors.indigo),
              _buildTypeChip(index, column, ColumnType.autoNumber, AppLocalizations.of(context).autoNumber, Icons.format_list_numbered, Colors.brown),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(int index, ColumnModel column, ColumnType type, String label, IconData icon, Color color) {
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
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 11,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            column.columnType = type;
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
          title: Text(AppLocalizations.of(context).numericColumn, style: const TextStyle(fontSize: 13)),
          value: column.isNumeric,
          onChanged: (value) => setState(() => column.isNumeric = value ?? false),
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
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.pin, color: Colors.orange),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            column.constantValue = double.tryParse(value);
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
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.functions, color: Colors.purple),
          ),
          onChanged: (value) => column.formula = value,
        ),
        if (availableColumns.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(AppLocalizations.of(context).addColumnLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableColumns.map((col) {
              return ActionChip(
                label: Text(
                  col.name, 
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                  ),
                ),
                backgroundColor: AppTheme.lightBlue,
                side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
                onPressed: () {
                  final current = _formulaControllers[index].text;
                  _formulaControllers[index].text = '$current{${col.name}}';
                  column.formula = _formulaControllers[index].text;
                },
              );
            }).toList(),
          ),
          SizedBox(height: 8),
          Text(AppLocalizations.of(context).addOperation, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
                backgroundColor: AppTheme.formulaLight,
                side: BorderSide(color: AppTheme.formula.withOpacity(0.3)),
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
      });
    }
  }

  Future<void> _saveChanges() async {
    // Validasyon
    _tableName = _tableNameController.text.trim();
    if (_tableName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tableNameEmpty)),
      );
      return;
    }

    // Sütun isimlerini güncelle
    for (int i = 0; i < _columns.length; i++) {
      _columns[i].name = _nameControllers[i].text.trim();
      
      if (_columns[i].name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).columnNameEmpty(i + 1))),
        );
        return;
      }
      
      // Yeni sütunlar için ek ayarları güncelle
      if (i >= _originalColumnCount) {
        if (_columns[i].isConstant) {
          _columns[i].constantValue = double.tryParse(_constantValueControllers[i].text);
        }
        if (_columns[i].isFormula) {
          _columns[i].formula = _formulaControllers[i].text.trim().isEmpty 
              ? null 
              : _formulaControllers[i].text.trim();
        }
      }
    }

    // Kaydet
    final provider = Provider.of<TableProvider>(context, listen: false);
    final success = await provider.updateTableStructure(
      _tableName,
      _columns,
      _originalColumnCount,
    );

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tableStructureUpdated),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tableUpdateError),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}