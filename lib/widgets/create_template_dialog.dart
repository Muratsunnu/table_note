import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import '../providers/template_provider.dart';

class CreateTemplateDialog extends StatefulWidget {
  @override
  _CreateTemplateDialogState createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<CreateTemplateDialog> {
  final _templateNameController = TextEditingController();
  final List<ColumnModel> _columns = [];

  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _autoFillControllers = [];

  final Map<int, bool> _showAutoFillInput = {};

  @override
  void initState() {
    super.initState();
    _addColumn(); // ilk sütunu ekle
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    for (var c in _nameControllers) {
      c.dispose();
    }
    for (var c in _autoFillControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Yeni Şablon Oluştur'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _templateNameController,
              decoration: InputDecoration(
                labelText: 'Şablon Adı',
                hintText: 'Örn: Günlük Rapor Şablonu',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Sütunlar:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ..._buildColumnWidgets(),
            SizedBox(height: 8),
            OutlinedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Sütun Ekle'),
              onPressed: _addColumn,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _createTemplate,
          child: Text('Oluştur'),
        ),
      ],
    );
  }

  List<Widget> _buildColumnWidgets() {
    return _columns.asMap().entries.map((entry) {
      int index = entry.key;
      ColumnModel column = entry.value;

      return Card(
        margin: EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Sütun ${index + 1}',
                        hintText: 'Sütun adı',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        column.name = value;
                      },
                    ),
                  ),
                  if (_columns.length > 1) ...[
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeColumn(index),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: Text('Sayısal Sütun'),
                      value: column.isNumeric,
                      onChanged: (value) {
                        setState(() {
                          column.isNumeric = value ?? false;
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              if (column.autoFillOptions.isNotEmpty ||
                  _showAutoFillInput[index] == true) ...[
                SizedBox(height: 8),
                TextField(
                  controller: _autoFillControllers[index],
                  decoration: InputDecoration(
                    labelText: 'Otomatik Doldurma Seçenekleri',
                    hintText: 'Seçenekleri virgülle ayırın',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear),
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
                SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.auto_fix_high, size: 16),
                  label: Text('Otomatik Doldurma Ekle'),
                  onPressed: () {
                    setState(() {
                      _showAutoFillInput[index] = true;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  void _addColumn() {
    setState(() {
      final newColumn = ColumnModel(name: '');
      _columns.add(newColumn);

      _nameControllers.add(TextEditingController(text: newColumn.name));
      _autoFillControllers.add(
          TextEditingController(text: newColumn.autoFillOptions.join(', ')));
    });
  }

  void _removeColumn(int index) {
    setState(() {
      _columns.removeAt(index);
      _nameControllers[index].dispose();
      _autoFillControllers[index].dispose();
      _nameControllers.removeAt(index);
      _autoFillControllers.removeAt(index);
      _showAutoFillInput.remove(index);
    });
  }

  Future<void> _createTemplate() async {
    final templateName = _templateNameController.text.trim();
    final validColumns = _columns
        .where((col) => col.name.trim().isNotEmpty)
        .toList();

    if (templateName.isEmpty) {
      _showErrorSnackBar('Şablon adı boş olamaz');
      return;
    }

    if (validColumns.isEmpty) {
      _showErrorSnackBar('En az bir sütun eklemelisiniz');
      return;
    }

    final provider = Provider.of<TemplateProvider>(context, listen: false);
    final success = await provider.createTemplate(templateName, validColumns);

    if (success) {
      Navigator.pop(context);
    } else {
      _showErrorSnackBar('Şablon oluşturulamadı');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
