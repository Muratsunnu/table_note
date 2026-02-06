import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import '../providers/template_provider.dart';
import '../theme/app_theme.dart';

class CreateTemplateDialog extends StatefulWidget {
  const CreateTemplateDialog({Key? key}) : super(key: key);

  @override
  State<CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<CreateTemplateDialog> {
  final _templateNameController = TextEditingController();
  final List<ColumnModel> _columns = [];

  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _autoFillControllers = [];
  final List<TextEditingController> _constantValueControllers = [];
  final List<TextEditingController> _formulaControllers = [];
  final Map<int, bool> _showAutoFillInput = {};

  @override
  void initState() {
    super.initState();
    _addColumn();
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    for (var c in _nameControllers) c.dispose();
    for (var c in _autoFillControllers) c.dispose();
    for (var c in _constantValueControllers) c.dispose();
    for (var c in _formulaControllers) c.dispose();
    super.dispose();
  }

  void _initializeControllersForColumn(ColumnModel col) {
    _nameControllers.add(TextEditingController(text: col.name));
    _autoFillControllers.add(TextEditingController(text: col.autoFillOptions.join(', ')));
    _constantValueControllers.add(TextEditingController(
      text: col.constantValue?.toString() ?? '',
    ));
    _formulaControllers.add(TextEditingController(text: col.formula ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.darkBlue, AppTheme.primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.article_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Yeni Şablon Oluştur',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _templateNameController,
                      decoration: InputDecoration(
                        labelText: 'Şablon Adı',
                        hintText: 'Örn: Sefer Kayıt Şablonu',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.article_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.lightBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.view_column_rounded, size: 18, color: AppTheme.primaryBlue),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Sütunlar',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._buildColumnWidgets(),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Sütun Ekle'),
                      onPressed: _addColumn,
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Şablon Oluştur'),
                      onPressed: _createTemplate,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildColumnWidgets() {
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
              // Sütun adı
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Sütun ${index + 1}',
                        hintText: 'Sütun adı',
                        border: const OutlineInputBorder(),
                        prefixIcon: _getColumnTypeIcon(column.columnType),
                      ),
                      onChanged: (value) => column.name = value,
                    ),
                  ),
                  if (_columns.length > 1) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeColumn(index),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Sütun tipi seçimi
              _buildColumnTypeSelector(index, column),

              // Tipe göre ayarlar
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
        return const Icon(Icons.edit, color: Colors.blue);
      case ColumnType.constant:
        return const Icon(Icons.pin, color: Colors.orange);
      case ColumnType.formula:
        return const Icon(Icons.functions, color: Colors.purple);
      case ColumnType.date:
        return const Icon(Icons.calendar_today, color: Colors.teal);
      case ColumnType.time:
        return const Icon(Icons.access_time, color: Colors.indigo);
      case ColumnType.autoNumber:
        return const Icon(Icons.format_list_numbered, color: Colors.brown);
    }
  }

  Widget _buildColumnTypeSelector(int index, ColumnModel column) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTypeChip(index, column, ColumnType.normal, 'Normal', Icons.edit, Colors.blue),
        _buildTypeChip(index, column, ColumnType.constant, 'Sabit', Icons.pin, Colors.orange),
        _buildTypeChip(index, column, ColumnType.formula, 'Formül', Icons.functions, Colors.purple),
        _buildTypeChip(index, column, ColumnType.date, 'Tarih', Icons.calendar_today, Colors.teal),
        _buildTypeChip(index, column, ColumnType.time, 'Saat', Icons.access_time, Colors.indigo),
        _buildTypeChip(index, column, ColumnType.autoNumber, 'Sıra No', Icons.format_list_numbered, Colors.brown),
      ],
    );
  }

  Widget _buildTypeChip(int index, ColumnModel column, ColumnType type, String label, IconData icon, Color color) {
    final isSelected = column.columnType == type;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            column.columnType = type;
            if (type == ColumnType.normal) {
              column.constantValue = null;
              column.formula = null;
              column.isNumeric = false;
            } else if (type == ColumnType.date || type == ColumnType.time) {
              column.constantValue = null;
              column.formula = null;
              column.isNumeric = false;
            } else if (type == ColumnType.autoNumber) {
              column.constantValue = null;
              column.formula = null;
              column.isNumeric = true;
            } else {
              column.isNumeric = true;
              if (type == ColumnType.constant) {
                column.formula = null;
              } else {
                column.constantValue = null;
              }
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
        return _buildDateSettings();
      case ColumnType.time:
        return _buildTimeSettings();
      case ColumnType.autoNumber:
        return _buildAutoNumberSettings();
    }
  }

  Widget _buildAutoNumberSettings() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.brown[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.brown[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Her yeni kayıt için otomatik artan numara (1, 2, 3...) atanır.',
              style: TextStyle(fontSize: 12, color: Colors.brown[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSettings() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.teal[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kayıt eklerken bugünün tarihi otomatik gelir, değiştirilebilir.',
              style: TextStyle(fontSize: 12, color: Colors.teal[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSettings() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.indigo[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kayıt eklerken şu anki saat otomatik gelir, değiştirilebilir.',
              style: TextStyle(fontSize: 12, color: Colors.indigo[800]),
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
          title: const Text('Sayısal Sütun'),
          value: column.isNumeric,
          onChanged: (value) => setState(() => column.isNumeric = value ?? false),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (column.autoFillOptions.isNotEmpty || _showAutoFillInput[index] == true) ...[
          TextField(
            controller: _autoFillControllers[index],
            decoration: InputDecoration(
              labelText: 'Hızlı Seçim Listesi',
              hintText: 'Virgülle ayırın',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    column.autoFillOptions.clear();
                    _autoFillControllers[index].clear();
                    _showAutoFillInput[index] = false;
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
          OutlinedButton.icon(
            icon: const Icon(Icons.list, size: 16),
            label: const Text('Hızlı Seçim Ekle'),
            onPressed: () => setState(() => _showAutoFillInput[index] = true),
          ),
        ],
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
          onChanged: (value) => column.constantValue = double.tryParse(value),
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
          ),
          onChanged: (value) => column.formula = value,
        ),
        if (availableColumns.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Sütun ekle:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...availableColumns.map((col) => ActionChip(
                label: Text(
                  col.name, 
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                  ),
                ),
                backgroundColor: AppTheme.lightBlue,
                side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
                onPressed: () {
                  _formulaControllers[index].text += '{${col.name}}';
                  column.formula = _formulaControllers[index].text;
                },
              )),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'İşlem ekle:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildOpChip(index, column, '+'),
              _buildOpChip(index, column, '-'),
              _buildOpChip(index, column, '*'),
              _buildOpChip(index, column, '/'),
              _buildOpChip(index, column, '%'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOpChip(int index, ColumnModel column, String op) {
    return ActionChip(
      label: Text(
        op,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.formula,
        ),
      ),
      backgroundColor: AppTheme.formulaLight,
      side: BorderSide(color: AppTheme.formula.withOpacity(0.3)),
      onPressed: () => _addOperator(index, column, op),
    );
  }

  void _addOperator(int index, ColumnModel column, String op) {
    _formulaControllers[index].text += op;
    column.formula = _formulaControllers[index].text;
  }

  void _addColumn() {
    setState(() {
      final newColumn = ColumnModel(name: '');
      _columns.add(newColumn);
      _initializeControllersForColumn(newColumn);
    });
  }

  void _removeColumn(int index) {
    setState(() {
      _columns.removeAt(index);
      _nameControllers[index].dispose();
      _nameControllers.removeAt(index);
      _autoFillControllers[index].dispose();
      _autoFillControllers.removeAt(index);
      _constantValueControllers[index].dispose();
      _constantValueControllers.removeAt(index);
      _formulaControllers[index].dispose();
      _formulaControllers.removeAt(index);
      _showAutoFillInput.remove(index);
    });
  }

  Future<void> _createTemplate() async {
    final templateName = _templateNameController.text.trim();

    // Controller'lardan verileri senkronize et
    for (int i = 0; i < _columns.length; i++) {
      _columns[i].name = _nameControllers[i].text.trim();
      _columns[i].autoFillOptions = _autoFillControllers[i]
          .text.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      _columns[i].constantValue = double.tryParse(_constantValueControllers[i].text);
      _columns[i].formula = _formulaControllers[i].text.trim().isEmpty
          ? null
          : _formulaControllers[i].text.trim();
    }

    final validColumns = _columns.where((col) => col.name.isNotEmpty).toList();

    if (templateName.isEmpty) {
      _showError('Şablon adı boş olamaz');
      return;
    }

    if (validColumns.isEmpty) {
      _showError('En az bir sütun eklemelisiniz');
      return;
    }

    final provider = Provider.of<TemplateProvider>(context, listen: false);
    final success = await provider.createTemplate(templateName, validColumns);

    if (success) {
      Navigator.pop(context);
    } else {
      _showError('Şablon oluşturulamadı');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}