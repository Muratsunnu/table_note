import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';

class AddRowDialog extends StatefulWidget {
  @override
  _AddRowDialogState createState() => _AddRowDialogState();
}

class _AddRowDialogState extends State<AddRowDialog> {
  List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TableProvider>(context, listen: false);
    final currentTable = provider.currentTable!;
    _controllers = currentTable.columns.map((col) => TextEditingController()).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TableProvider>(context);
    final currentTable = provider.currentTable!;

    return AlertDialog(
      title: Text('Yeni Kayıt Ekle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: currentTable.columns.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: TextField(
                controller: _controllers[entry.key],
                decoration: InputDecoration(
                  labelText: entry.value,
                  border: OutlineInputBorder(),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _addRow,
          child: Text('Ekle'),
        ),
      ],
    );
  }

  Future<void> _addRow() async {
    final provider = Provider.of<TableProvider>(context, listen: false);
    final rowData = _controllers.map((controller) => controller.text.trim()).toList();
    
    final success = await provider.addRow(rowData);
    
    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt eklenemedi')),
      );
    }
  }
}