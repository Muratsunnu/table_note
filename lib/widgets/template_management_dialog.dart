import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import '../providers/template_provider.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import 'create_template_dialog.dart';
import 'edit_template_dialog.dart';

class TemplateManagementDialog extends StatefulWidget {
  const TemplateManagementDialog({Key? key}) : super(key: key);

  @override
  State<TemplateManagementDialog> createState() => _TemplateManagementDialogState();
}

class _TemplateManagementDialogState extends State<TemplateManagementDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Arama kutusu (şablon varsa göster)
            Consumer<TemplateProvider>(
              builder: (context, provider, child) {
                if (!provider.hasTemplates) return const SizedBox();
                return _buildSearchBar();
              },
            ),

            // Content
            Expanded(
              child: Consumer<TemplateProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!provider.hasTemplates) {
                    return _buildEmptyState();
                  }

                  return _buildTemplateList(provider);
                },
              ),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkBlue, AppTheme.primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.article_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tablo Şablonları',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // Arama toggle butonu
          Consumer<TemplateProvider>(
            builder: (context, provider, child) {
              if (!provider.hasTemplates) return const SizedBox();
              return IconButton(
                icon: Icon(
                  _isSearching ? Icons.search_off_rounded : Icons.search_rounded,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
                tooltip: _isSearching ? 'Aramayı Kapat' : 'Şablon Ara',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isSearching ? 70 : 0,
      child: _isSearching
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Şablon adı yazın...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Henüz şablon oluşturmadınız',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Sık kullandığınız tablo yapılarını şablon olarak kaydedin',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(TemplateProvider provider) {
    // Filtrelenmiş şablonlar
    final filteredTemplates = provider.templates.where((template) {
      return template.templateName.toLowerCase().contains(_searchQuery);
    }).toList();

    // Arama sonucu boşsa
    if (filteredTemplates.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      children: [
        // Sonuç sayısı
        if (_searchQuery.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            color: AppTheme.background,
            child: Text(
              '${filteredTemplates.length} / ${provider.templates.length} şablon gösteriliyor',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

        // Liste
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredTemplates.length,
            itemBuilder: (context, index) {
              final template = filteredTemplates[index];
              final originalIndex = provider.templates.indexOf(template);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.article_rounded, color: AppTheme.primaryBlue),
                  ),
                  title: _buildHighlightedText(template.templateName, _searchQuery),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${template.columns.length} sütun',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                    tooltip: 'İşlemler',
                    onSelected: (value) {
                      switch (value) {
                        case 'create':
                          _createTableFromTemplate(context, template);
                          break;
                        case 'edit':
                          _editTemplate(context, originalIndex);
                          break;
                        case 'delete':
                          _deleteTemplate(context, originalIndex);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'create',
                        child: ListTile(
                          leading: Icon(Icons.add_circle_outline, color: AppTheme.success),
                          title: Text('Tablo Oluştur'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
                          title: Text('Düzenle'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: AppTheme.error),
                          title: Text('Sil'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _createTableFromTemplate(context, template),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.warningLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.warning),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sonuç bulunamadı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"$_searchQuery" ile eşleşen şablon yok',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni Şablon Oluştur'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showCreateTemplateDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  // Arama sorgusunu vurgulayan text widget
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );
    }

    final endIndex = startIndex + query.length;

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              backgroundColor: Colors.yellow[300],
              color: Colors.black,
            ),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }

  void _showCreateTemplateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateTemplateDialog(),
    );
  }

  void _editTemplate(BuildContext context, int templateIndex) {
    showDialog(
      context: context,
      builder: (context) => EditTemplateDialog(templateIndex: templateIndex),
    );
  }

  void _createTableFromTemplate(BuildContext context, TemplateModel template) {
    final tableNameController = TextEditingController(text: template.templateName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şablondan Tablo Oluştur'),
        content: TextField(
          controller: tableNameController,
          decoration: const InputDecoration(
            labelText: 'Tablo Adı',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tableNameController.text.trim().isNotEmpty) {
                final tableProvider = Provider.of<TableProvider>(context, listen: false);
                final success = await tableProvider.createTable(
                  tableNameController.text.trim(),
                  List.from(template.columns),
                );

                Navigator.pop(context); // Dialog'u kapat
                Navigator.pop(context); // Template management dialog'u kapat

                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tablo oluşturulamadı')),
                  );
                }
              }
            },
            child: const Text('Oluştur'),
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
        title: const Text('Şablonu Sil'),
        content: Text('$templateName şablonunu silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteTemplate(index);
              Navigator.pop(context);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sütunlar:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...template.columns.map((col) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      col.isNumeric ? Icons.numbers : Icons.text_fields,
                      size: 18,
                      color: col.isNumeric ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(col.name)),
                    if (col.autoFillOptions.isNotEmpty)
                      Tooltip(
                        message: col.autoFillOptions.join(', '),
                        child: Icon(Icons.auto_fix_high, size: 18, color: Colors.orange),
                      ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}