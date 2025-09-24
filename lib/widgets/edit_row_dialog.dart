import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
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
      content: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: currentTable.columns.asMap().entries.map((entry) {
              int colIndex = entry.key;
              ColumnModel column = entry.value;
              
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controllers[colIndex],
                            decoration: InputDecoration(
                              labelText: column.name,
                              border: OutlineInputBorder(),
                              suffixIcon: column.autoFillOptions.isNotEmpty 
                                  ? PopupMenuButton<String>(
                                      icon: Icon(Icons.arrow_drop_down),
                                      tooltip: 'Hızlı Seç',
                                      onSelected: (value) {
                                        _controllers[colIndex].text = value;
                                      },
                                      itemBuilder: (context) {
                                        return column.autoFillOptions.map((option) {
                                          return PopupMenuItem<String>(
                                            value: option,
                                            child: Text(option),
                                          );
                                        }).toList();
                                      },
                                    )
                                  : null,
                            ),
                            keyboardType: column.isNumeric 
                                ? TextInputType.numberWithOptions(decimal: true)
                                : TextInputType.text,
                          ),
                        ),
                      ],
                    ),
                    // Otomatik doldurma seçenekleri
                    if (column.autoFillOptions.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: column.autoFillOptions.map((option) {
                          return GestureDetector(
                            onTap: () {
                              _controllers[colIndex].text = option;
                            },
                            child: Chip(
                              label: Text(
                                option,
                                style: TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.blue[50],
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
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