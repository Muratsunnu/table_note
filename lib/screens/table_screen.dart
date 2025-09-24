import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../widgets/table_list_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/create_table_dialog.dart';
import '../widgets/table_selector_menu.dart';
import '../widgets/add_row_dialog.dart';
import '../widgets/template_management_dialog.dart';
import '../widgets/column_sums_widget.dart';

class TableScreen extends StatefulWidget {
  @override
  _TableScreenState createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<TableProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (!provider.hasTables) {
            return EmptyStateWidget(
              onCreateTable: () => _showCreateTableDialog(context),
            );
          }

          return Column(
            children: [
              Expanded(child: TableListWidget()),
              ColumnSumsWidget(),
            ],
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('Table Note'),
      backgroundColor: Colors.blue[700],
      actions: [
        IconButton(
          icon: Icon(Icons.article_outlined),
          onPressed: () => _showTemplateDialog(context),
          tooltip: 'Tablo Şablonları',
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline),
          onPressed: () => _showCreateTableDialog(context),
          tooltip: 'Yeni Tablo Oluştur',
        ),
        TableSelectorMenu(),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        if (!provider.hasTables) return SizedBox();
        
        return FloatingActionButton(
          onPressed: () => _showAddRowDialog(context),
          child: Icon(Icons.add),
          tooltip: 'Yeni Kayıt Ekle',
        );
      },
    );
  }

  void _showCreateTableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateTableDialog(),
    );
  }

  void _showAddRowDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddRowDialog(),
    );
  }

  void _showTemplateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TemplateManagementDialog(),
    );
  }
}
