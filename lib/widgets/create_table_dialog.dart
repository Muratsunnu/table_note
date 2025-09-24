import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import '../providers/table_provider.dart';
import '../providers/template_provider.dart';

class CreateTableDialog extends StatefulWidget {
  @override
  _CreateTableDialogState createState() => _CreateTableDialogState();
}

class _CreateTableDialogState extends State<CreateTableDialog> with SingleTickerProviderStateMixin {
  final _tableNameController = TextEditingController();

  // Model listesi (senin orijinal)
  final List<ColumnModel> _columns = [ColumnModel(name: '')];

  // --- Yeni: controller ve show-listeleri ---
  final List<TextEditingController> _columnControllers = [];
  final List<TextEditingController> _autoFillControllers = [];
  final List<bool> _showAutoFill = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Mevcut sütunlar için controller'ları bir kez oluştur
    for (var col in _columns) {
      _columnControllers.add(TextEditingController(text: col.name));
      _autoFillControllers.add(TextEditingController(text: col.autoFillOptions.join(', ')));
      _showAutoFill.add(col.autoFillOptions.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _tableNameController.dispose();
    for (var c in _columnControllers) {
      c.dispose();
    }
    for (var c in _autoFillControllers) {
      c.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header with tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.blue[700]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Yeni Tablo Oluştur',
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
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue[700],
                    tabs: [
                      Tab(text: 'Manuel Oluştur'),
                      Tab(text: 'Şablondan Oluştur'),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildManualCreateTab(),
                  _buildTemplateTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualCreateTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            'Sütunlar:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          ..._buildColumnWidgets(),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Sütun Ekle'),
                  onPressed: _addColumn,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _createTable,
                  child: Text('Tablo Oluştur'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateTab() {
    return Consumer<TemplateProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        if (!provider.hasTemplates) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Henüz şablon yok',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Manuel sekmesinde tablo oluşturduktan sonra şablon olarak kaydedebilirsiniz',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

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
                onTap: () => _createTableFromTemplate(template),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildColumnWidgets() {
    return _columns.asMap().entries.map((entry) {
      int index = entry.key;
      ColumnModel column = entry.value;
      
      // güvenlik: controller listelerinin uygun uzunlukta olduğundan emin ol
      if (index >= _columnControllers.length) {
        _columnControllers.add(TextEditingController(text: column.name));
      }
      if (index >= _autoFillControllers.length) {
        _autoFillControllers.add(TextEditingController(text: column.autoFillOptions.join(', ')));
      }
      if (index >= _showAutoFill.length) {
        _showAutoFill.add(column.autoFillOptions.isNotEmpty);
      }

      return Card(
        margin: EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _columnControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Sütun ${index + 1}',
                        hintText: 'Sütun adı',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        // column modelini güncelle
                        column.name = value;
                        // setState sadece UI değişiklikleri için
                        setState(() {});
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
                      subtitle: Text('Bu sütundaki değerleri toplayabilirsiniz'),
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
              if (column.autoFillOptions.isNotEmpty || _showAutoFill[index] == true) ...[
                SizedBox(height: 8),
                TextField(
                  controller: _autoFillControllers[index],
                  decoration: InputDecoration(
                    labelText: 'Otomatik Doldurma Seçenekleri',
                    hintText: 'Seçenekleri virgülle ayırın (örn: İstanbul, Ankara, İzmir)',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          column.autoFillOptions.clear();
                          _autoFillControllers[index].clear();
                          _showAutoFill[index] = false;
                        });
                      },
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      column.autoFillOptions = value
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                    });
                  },
                ),
              ] else ...[
                SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.auto_fix_high, size: 16),
                  label: Text('Otomatik Doldurma Ekle'),
                  onPressed: () {
                    setState(() {
                      _showAutoFill[index] = true;
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
      _columns.add(ColumnModel(name: ''));
      _columnControllers.add(TextEditingController());
      _autoFillControllers.add(TextEditingController());
      _showAutoFill.add(false);
    });
  }

  void _removeColumn(int index) {
    setState(() {
      _columns.removeAt(index);

      // dispose ve listelerden çıkar
      _columnControllers[index].dispose();
      _columnControllers.removeAt(index);

      _autoFillControllers[index].dispose();
      _autoFillControllers.removeAt(index);

      _showAutoFill.removeAt(index);
    });
  }

  Future<void> _createTable() async {
    // Sütun modellerini controller'ların verisiyle senkronize et (güvenlik için)
    for (int i = 0; i < _columns.length; i++) {
      _columns[i].name = _columnControllers[i].text.trim();
      _columns[i].autoFillOptions = _autoFillControllers[i].text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final tableName = _tableNameController.text.trim();
    final validColumns = _columns
        .where((col) => col.name.trim().isNotEmpty)
        .map((col) => ColumnModel(
          name: col.name.trim(),
          isNumeric: col.isNumeric,
          autoFillOptions: List.from(col.autoFillOptions),
        ))
        .toList();

    if (tableName.isEmpty) {
      _showErrorSnackBar('Tablo adı boş olamaz');
      return;
    }

    if (validColumns.isEmpty) {
      _showErrorSnackBar('En az bir sütun eklemelisiniz');
      return;
    }

    final provider = Provider.of<TableProvider>(context, listen: false);
    final success = await provider.createTable(tableName, validColumns);

    if (success) {
      Navigator.pop(context);
    } else {
      _showErrorSnackBar('Tablo oluşturulamadı');
    }
  }

  void _createTableFromTemplate(TemplateModel template) {
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
                
                Navigator.pop(context); // Template dialog
                Navigator.pop(context); // Create table dialog
                
                if (!success) {
                  _showErrorSnackBar('Tablo oluşturulamadı');
                }
              }
            },
            child: Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
