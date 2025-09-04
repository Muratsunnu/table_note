import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';

class TableSelectorMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        if (!provider.hasTables) return SizedBox();
        
        return PopupMenuButton<int>(
          icon: Icon(Icons.table_chart),
          tooltip: 'Tablo Seç',
          onSelected: (index) => provider.changeTable(index),
          itemBuilder: (context) {
            return provider.tables.asMap().entries.map((entry) {
              final isActive = entry.key == provider.currentTableIndex;
              
              return PopupMenuItem<int>(
                value: entry.key,
                child: Row(
                  children: [
                    if (isActive)
                      Icon(Icons.check, color: Colors.green, size: 16),
                    SizedBox(width: isActive ? 8 : 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.value.tableName,
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            '${entry.value.rows.length} kayıt',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 16),
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteTableDialog(context, entry.key);
                      },
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }

  void _showDeleteTableDialog(BuildContext context, int tableIndex) {
    final provider = Provider.of<TableProvider>(context, listen: false);
    final tableName = provider.tables[tableIndex].tableName;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tabloyu Sil'),
        content: Text('$tableName tablosunu silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteTable(tableIndex);
              Navigator.pop(context);
            },
            child: Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}