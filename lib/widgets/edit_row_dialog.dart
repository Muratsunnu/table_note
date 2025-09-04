import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';

class EditRowDialog extends StatefulWidget {
  final int rowIndex;
  final List<String> currentData;

  const EditRowDialog({
    Key? key,
    required this.rowIndex,
    required this.currentData,
  }) : super(key: key);

  @override
  _EditRowDialogState createState() => _EditRowDialogState();
}

class _EditRowDialogState extends State<EditRowDialog> {
  List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _controllers = widget.currentData
        .map((data) => TextEditingController(text: data))
        .toList();
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
      title: Text('Kaydı Düzenle'),
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
          onPressed: _updateRow,
          child: Text('Güncelle'),
        ),
      ],
    );
  }

  Future<void> _updateRow() async {
    final provider = Provider.of<TableProvider>(context, listen: false);
    final newRowData = _controllers.map((controller) => controller.text.trim()).toList();
    
    final success = await provider.updateRow(widget.rowIndex, newRowData);
    
    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt güncellenemedi')),
      );
    }
  }
}