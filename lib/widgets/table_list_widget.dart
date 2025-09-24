import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import '../providers/table_provider.dart';
import 'edit_row_dialog.dart';

class TableListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        final currentTable = provider.currentTable!;
        
        return Column(
          children: [
            // Tablo başlığı - Düzenleme özelliği eklendi
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showRenameDialog(context, provider),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentTable.tableName,
                              style: TextStyle(
                                fontSize: 20, 
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                          Icon(Icons.edit, size: 16, color: Colors.blue[600]),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '${currentTable.rows.length} kayıt',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Tablo içeriği
            Expanded(
              child: currentTable.rows.isEmpty
                  ? _buildEmptyTableState(context)
                  : _buildTableData(context, currentTable, provider),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, TableProvider provider) {
    final controller = TextEditingController(text: provider.currentTable!.tableName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tablo Adını Değiştir'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Yeni Tablo Adı',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final success = await provider.renameTable(
                  provider.currentTableIndex,
                  controller.text.trim(),
                );
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tablo adı değiştirilemedi')),
                  );
                }
              }
            },
            child: Text('Değiştir'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTableState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Bu tabloda henüz kayıt yok',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'İlk kaydınızı eklemek için + butonuna dokunun',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTableData(BuildContext context, TableModel currentTable, TableProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 20,
          columns: [
            ...currentTable.columns.map((col) {
              return DataColumn(
                label: Container(
                  constraints: BoxConstraints(maxWidth: 120),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          col.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (col.isNumeric) ...[
                        SizedBox(width: 4),
                        Icon(Icons.numbers, size: 16, color: Colors.green),
                      ],
                      if (col.autoFillOptions.isNotEmpty) ...[
                        SizedBox(width: 4),
                        Icon(Icons.auto_fix_high, size: 16, color: Colors.orange),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
            DataColumn(
              label: Text(
                'İşlemler',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: currentTable.rows.asMap().entries.map((entry) {
            int rowIndex = entry.key;
            List<String> row = entry.value;
            
            return DataRow(
              cells: [
                ...row.map((cell) {
                  return DataCell(
                    Container(
                      constraints: BoxConstraints(maxWidth: 120),
                      child: Text(
                        cell,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: () => _showEditRowDialog(context, rowIndex, row),
                  );
                }).toList(),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditRowDialog(context, rowIndex, row),
                        tooltip: 'Düzenle',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmDialog(context, rowIndex, provider),
                        tooltip: 'Sil',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEditRowDialog(BuildContext context, int rowIndex, List<String> currentData) {
    showDialog(
      context: context,
      builder: (context) => EditRowDialog(
        rowIndex: rowIndex,
        currentData: currentData,
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, int rowIndex, TableProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kaydı Sil'),
        content: Text('Bu kaydı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteRow(rowIndex);
              Navigator.pop(context);
            },
            child: Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}