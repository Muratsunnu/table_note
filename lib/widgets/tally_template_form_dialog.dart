import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/tally_model.dart';
import '../providers/tally_template_provider.dart';
import '../theme/app_theme.dart';

/// Çetele şablonu oluşturma / düzenleme dialog'u.
/// [templateIndex] null ise oluşturma, doluysa düzenleme modu.
class TallyTemplateFormDialog extends StatefulWidget {
  final int? templateIndex;
  const TallyTemplateFormDialog({Key? key, this.templateIndex}) : super(key: key);

  @override
  State<TallyTemplateFormDialog> createState() => _TallyTemplateFormDialogState();
}

class _TallyTemplateFormDialogState extends State<TallyTemplateFormDialog> {
  final _nameController = TextEditingController();

  final List<TextEditingController> _statusCodeControllers = [];
  final List<TextEditingController> _statusLabelControllers = [];
  final List<int> _statusColors = [];

  final List<TextEditingController> _itemControllers = [];

  static const List<int> _colorPalette = [
    0xFF4CAF50,
    0xFFFF9800,
    0xFFF44336,
    0xFF2196F3,
    0xFF9C27B0,
    0xFF00BCD4,
    0xFF795548,
    0xFF607D8B,
  ];

  bool get _isEdit => widget.templateIndex != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final tpl = context.read<TallyTemplateProvider>().templates[widget.templateIndex!];
      _nameController.text = tpl.templateName;
      for (final s in tpl.statuses) {
        _statusCodeControllers.add(TextEditingController(text: s.code));
        _statusLabelControllers.add(TextEditingController(text: s.label));
        _statusColors.add(s.colorValue);
      }
      for (final n in tpl.itemNames) {
        _itemControllers.add(TextEditingController(text: n));
      }
    }
    if (_itemControllers.isEmpty) {
      _itemControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var c in _statusCodeControllers) c.dispose();
    for (var c in _statusLabelControllers) c.dispose();
    for (var c in _itemControllers) c.dispose();
    super.dispose();
  }

  void _addStatus() {
    setState(() {
      _statusCodeControllers.add(TextEditingController());
      _statusLabelControllers.add(TextEditingController());
      _statusColors.add(_colorPalette[_statusColors.length % _colorPalette.length]);
    });
  }

  void _removeStatus(int index) {
    setState(() {
      _statusCodeControllers[index].dispose();
      _statusCodeControllers.removeAt(index);
      _statusLabelControllers[index].dispose();
      _statusLabelControllers.removeAt(index);
      _statusColors.removeAt(index);
    });
  }

  void _addItem() {
    setState(() => _itemControllers.add(TextEditingController()));
  }

  void _removeItem(int index) {
    if (_itemControllers.length > 1) {
      setState(() {
        _itemControllers[index].dispose();
        _itemControllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.darkBlue, AppTheme.primaryBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.article_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEdit ? loc.tallyTemplateEdit : loc.tallyTemplateCreate,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: loc.tallyTemplateName,
                        hintText: loc.tallyTemplateNameHint,
                        prefixIcon: const Icon(Icons.article_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.label_rounded, color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(loc.tallyStatuses, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const Spacer(),
                        TextButton.icon(icon: const Icon(Icons.add, size: 18), label: Text(loc.add), onPressed: _addStatus),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_statusCodeControllers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppTheme.warningLight, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(loc.tallyAddStatusHint, style: const TextStyle(fontSize: 13, color: AppTheme.warning))),
                          ],
                        ),
                      ),
                    ...List.generate(_statusCodeControllers.length, (i) => _buildStatusRow(i, loc)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.list_rounded, color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(loc.tallyItemsLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const Spacer(),
                        TextButton.icon(icon: const Icon(Icons.add, size: 18), label: Text(loc.add), onPressed: _addItem),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_itemControllers.length, (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _itemControllers[i],
                                  decoration: InputDecoration(
                                    labelText: '${loc.tallyItem} ${i + 1}',
                                    hintText: loc.tallyItemNameHint,
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.person_outline),
                                  ),
                                ),
                              ),
                              if (_itemControllers.length > 1)
                                IconButton(icon: const Icon(Icons.close, color: AppTheme.error), onPressed: () => _removeItem(i)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!))),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(_isEdit ? loc.save : loc.create),
                      onPressed: _submit,
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

  Widget _buildStatusRow(int index, AppLocalizations loc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _showColorPicker(index),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Color(_statusColors[index]), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.palette, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: TextField(
                controller: _statusCodeControllers[index],
                decoration: InputDecoration(labelText: loc.tallyCode, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                textAlign: TextAlign.center,
                maxLength: 3,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _statusLabelControllers[index],
                decoration: InputDecoration(labelText: loc.tallyStatusLabel, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
              ),
            ),
            IconButton(icon: const Icon(Icons.close, size: 20, color: AppTheme.error), onPressed: () => _removeStatus(index)),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).tallyPickColor),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colorPalette.map((c) => GestureDetector(
                onTap: () {
                  setState(() => _statusColors[index] = c);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Color(c),
                    borderRadius: BorderRadius.circular(8),
                    border: _statusColors[index] == c ? Border.all(color: Colors.black, width: 3) : null,
                  ),
                ),
              )).toList(),
        ),
      ),
    );
  }

  void _submit() async {
    final loc = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError(loc.tallyTemplateNameRequired);
      return;
    }
    if (_statusCodeControllers.isEmpty) {
      _showError(loc.tallyStatusRequired);
      return;
    }
    final statuses = <TallyStatus>[];
    for (int i = 0; i < _statusCodeControllers.length; i++) {
      final code = _statusCodeControllers[i].text.trim();
      final label = _statusLabelControllers[i].text.trim();
      if (code.isEmpty) {
        _showError(loc.tallyCodeRequired);
        return;
      }
      statuses.add(TallyStatus(code: code, label: label.isNotEmpty ? label : code, colorValue: _statusColors[i]));
    }
    final itemNames = _itemControllers.map((c) => c.text.trim()).where((n) => n.isNotEmpty).toList();

    final provider = context.read<TallyTemplateProvider>();
    final template = TallyTemplateModel(templateName: name, statuses: statuses, itemNames: itemNames);

    final ok = _isEdit
        ? await provider.updateTemplate(widget.templateIndex!, template)
        : await provider.createTemplate(template);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      _showError(_isEdit ? loc.tallyTemplateUpdateFailed : loc.tallyTemplateCreateFailed);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}
