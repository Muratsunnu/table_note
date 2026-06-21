import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/tally_model.dart';
import '../providers/tally_provider.dart';
import '../providers/tally_template_provider.dart';
import '../theme/app_theme.dart';
import 'tally_template_form_dialog.dart';

class TallyTemplateManagementDialog extends StatelessWidget {
  const TallyTemplateManagementDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            _Header(loc: loc),
            Expanded(
              child: Consumer<TallyTemplateProvider>(
                builder: (ctx, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!provider.hasTemplates) {
                    return _buildEmpty(loc);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.templates.length,
                    itemBuilder: (_, i) => _TallyTemplateTile(
                      template: provider.templates[i],
                      onUse: () => _createFromTemplate(context, provider.templates[i]),
                      onEdit: () => _editTemplate(context, i),
                      onDelete: () => _deleteTemplate(context, provider, i, provider.templates[i], loc),
                    ),
                  );
                },
              ),
            ),
            _Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(loc.tallyNoTemplates, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(loc.tallyNoTemplatesHint,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  void _editTemplate(BuildContext context, int index) {
    showDialog(context: context, builder: (_) => TallyTemplateFormDialog(templateIndex: index));
  }

  void _deleteTemplate(BuildContext context, TallyTemplateProvider provider, int index, TallyTemplateModel tpl, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tallyTemplateDelete),
        content: Text(loc.tallyTemplateDeleteConfirm(tpl.templateName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteTemplate(index);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(loc.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _createFromTemplate(BuildContext context, TallyTemplateModel tpl) {
    showDialog(
      context: context,
      builder: (_) => _CreateFromTallyTemplateDialog(template: tpl),
    );
  }
}

class _Header extends StatelessWidget {
  final AppLocalizations loc;
  const _Header({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkBlue, AppTheme.primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.article_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(loc.tallyTemplates,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
              label: Text(loc.tallyCreateNewTemplate),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                showDialog(context: context, builder: (_) => const TallyTemplateFormDialog());
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Şablondan çetele oluşturma — kullanıcı isim + tarih aralığı girer
class _CreateFromTallyTemplateDialog extends StatefulWidget {
  final TallyTemplateModel template;
  const _CreateFromTallyTemplateDialog({required this.template});

  @override
  State<_CreateFromTallyTemplateDialog> createState() => _CreateFromTallyTemplateDialogState();
}

class _CreateFromTallyTemplateDialogState extends State<_CreateFromTallyTemplateDialog> {
  late final TextEditingController _nameController;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  bool _includeItems = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.templateName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.tallyCreateFromTemplate),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: loc.tallyTableName,
                hintText: loc.tallyTableNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(loc.tallyDateRange, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _dateButton(loc.tallyStartDate, _startDate, (d) => setState(() => _startDate = d))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 16)),
                Expanded(child: _dateButton(loc.tallyEndDate, _endDate, (d) => setState(() => _endDate = d))),
              ],
            ),
            if (widget.template.itemNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _includeItems,
                onChanged: (v) => setState(() => _includeItems = v ?? true),
                title: Text(loc.tallyIncludeItems),
                subtitle: Text(loc.tallyIncludeItemsHint, style: const TextStyle(fontSize: 12)),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
        ElevatedButton(onPressed: _create, child: Text(loc.create)),
      ],
    );
  }

  Widget _dateButton(String label, DateTime date, ValueChanged<DateTime> onPicked) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: Localizations.localeOf(context),
        );
        if (picked != null) onPicked(picked);
      },
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _create() async {
    final loc = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.tallyNameRequired), backgroundColor: Colors.red));
      return;
    }
    if (_startDate.isAfter(_endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.tallyDateError), backgroundColor: Colors.red));
      return;
    }

    final tpl = widget.template;
    final clonedStatuses = tpl.statuses
        .map((s) => TallyStatus(code: s.code, label: s.label, colorValue: s.colorValue))
        .toList();
    final items = _includeItems
        ? tpl.itemNames.map((n) => TallyItemModel(name: n)).toList()
        : <TallyItemModel>[];

    final table = TallyTableModel(
      tableName: name,
      startDate: _startDate,
      endDate: _endDate,
      statuses: clonedStatuses,
      items: items,
    );

    final tallyProvider = context.read<TallyProvider>();
    final ok = await tallyProvider.createTable(table);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context); // kendisi
      Navigator.pop(context); // yönetim dialog'u
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.tallyCreateFailed), backgroundColor: Colors.red));
    }
  }
}

/// Genişleyebilen şablon kartı: durumlar (renk+kod chipleri) ve öğeleri önizler.
class _TallyTemplateTile extends StatefulWidget {
  final TallyTemplateModel template;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TallyTemplateTile({
    required this.template,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TallyTemplateTile> createState() => _TallyTemplateTileState();
}

class _TallyTemplateTileState extends State<_TallyTemplateTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final tpl = widget.template;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.lightBlue, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.article_rounded, color: AppTheme.primaryBlue),
            ),
            title: Text(tpl.templateName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                loc.tallyTemplateStatusItemCount(tpl.statuses.length, tpl.itemNames.length),
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded, color: AppTheme.textSecondary),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        widget.onEdit();
                        break;
                      case 'delete':
                        widget.onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
                        title: Text(loc.edit),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                        title: Text(loc.delete),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tpl.statuses.isNotEmpty) ...[
                    Text(loc.tallyStatuses,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tpl.statuses.map((s) {
                        final color = Color(s.colorValue);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 6),
                              Text('${s.code} - ${s.label}',
                                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (tpl.itemNames.isNotEmpty) ...[
                    Text(loc.tallyItemsLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tpl.itemNames
                          .map((n) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.divider),
                                ),
                                child: Text(n, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(loc.tallyCreateFromTemplate),
                      onPressed: widget.onUse,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
