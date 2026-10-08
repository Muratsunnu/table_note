import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import '../providers/template_provider.dart';
import '../providers/table_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import 'create_template_dialog.dart';
import 'edit_template_dialog.dart';
import '../l10n/app_localizations.dart';

class TemplateManagementDialog extends StatefulWidget {
  const TemplateManagementDialog({Key? key}) : super(key: key);

  @override
  State<TemplateManagementDialog> createState() =>
      _TemplateManagementDialogState();
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
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
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.article_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).tableTemplates,
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
              if (!provider.hasTemplates) return SizedBox();
              return IconButton(
                icon: Icon(
                  _isSearching
                      ? Icons.search_off_rounded
                      : Icons.search_rounded,
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
                tooltip: _isSearching
                    ? AppLocalizations.of(context).closeSearch
                    : AppLocalizations.of(context).searchTemplate,
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
                  hintText: AppLocalizations.of(context).typeTemplateName,
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
          Icon(
            Icons.article_outlined,
            size: 60,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noTemplatesCreated,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).saveFrequentStructures,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Text(
              AppLocalizations.of(context).showingTemplates(
                filteredTemplates.length,
                provider.templates.length,
              ),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.article_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  title: _buildHighlightedText(
                    template.templateName,
                    _searchQuery,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${template.columns.length} sütun',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                      PopupMenuItem(
                        value: 'create',
                        child: ListTile(
                          leading: const Icon(
                            Icons.add_circle_outline,
                            color: AppTheme.success,
                          ),
                          title: Text(AppLocalizations.of(context).createTable),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: const Icon(
                            Icons.edit_outlined,
                            color: AppTheme.primaryBlue,
                          ),
                          title: Text(AppLocalizations.of(context).edit),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.error,
                          ),
                          title: Text(AppLocalizations.of(context).delete),
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
              color: AppTheme.tintedSurface(context, AppTheme.warning),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppTheme.warning,
            ),
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noResults,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).deleteTemplateConfirm(_searchQuery),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text(AppLocalizations.of(context).createNewTemplate),
              style: FilledButton.styleFrom(
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
      return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
    }

    final endIndex = startIndex + query.length;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
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
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CreateTemplateDialog(),
      ),
    );
  }

  void _editTemplate(BuildContext context, int templateIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EditTemplateDialog(templateIndex: templateIndex),
      ),
    );
  }

  Future<void> _createTableFromTemplate(
    BuildContext context,
    TemplateModel template,
  ) async {
    final managementRoute = ModalRoute.of(context);
    final managementNavigator = Navigator.of(context);
    final tableNameController = TextEditingController(
      text: template.templateName,
    );
    final columns = template.columns
        .map((column) => column.copyWith())
        .toList();
    final quickSelectionControllers = <int, TextEditingController>{
      for (var i = 0; i < columns.length; i++)
        if (columns[i].isNormal)
          i: TextEditingController(text: columns[i].autoFillOptions.join('\n')),
    };
    String? nameError;
    bool isSaving = false;

    final route = DialogRoute<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).createTableFromTemplate),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: tableNameController,
                enabled: !isSaving,
                onChanged: (_) {
                  if (nameError != null) setDialogState(() => nameError = null);
                },
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).tableName,
                  errorText: nameError,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (quickSelectionControllers.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context).quickSelectionList,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).templateQuickSelectionHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final entry in quickSelectionControllers.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: entry.value,
                      enabled: !isSaving,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: columns[entry.key].name,
                        hintText: AppLocalizations.of(
                          context,
                        ).quickSelectionLinesHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (tableNameController.text.trim().isEmpty) {
                        setDialogState(() {
                          nameError = AppLocalizations.of(
                            context,
                          ).tableNameEmpty;
                        });
                        return;
                      }
                      final tableProvider = Provider.of<TableProvider>(
                        context,
                        listen: false,
                      );
                      setDialogState(() => isSaving = true);
                      final newColumns = columns
                          .map((column) => column.copyWith())
                          .toList();
                      for (final entry in quickSelectionControllers.entries) {
                        if (entry.value.text !=
                            columns[entry.key].autoFillOptions.join('\n')) {
                          newColumns[entry.key].autoFillOptions = entry
                              .value
                              .text
                              .split(RegExp(r'\r?\n'))
                              .map((option) => option.trim())
                              .where((option) => option.isNotEmpty)
                              .toList();
                        }
                      }
                      final success = await tableProvider.createTable(
                        tableNameController.text.trim(),
                        newColumns,
                        isPremium: context
                            .read<SubscriptionProvider>()
                            .hasUnlimitedPlan,
                      );

                      if (!dialogContext.mounted) return;
                      if (success) {
                        Navigator.pop(dialogContext, true);
                      } else {
                        setDialogState(() {
                          isSaving = false;
                          nameError = AppLocalizations.of(
                            context,
                          ).tableCreateFailed;
                        });
                      }
                    },
              child: Text(AppLocalizations.of(context).create),
            ),
          ],
        ),
      ),
    );
    final created = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(route);
    // The text field remains mounted throughout the closing animation.
    await route.completed;
    tableNameController.dispose();
    for (final controller in quickSelectionControllers.values) {
      controller.dispose();
    }
    if (created == true && mounted && managementRoute?.isCurrent == true) {
      managementNavigator.pop();
    }
  }

  void _deleteTemplate(BuildContext context, int index) {
    final provider = Provider.of<TemplateProvider>(context, listen: false);
    final templateName = provider.templates[index].templateName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteTemplate),
        content: Text(
          AppLocalizations.of(context).deleteTemplateConfirm(templateName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              await provider.deleteTemplate(index);
              Navigator.pop(context);
            },
            child: Text(
              AppLocalizations.of(context).delete,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
