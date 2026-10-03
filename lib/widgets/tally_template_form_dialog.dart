import 'package:flutter/material.dart';
import 'form_field_reveal.dart';
import 'added_field_focus.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/tally_model.dart';
import '../providers/tally_template_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_feedback.dart';

/// Çetele şablonu oluşturma / düzenleme dialog'u.
/// [templateIndex] null ise oluşturma, doluysa düzenleme modu.
class TallyTemplateFormDialog extends StatefulWidget {
  final int? templateIndex;
  const TallyTemplateFormDialog({Key? key, this.templateIndex})
    : super(key: key);

  @override
  State<TallyTemplateFormDialog> createState() =>
      _TallyTemplateFormDialogState();
}

class _TallyTemplateFormDialogState extends State<TallyTemplateFormDialog> {
  TextEditingController? _newFieldToFocus;

  final _nameController = TextEditingController();
  final _fieldReveal = FieldRevealController();
  String? _nameError;

  final List<TextEditingController> _statusCodeControllers = [];
  final List<TextEditingController> _statusLabelControllers = [];
  final List<int> _statusColors = [];
  final List<String?> _statusCodeErrors = [];
  String? _statusListError;

  final List<TextEditingController> _itemControllers = [];
  final Map<TextEditingController, FocusNode> _itemFocusNodes = {};
  TextEditingController? _pendingItemFocus;

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
      final tpl = context
          .read<TallyTemplateProvider>()
          .templates[widget.templateIndex!];
      _nameController.text = tpl.templateName;
      for (final s in tpl.statuses) {
        _statusCodeControllers.add(TextEditingController(text: s.code));
        _statusLabelControllers.add(TextEditingController(text: s.label));
        _statusColors.add(s.colorValue);
        _statusCodeErrors.add(null);
      }
      for (final n in tpl.itemNames) {
        _itemControllers.add(TextEditingController(text: n));
      }
    }
    if (_itemControllers.isEmpty) {
      _itemControllers.add(TextEditingController());
    }
    for (final controller in _itemControllers) {
      _itemFocusNodes[controller] = FocusNode();
    }
  }

  @override
  void dispose() {
    _fieldReveal.dispose();
    _nameController.dispose();
    for (var c in _statusCodeControllers) c.dispose();
    for (var c in _statusLabelControllers) c.dispose();
    for (var c in _itemControllers) c.dispose();
    for (final node in _itemFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _addStatus() {
    setState(() {
      _statusCodeControllers.add(TextEditingController());
      _statusLabelControllers.add(TextEditingController());
      _statusColors.add(
        _colorPalette[_statusColors.length % _colorPalette.length],
      );
      _statusCodeErrors.add(null);
      _statusListError = null;
      _newFieldToFocus = _statusCodeControllers.last;
    });
  }

  void _removeStatus(int index) {
    setState(() {
      _statusCodeControllers[index].dispose();
      _statusCodeControllers.removeAt(index);
      _statusLabelControllers[index].dispose();
      _statusLabelControllers.removeAt(index);
      _statusColors.removeAt(index);
      _statusCodeErrors.removeAt(index);
    });
  }

  void _addItem() {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    setState(() {
      _itemControllers.add(controller);
      _itemFocusNodes[controller] = focusNode;
      _pendingItemFocus = controller;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _pendingItemFocus != controller ||
          !_itemFocusNodes.containsKey(controller)) {
        return;
      }
      _pendingItemFocus = null;
      _fieldReveal.reveal(focusNode);
    });
  }

  void _removeItem(int index) {
    if (_itemControllers.length > 1) {
      final controller = _itemControllers[index];
      final focusNode = _itemFocusNodes[controller];
      focusNode?.unfocus();
      setState(() {
        _itemControllers.removeAt(index);
        _itemFocusNodes.remove(controller);
        if (_pendingItemFocus == controller) _pendingItemFocus = null;
      });
      // Release only after the removed field has left the widget tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
        focusNode?.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.darkBlue, AppTheme.primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEdit ? loc.tallyTemplateEdit : loc.tallyTemplateCreate,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FormFocusScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: loc.tallyTemplateName,
                        hintText: loc.tallyTemplateNameHint,
                        errorText: _nameError,
                        prefixIcon: const Icon(Icons.article_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.label_rounded,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.tallyStatuses,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(loc.add),
                          onPressed: _addStatus,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_statusCodeControllers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.tintedSurface(
                            context,
                            AppTheme.warning,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppTheme.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusListError ?? loc.tallyAddStatusHint,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...List.generate(
                      _statusCodeControllers.length,
                      (i) => _buildStatusRow(i, loc),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.list_rounded,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.tallyItemsLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(loc.add),
                          onPressed: _addItem,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      _itemControllers.length,
                      (i) => Padding(
                        key: ValueKey(_itemControllers[i]),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _itemControllers[i],
                                focusNode: _itemFocusNodes[_itemControllers[i]],
                                decoration: InputDecoration(
                                  labelText: '${loc.tallyItem} ${i + 1}',
                                  hintText: loc.tallyItemNameHint,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                              ),
                            ),
                            if (_itemControllers.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: AppTheme.error,
                                ),
                                onPressed: () => _removeItem(i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(_statusColors[index]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.palette, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: AddedFieldFocus(
                key: ValueKey(_statusCodeControllers[index]),
                target: _statusCodeControllers[index],
                pendingTarget: () => _newFieldToFocus,
                onFocused: (target) {
                  if (identical(_newFieldToFocus, target)) {
                    _newFieldToFocus = null;
                  }
                },
                builder: (focusNode) => TextField(
                  focusNode: focusNode,
                  controller: _statusCodeControllers[index],
                  decoration: InputDecoration(
                    labelText: loc.tallyCode,
                    errorText: _statusCodeErrors[index],
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  textAlign: TextAlign.center,
                  maxLength: 3,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  onChanged: (_) {
                    if (_statusCodeErrors[index] != null) {
                      setState(() => _statusCodeErrors[index] = null);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _statusLabelControllers[index],
                decoration: InputDecoration(
                  labelText: loc.tallyStatusLabel,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: AppTheme.error),
              onPressed: () => _removeStatus(index),
            ),
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
          children: _colorPalette
              .map(
                (c) => GestureDetector(
                  onTap: () {
                    setState(() => _statusColors[index] = c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(8),
                      border: _statusColors[index] == c
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _submit() async {
    final loc = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = loc.tallyTemplateNameRequired);
      return;
    }
    if (_statusCodeControllers.isEmpty) {
      setState(() => _statusListError = loc.tallyStatusRequired);
      return;
    }
    setState(() {
      _statusListError = null;
      for (var i = 0; i < _statusCodeErrors.length; i++) {
        _statusCodeErrors[i] = null;
      }
    });
    final statuses = <TallyStatus>[];
    final usedCodes = <String>{};
    for (int i = 0; i < _statusCodeControllers.length; i++) {
      final code = _statusCodeControllers[i].text.trim();
      final label = _statusLabelControllers[i].text.trim();
      if (code.isEmpty) {
        setState(() => _statusCodeErrors[i] = loc.tallyCodeRequired);
        return;
      }
      if (!usedCodes.add(code.toLowerCase())) {
        setState(() => _statusCodeErrors[i] = loc.duplicateStatusCode);
        return;
      }
      statuses.add(
        TallyStatus(
          code: code,
          label: label.isNotEmpty ? label : code,
          colorValue: _statusColors[i],
        ),
      );
    }
    final itemNames = _itemControllers
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    final provider = context.read<TallyTemplateProvider>();
    final template = TallyTemplateModel(
      templateName: name,
      statuses: statuses,
      itemNames: itemNames,
    );

    final ok = _isEdit
        ? await provider.updateTemplate(widget.templateIndex!, template)
        : await provider.createTemplate(
            template,
            isPremium: context.read<SubscriptionProvider>().isPremium,
          );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      _showError(
        _isEdit ? loc.tallyTemplateUpdateFailed : loc.tallyTemplateCreateFailed,
      );
    }
  }

  void _showError(String msg) {
    AppFeedback.showError(context, msg);
  }
}
