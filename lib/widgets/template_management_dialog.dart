import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import '../providers/template_provider.dart';
import '../providers/table_provider.dart';
import 'create_template_dialog.dart';

class TemplateManagementDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.article_outlined, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tablo Şablonları',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Consumer<TemplateProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!provider.hasTemplates) {
                    return _buildEmptyState(context);
                  }

                  return _buildTemplateList(context, provider);
                },
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Yeni Şablon Oluştur'),
                      onPressed: () => _showCreateTemplateDialog(context),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Henüz şablon oluşturmadınız',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Sık kullandığınız tablo yapılarını şablon olarak kaydedin',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(BuildContext context, TemplateProvider provider) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: provider.templates.length,
      itemBuilder: (context, index) {
        final template = provider.templates[index];
        
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.table_chart, color: Colors.blue[700]),
            ),
            title: Text(
              template.templateName,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${template.columns.length} sütun'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () => _createTableFromTemplate(context, template),
                  tooltip: 'Bu şablondan tablo oluştur',
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTemplate(context, index),
                  tooltip: 'Şablonu sil',
                ),
              ],
            ),
            onTap: () => _showTemplateDetails(context, template),
          ),
        );
      },
    );
  }

  void _showCreateTemplateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateTemplateDialog(),
    );
  }

  void _createTableFromTemplate(BuildContext context, TemplateModel template) {
    final tableNameController = TextEditingController(text: template.templateName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Şablondan Tablo Oluştur'),
        content: TextField(
          controller: tableNameController,
          decoration: InputDecoration(
            labelText: 'Tablo Adı',
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
              if (tableNameController.text.trim().isNotEmpty) {
                final tableProvider = Provider.of<TableProvider>(context, listen: false);
                final success = await tableProvider.createTable(
                  tableNameController.text.trim(),
                  List.from(template.columns),
                );
                
                Navigator.pop(context); // Template dialog'u kapat
                Navigator.pop(context); // Template management dialog'u kapat
                
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tablo oluşturulamadı')),
                  );
                }
              }
            },
            child: Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _deleteTemplate(BuildContext context, int index) {
    final provider = Provider.of<TemplateProvider>(context, listen: false);
    final templateName = provider.templates[index].templateName;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Şablonu Sil'),
        content: Text('$templateName şablonunu silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteTemplate(index);
              Navigator.pop(context);
            },
            child: Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTemplateDetails(BuildContext context, TemplateModel template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.templateName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sütunlar:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ...template.columns.map((col) => Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    col.isNumeric ? Icons.numbers : Icons.text_fields,
                    size: 16,
                    color: col.isNumeric ? Colors.green : Colors.blue,
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text(col.name)),
                  if (col.autoFillOptions.isNotEmpty)
                    Icon(Icons.auto_fix_high, size: 16, color: Colors.orange),
                ],
              ),
            )).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat'),
          ),
        ],
      ),
    );
  }
}