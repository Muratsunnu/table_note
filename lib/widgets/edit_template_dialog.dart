import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tabel_model.dart';
import '../providers/template_provider.dart';
import '../theme/app_theme.dart';

class EditTemplateDialog extends StatefulWidget {
  final int templateIndex;
  
  const EditTemplateDialog({Key? key, required this.templateIndex}) : super(key: key);

  @override
  State<EditTemplateDialog> createState() => _EditTemplateDialogState();
}

class _EditTemplateDialogState extends State<EditTemplateDialog> {
  late TextEditingController _templateNameController;
  late List<ColumnModel> _columns;
  late List<TextEditingController> _nameControllers;
  late List<TextEditingController> _constantValueControllers;
  late List<TextEditingController> _formulaControllers;
  late List<TextEditingController> _autoFillControllers;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TemplateProvider>(context, listen: false);
    final template = provider.templates[widget.templateIndex];
    
    _templateNameController = TextEditingController(text: template.templateName);
    
    // Sütunları kopyala
    _columns = template.columns.map((col) => col.copyWith()).toList();
    
    // Controller'ları oluştur
    _nameControllers = _columns.map((col) => TextEditingController(text: col.name)).toList();
    _constantValueControllers = _columns.map((col) => 
      TextEditingController(text: col.constantValue?.toString() ?? '')).toList();
    _formulaControllers = _columns.map((col) => 
      TextEditingController(text: col.formula ?? '')).toList();
    _autoFillControllers = _columns.map((col) => 
      TextEditingController(text: col.autoFillOptions.join(', '))).toList();
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    for (var c in _nameControllers) c.dispose();
    for (var c in _constantValueControllers) c.dispose();
    for (var c in _formulaControllers) c.dispose();
    for (var c in _autoFillControllers) c.dispose();
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
              color: AppTheme.formulaLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_rounded, color: AppTheme.formula, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Şablonu Düzenle',
              style: TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Şablon adı
              TextField(
                controller: _templateNameController,
                decoration: InputDecoration(
                  labelText: 'Şablon Adı',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.article, color: Colors.blue[700]),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Sütunlar başlığı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sütunlar (${_columns.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addColumn,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yeni Sütun'),
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
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _saveTemplate,
          icon: const Icon(Icons.save),
          label: const Text('Kaydet'),
        ),
      ],
    );
  }

  List<Widget> _buildColumnList() {
    return _columns.asMap().entries.map((entry) {
      final index = entry.key;
      final column = entry.value;
      
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sütun başlığı
              Row(
                children: [
                  _getColumnTypeIcon(column.columnType),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sütun ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_columns.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _removeColumn(index),
                      tooltip: 'Sütunu Sil',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Sütun adı
              TextField(
                controller: _nameControllers[index],
                decoration: const InputDecoration(
                  labelText: 'Sütun Adı',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                onChanged: (value) => column.name = value,
              ),
              
              const SizedBox(height: 12),
              
              // Sütun tipi seçimi
              _buildColumnTypeSelector(index, column),
              
              // Tipe göre ek ayarlar
              _buildColumnTypeSettings(index, column),
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
          const Text(
            'Sütun Tipi:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTypeChip(index, column, ColumnType.normal, 'Normal', Icons.edit, Colors.blue),
              _buildTypeChip(index, column, ColumnType.constant, 'Sabit', Icons.pin, Colors.orange),
              _buildTypeChip(index, column, ColumnType.formula, 'Formül', Icons.functions, Colors.purple),
              _buildTypeChip(index, column, ColumnType.date, 'Tarih', Icons.calendar_today, Colors.teal),
              _buildTypeChip(index, column, ColumnType.time, 'Saat', Icons.access_time, Colors.indigo),
              _buildTypeChip(index, column, ColumnType.autoNumber, 'Sıra No', Icons.format_list_numbered, Colors.brown),
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
        return _buildInfoBox('Kayıt eklerken bugünün tarihi otomatik gelir.', Colors.teal);
      case ColumnType.time:
        return _buildInfoBox('Kayıt eklerken şu anki saat otomatik gelir.', Colors.indigo);
      case ColumnType.autoNumber:
        return _buildInfoBox('Her kayıt için otomatik artan numara (1, 2, 3...) atanır.', Colors.brown);
    }
  }

  Widget _buildInfoBox(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalSettings(int index, ColumnModel column) {
    return Column(
      children: [
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Sayısal Sütun', style: TextStyle(fontSize: 13)),
          subtitle: const Text('Bu sütundaki değerler toplanabilir', style: TextStyle(fontSize: 11)),
          value: column.isNumeric,
          onChanged: (value) => setState(() => column.isNumeric = value ?? false),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _autoFillControllers[index],
          decoration: const InputDecoration(
            labelText: 'Hızlı Seçim Listesi (opsiyonel)',
            hintText: 'Virgülle ayırın: Ankara, İstanbul, İzmir',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.list),
          ),
          onChanged: (value) {
            column.autoFillOptions = value
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          },
        ),
      ],
    );
  }

  Widget _buildConstantSettings(int index, ColumnModel column) {
    return Column(
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _constantValueControllers[index],
          decoration: const InputDecoration(
            labelText: 'Varsayılan Değer',
            hintText: 'Örn: 0.2',
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
    final availableColumns = _columns
        .asMap()
        .entries
        .where((e) => e.key != index && e.value.name.trim().isNotEmpty)
        .map((e) => e.value)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _formulaControllers[index],
          decoration: const InputDecoration(
            labelText: 'Formül',
            hintText: 'Örn: {Kg}*{Birim Fiyat}',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.functions, color: Colors.purple),
            helperText: 'İşlemler: + - * / % (yüzde)',
          ),
          onChanged: (value) => column.formula = value,
        ),
        if (availableColumns.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Sütun ekle:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
                  setState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text('İşlem ekle:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _addColumn() {
    setState(() {
      final newColumn = ColumnModel(name: '');
      _columns.add(newColumn);
      _nameControllers.add(TextEditingController());
      _constantValueControllers.add(TextEditingController());
      _formulaControllers.add(TextEditingController());
      _autoFillControllers.add(TextEditingController());
    });
  }

  void _removeColumn(int index) {
    if (_columns.length > 1) {
      setState(() {
        _columns.removeAt(index);
        _nameControllers[index].dispose();
        _nameControllers.removeAt(index);
        _constantValueControllers[index].dispose();
        _constantValueControllers.removeAt(index);
        _formulaControllers[index].dispose();
        _formulaControllers.removeAt(index);
        _autoFillControllers[index].dispose();
        _autoFillControllers.removeAt(index);
      });
    }
  }

  Future<void> _saveTemplate() async {
    final templateName = _templateNameController.text.trim();
    
    if (templateName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şablon adı boş olamaz')),
      );
      return;
    }

    // Sütun isimlerini güncelle
    for (int i = 0; i < _columns.length; i++) {
      _columns[i].name = _nameControllers[i].text.trim();
      
      if (_columns[i].name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sütun ${i + 1} adı boş olamaz')),
        );
        return;
      }
      
      // Tip ayarlarını güncelle
      if (_columns[i].isConstant) {
        _columns[i].constantValue = double.tryParse(_constantValueControllers[i].text);
      }
      if (_columns[i].isFormula) {
        _columns[i].formula = _formulaControllers[i].text.trim().isEmpty 
            ? null 
            : _formulaControllers[i].text.trim();
      }
      if (_columns[i].isNormal) {
        _columns[i].autoFillOptions = _autoFillControllers[i].text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }

    final provider = Provider.of<TemplateProvider>(context, listen: false);
    final success = await provider.updateTemplate(
      widget.templateIndex,
      templateName,
      _columns,
    );

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şablon güncellendi'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şablon güncellenirken hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}