import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import 'create_table_dialog.dart';
import 'edit_table_structure_dialog.dart';
import 'template_management_dialog.dart';

class TableDrawer extends StatelessWidget {
  const TableDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Tablo listesi
            Expanded(
              child: Consumer<TableProvider>(
                builder: (context, provider, child) {
                  if (!provider.hasTables) {
                    return _buildEmptyState(context);
                  }
                  return _buildTableList(context, provider);
                },
              ),
            ),
            
            // Alt butonlar
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.gradientDecoration(radius: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tablolarım',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tablo seçin veya yeni oluşturun',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Henüz tablo yok',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'İlk tablonuzu oluşturun',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => CreateTableDialog(),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tablo Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableList(BuildContext context, TableProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: provider.tables.length,
      itemBuilder: (context, index) {
        final table = provider.tables[index];
        final isActive = index == provider.currentTableIndex;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.lightBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive 
                ? Border.all(color: AppTheme.primaryBlue.withOpacity(0.3))
                : null,
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive 
                    ? AppTheme.primaryBlue 
                    : AppTheme.textSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.table_chart_rounded,
                color: isActive ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
            ),
            title: Text(
              table.tableName,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? AppTheme.primaryBlue : AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              '${table.rows.length} kayıt • ${table.columns.length} sütun',
              style: TextStyle(
                fontSize: 12,
                color: isActive 
                    ? AppTheme.primaryBlue.withOpacity(0.7) 
                    : AppTheme.textSecondary,
              ),
            ),
            trailing: isActive 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Düzenle
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        color: AppTheme.primaryBlue,
                        onPressed: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (context) => const EditTableStructureDialog(),
                          );
                        },
                        tooltip: 'Yapıyı Düzenle',
                      ),
                    ],
                  )
                : null,
            onTap: () {
              provider.changeTable(index);
              Navigator.pop(context);
            },
            onLongPress: () => _showTableOptions(context, provider, index),
          ),
        );
      },
    );
  }

  void _showTableOptions(BuildContext context, TableProvider provider, int index) {
    final table = provider.tables[index];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Tablo adı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.table_chart_rounded, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        table.tableName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 24),
              
              // Seçenekler
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppTheme.success),
                title: const Text('Tabloya Geç'),
                onTap: () {
                  provider.changeTable(index);
                  Navigator.pop(context); // Bottom sheet
                  Navigator.pop(context); // Drawer
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: AppTheme.primaryBlue),
                title: const Text('Yapıyı Düzenle'),
                onTap: () {
                  provider.changeTable(index);
                  Navigator.pop(context); // Bottom sheet
                  Navigator.pop(context); // Drawer
                  showDialog(
                    context: context,
                    builder: (context) => const EditTableStructureDialog(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                title: const Text('Tabloyu Sil', style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(context); // Bottom sheet
                  _showDeleteConfirmation(context, provider, index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TableProvider provider, int index) {
    final table = provider.tables[index];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Tabloyu Sil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${table.tableName}" tablosunu silmek istediğinizden emin misiniz?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.coloredCardDecoration(AppTheme.error),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${table.rows.length} kayıt kalıcı olarak silinecek.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteTable(index);
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // Drawer
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          // Yeni tablo oluştur
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => CreateTableDialog(),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni Tablo'),
            ),
          ),
          const SizedBox(height: 8),
          // Şablonlar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => const TemplateManagementDialog(),
                );
              },
              icon: const Icon(Icons.article_outlined),
              label: const Text('Şablonlar'),
            ),
          ),
        ],
      ),
    );
  }
}