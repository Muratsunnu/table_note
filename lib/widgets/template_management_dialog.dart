import 'example_templates_header.dart';
import 'premium_gate.dart';
import '../config/plan_limits.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import '../providers/template_provider.dart';
import '../providers/table_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import 'quick_table_builder.dart';
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

  Widget _buildTemplateList(TemplateProvider provider) {
    // Filtrelenmiş şablonlar
    final filteredTemplates = provider.templates.where((template) {
      return template.templateName.toLowerCase().contains(_searchQuery);
    }).toList();
    // Uygulamayla gelen örnekler kendi şablonlarının ardından gelir ve aynı
    // biçimde kullanılır, düzenlenir, silinir.
    final examples = provider
        .examples(AppLocalizations.of(context).locale.languageCode)
        .where(
          (template) =>
              template.templateName.toLowerCase().contains(_searchQuery),
        )
        .toList();
    final showRestore = provider.hasHiddenExamples && _searchQuery.isEmpty;

    // Arama sonucu boşsa
    if (filteredTemplates.isEmpty &&
        examples.isEmpty &&
        _searchQuery.isNotEmpty) {
      return _buildNoResultsState();
    }

    final ownCount = filteredTemplates.length;
    final exampleCount = examples.isEmpty ? 0 : examples.length + 1;

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
            itemCount: ownCount + exampleCount + (showRestore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < ownCount) {
                return _buildTemplateCard(filteredTemplates[index]);
              }
              index -= ownCount;
              if (index < exampleCount) {
                if (index == 0) {
                  return ExampleTemplatesHeader(firstInList: ownCount == 0);
                }
                return _buildTemplateCard(examples[index - 1], example: true);
              }
              return _buildRestoreExamples(provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(TemplateModel template, {bool example = false}) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey(template.id),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: example ? colors.surfaceContainer : colors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: example
              ? Icon(
                  Icons.auto_awesome_mosaic_rounded,
                  color: colors.onSurfaceVariant,
                )
              : const Icon(Icons.article_rounded, color: AppTheme.primaryBlue),
        ),
        title: _buildHighlightedText(template.templateName, _searchQuery),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            // Örnekte sütunların adı, ne işe yaradığını anlatır.
            example
                ? template.columns.map((c) => c.name).join(' · ')
                : loc.nColumns(template.columns.length),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: colors.onSurfaceVariant),
          tooltip: loc.moreActions,
          onSelected: (value) {
            switch (value) {
              case 'create':
                _createTableFromTemplate(context, template);
              case 'edit':
                _editTemplate(context, template);
              case 'delete':
                example
                    ? _removeExample(template)
                    : _deleteTemplate(context, template);
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
                title: Text(loc.createTable),
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
                title: Text(loc.edit),
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
                title: Text(loc.delete),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        onTap: () => _createTableFromTemplate(context, template),
      ),
    );
  }

  /// Örnek silinmez, listeden kaldırılır: hemen geri alınabilir, sonra da
  /// listenin sonundan geri getirilebilir.
  void _removeExample(TemplateModel example) {
    final loc = AppLocalizations.of(context);
    final provider = context.read<TemplateProvider>();
    provider.deleteTemplate(example.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(loc.exampleRemoved(example.templateName)),
          action: SnackBarAction(
            label: loc.undo,
            onPressed: () => provider.restoreExamples(id: example.id),
          ),
        ),
      );
  }

  Widget _buildRestoreExamples(TemplateProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: TextButton.icon(
          key: const ValueKey('restore-examples'),
          onPressed: () => provider.restoreExamples(),
          icon: const Icon(Icons.restore_rounded, size: 18),
          label: Text(AppLocalizations.of(context).restoreExamples),
        ),
      ),
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
            AppLocalizations.of(context).noMatchingRecord(_searchQuery),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
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
          // Hazır örnekler sınıra sayılmaz; yalnızca kendi şablonları.
          FreeQuotaNote(
            used: context.watch<TemplateProvider>().templates.length,
            limit: PlanLimits.freeTemplates,
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
    if (freeLimitReached(
      context,
      used: context.read<TemplateProvider>().templates.length,
      limit: PlanLimits.freeTemplates,
    )) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const QuickTableBuilder.template(),
      ),
    );
  }

  void _editTemplate(BuildContext context, TemplateModel template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => QuickTableBuilder.editTemplate(template: template),
      ),
    );
  }

  Future<void> _createTableFromTemplate(
    BuildContext context,
    TemplateModel template,
  ) async {
    // Tablo sınırı doluysa ad sorulmadan Premium ekranı açılır.
    if (freeLimitReached(
      context,
      used: context.read<TableProvider>().ownedTableCount,
      limit: PlanLimits.freeTables,
    )) {
      return;
    }
    final managementRoute = ModalRoute.of(context);
    final managementNavigator = Navigator.of(context);
    final tableNameController = TextEditingController(
      text: template.templateName,
    );
    final columns = template.columns
        .map((column) => column.copyWith())
        .toList();
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
    if (created == true && mounted && managementRoute?.isCurrent == true) {
      managementNavigator.pop();
    }
  }

  void _deleteTemplate(BuildContext context, TemplateModel template) {
    final provider = Provider.of<TemplateProvider>(context, listen: false);
    final templateName = template.templateName;

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
            // Pencere önce kapanır: ikinci bir dokunuş başka bir kaydı silemez.
            onPressed: () {
              Navigator.pop(context);
              provider.deleteTemplate(template.id);
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
