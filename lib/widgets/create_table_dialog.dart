import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';

class CreateTableDialog extends StatefulWidget {
  @override
  _CreateTableDialogState createState() => _CreateTableDialogState();
}

class _CreateTableDialogState extends State<CreateTableDialog> {
  final _tableNameController = TextEditingController();
  final List<TextEditingController> _columnControllers = [TextEditingController()];

  @override
  void dispose() {
    _tableNameController.dispose();
    for (var controller in _columnControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Yeni Tablo Oluştur'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _tableNameController,
              decoration: InputDecoration(
                labelText: 'Tablo Adı',
                hintText: 'Örn: Günlük Kayıtlar',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Sütun Başlıkları:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ..._columnControllers.asMap().entries.map((entry) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: 'Sütun ${entry.key + 1}',
                          hintText: entry.key == 0 ? 'Örn: Tarih' : 'Sütun adı',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    if (_columnControllers.length > 1) ...[
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            entry.value.dispose();
                            _columnControllers.removeAt(entry.key);
                          });
                        },
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            SizedBox(height: 8),
            OutlinedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Sütun Ekle'),
              onPressed: () {
                setState(() {
                  _columnControllers.add(TextEditingController());
                });
              },
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
          onPressed: _createTable,
          child: Text('Oluştur'),
        ),
      ],
    );
  }

  Future<void> _createTable() async {
    final tableName = _tableNameController.text.trim();
    final columns = _columnControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (tableName.isEmpty) {
      _showErrorSnackBar('Tablo adı boş olamaz');
      return;
    }

    if (columns.isEmpty) {
      _showErrorSnackBar('En az bir sütun eklemelisiniz');
      return;
    }

    final provider = Provider.of<TableProvider>(context, listen: false);
    final success = await provider.createTable(tableName, columns);

    if (success) {
      Navigator.pop(context);
    } else {
      _showErrorSnackBar('Tablo oluşturulamadı');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}