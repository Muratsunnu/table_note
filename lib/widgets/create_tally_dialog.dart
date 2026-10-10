import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'form_field_reveal.dart';
import 'added_field_focus.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ux_localizations.dart';
import '../services/form_draft_store.dart';
import '../models/tally_model.dart';
import '../providers/tally_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/tally_template_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_feedback.dart';
import 'form_draft_guard.dart';

class CreateTallyDialog extends StatefulWidget {
  const CreateTallyDialog({Key? key}) : super(key: key);

  @override
  State<CreateTallyDialog> createState() => _CreateTallyDialogState();
}

class _CreateTallyDialogState extends State<CreateTallyDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  TextEditingController? _newFieldToFocus;

  final _draft = FormDraftStore('create_tally');
  late final String _emptyDraft;
  String? _lastDraftSnapshot;
  bool _restoringDraft = true;
  bool _restoredDraft = false;
  bool _draftCaptureQueued = false;
  bool _draftCompleted = false;
  bool _isSaving = false;
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _formScrollController = ScrollController();
  String? _nameError;
  String? _dateError;
  String? _statusError;
  final Map<int, String> _codeErrors = {};
  late final TabController _tabController;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  final List<TextEditingController> _statusCodeControllers = [];
  final List<TextEditingController> _statusLabelControllers = [];
  final List<int> _statusColors = [];

  final List<TextEditingController> _itemControllers = [
    TextEditingController(),
  ];

  static const List<int> _colorPalette = [
    0xFF4CAF50, // Yeşil
    0xFFFF9800, // Turuncu
    0xFFF44336, // Kırmızı
    0xFF2196F3, // Mavi
    0xFF9C27B0, // Mor
    0xFF00BCD4, // Cyan
    0xFF795548, // Kahverengi
    0xFF607D8B, // Gri-Mavi
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    WidgetsBinding.instance.addObserver(this);
    _nameController.addListener(_queueDraft);
    _itemControllers.first.addListener(_queueDraft);
    _emptyDraft = jsonEncode(_draftSnapshot());
    _lastDraftSnapshot = _emptyDraft;
    unawaited(_restoreDraft());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _persistDraft();
      unawaited(_draft.flush());
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _queueDraft();
  }

  Map<String, dynamic> _draftSnapshot() => {
    'name': _nameController.text,
    'startDate': _startDate.toIso8601String(),
    'endDate': _endDate.toIso8601String(),
    'statuses': List.generate(
      _statusCodeControllers.length,
      (i) => {
        'code': _statusCodeControllers[i].text,
        'label': _statusLabelControllers[i].text,
        'color': _statusColors[i],
      },
    ),
    'items': _itemControllers.map((controller) => controller.text).toList(),
  };

  void _queueDraft() {
    if (_restoringDraft || _draftCompleted || _draftCaptureQueued) return;
    _draftCaptureQueued = true;
    scheduleMicrotask(() {
      _draftCaptureQueued = false;
      if (mounted) _persistDraft();
    });
  }

  void _persistDraft() {
    if (_restoringDraft || _draftCompleted) return;
    final snapshot = _draftSnapshot();
    final serialized = jsonEncode(snapshot);
    if (serialized == _lastDraftSnapshot) return;
    _lastDraftSnapshot = serialized;
    if (serialized == _emptyDraft) {
      unawaited(_draft.clear());
    } else {
      _draft.schedule(snapshot);
    }
  }

  Future<void> _restoreDraft() async {
    final data = await _draft.read();
    if (!mounted) return;
    if (data != null) {
      try {
        _applyDraft(data);
        _restoredDraft = true;
      } catch (_) {
        _applyDraft(Map<String, dynamic>.from(jsonDecode(_emptyDraft)));
      }
    }
    setState(() => _restoringDraft = false);
  }

  void _applyDraft(Map<String, dynamic> data) {
    final startDate = DateTime.parse(data['startDate'] as String);
    final endDate = DateTime.parse(data['endDate'] as String);
    final statuses = (data['statuses'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final items = List<String>.from(data['items'] as List);
    for (final controller in [
      ..._statusCodeControllers,
      ..._statusLabelControllers,
      ..._itemControllers,
    ]) {
      controller.dispose();
    }
    _statusCodeControllers.clear();
    _statusLabelControllers.clear();
    _statusColors.clear();
    _itemControllers.clear();
    _nameController.text = data['name'] as String? ?? '';
    _startDate = startDate;
    _endDate = endDate;
    for (final status in statuses) {
      _statusCodeControllers.add(
        _draftController(status['code'] as String? ?? ''),
      );
      _statusLabelControllers.add(
        _draftController(status['label'] as String? ?? ''),
      );
      _statusColors.add(status['color'] as int);
    }
    _itemControllers.addAll(
      (items.isEmpty ? [''] : items).map(_draftController),
    );
  }

  TextEditingController _draftController([String text = '']) =>
      TextEditingController(text: text)..addListener(_queueDraft);

  Future<void> _discardDraft() async {
    _restoringDraft = true;
    setState(() {
      _applyDraft(Map<String, dynamic>.from(jsonDecode(_emptyDraft)));
      _nameError = null;
      _dateError = null;
      _statusError = null;
      _codeErrors.clear();
      _restoredDraft = false;
      _lastDraftSnapshot = _emptyDraft;
    });
    await _draft.clear();
    if (mounted) setState(() => _restoringDraft = false);
  }

  void _handleTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persistDraft();
    _draft.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _formScrollController.dispose();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    for (var c in _statusCodeControllers) c.dispose();
    for (var c in _statusLabelControllers) c.dispose();
    for (var c in _itemControllers) c.dispose();
    super.dispose();
  }

  void _addStatus() {
    setState(() {
      _statusError = null;
      _statusCodeControllers.add(_draftController());
      _statusLabelControllers.add(_draftController());
      _statusColors.add(
        _colorPalette[_statusColors.length % _colorPalette.length],
      );
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
      _codeErrors.clear();
    });
  }

  void _addItem() {
    setState(() {
      _itemControllers.add(_draftController());
      _newFieldToFocus = _itemControllers.last;
    });
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
    return FormDraftGuard(
      isSaving: _isSaving || _restoringDraft,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Header
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
                        Icons.grid_on_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        loc.tallyCreate,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  indicatorColor: AppTheme.primaryBlue,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: loc.manualCreate),
                    Tab(text: loc.createFromTemplate),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    FormFocusScrollView(
                      controller: _formScrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_restoredDraft) ...[
                            Material(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.restore_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(loc.draftRestored)),
                                    TextButton(
                                      onPressed: _discardDraft,
                                      child: Text(loc.discardDraft),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          // Tablo adı
                          TextField(
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            onChanged: (_) {
                              if (_nameError != null) {
                                setState(() => _nameError = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: loc.tallyTableName,
                              hintText: loc.tallyTableNameHint,
                              prefixIcon: const Icon(Icons.grid_on_rounded),
                              errorText: _nameError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tarih aralığı
                          Text(
                            loc.tallyDateRange,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateButton(
                                  context,
                                  loc.tallyStartDate,
                                  _startDate,
                                  (d) => setState(() {
                                    _startDate = d;
                                    _dateError = null;
                                  }),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Expanded(
                                child: _buildDateButton(
                                  context,
                                  loc.tallyEndDate,
                                  _endDate,
                                  (d) => setState(() {
                                    _endDate = d;
                                    _dateError = null;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          if (_dateError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _dateError!,
                              style: const TextStyle(
                                color: AppTheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Durumlar
                          Row(
                            children: [
                              const Icon(
                                Icons.label_rounded,
                                color: AppTheme.primaryBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.tallyStatuses,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
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
                                color: _statusError == null
                                    ? AppTheme.tintedSurface(
                                        context,
                                        AppTheme.warning,
                                      )
                                    : AppTheme.tintedSurface(
                                        context,
                                        AppTheme.error,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: _statusError == null
                                        ? AppTheme.warning
                                        : AppTheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _statusError ?? loc.tallyAddStatusHint,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _statusError == null
                                            ? AppTheme.warning
                                            : AppTheme.error,
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

                          // Öğeler
                          Row(
                            children: [
                              const Icon(
                                Icons.list_rounded,
                                color: AppTheme.primaryBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.tallyItemsLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
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
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: AddedFieldFocus(
                                      key: ValueKey(_itemControllers[i]),
                                      target: _itemControllers[i],
                                      pendingTarget: () => _newFieldToFocus,
                                      onFocused: (target) {
                                        if (identical(
                                          _newFieldToFocus,
                                          target,
                                        )) {
                                          _newFieldToFocus = null;
                                        }
                                      },
                                      builder: (focusNode) => TextField(
                                        focusNode: focusNode,
                                        controller: _itemControllers[i],
                                        decoration: InputDecoration(
                                          labelText:
                                              '${loc.tallyItem} ${i + 1}',
                                          hintText: loc.tallyItemNameHint,
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(
                                            Icons.person_outline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_itemControllers.length > 1)
                                    IconButton(
                                      tooltip: loc.delete,
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
                    _buildTemplateTab(loc),
                  ],
                ),
              ),
              // Footer
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
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(loc.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isSaving ? loc.savingProgress : loc.create,
                        ),
                        onPressed: !_isSaving && _tabController.index == 0
                            ? _create
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateTab(AppLocalizations loc) {
    return Consumer<TallyTemplateProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!provider.hasTemplates) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 58,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.tallyNoTemplates,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.tallyNoTemplatesHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.templates.length,
          itemBuilder: (context, index) {
            final template = provider.templates[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.grid_view_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                title: Text(
                  template.templateName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  loc.tallyTemplateStatusItemCount(
                    template.statuses.length,
                    template.itemNames.length,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => _applyTemplate(template),
              ),
            );
          },
        );
      },
    );
  }

  void _applyTemplate(TallyTemplateModel template) {
    for (final controller in _statusCodeControllers) {
      controller.dispose();
    }
    for (final controller in _statusLabelControllers) {
      controller.dispose();
    }
    for (final controller in _itemControllers) {
      controller.dispose();
    }

    setState(() {
      _nameController.text = template.templateName;
      _nameError = null;
      _statusError = null;
      _codeErrors.clear();

      _statusCodeControllers
        ..clear()
        ..addAll(
          template.statuses.map((status) => _draftController(status.code)),
        );
      _statusLabelControllers
        ..clear()
        ..addAll(
          template.statuses.map((status) => _draftController(status.label)),
        );
      _statusColors
        ..clear()
        ..addAll(template.statuses.map((status) => status.colorValue));
      _itemControllers
        ..clear()
        ..addAll(template.itemNames.map(_draftController));
      if (_itemControllers.isEmpty) {
        _itemControllers.add(_draftController());
      }
    });
    _tabController.animateTo(0);
  }

  Widget _buildDateButton(
    BuildContext context,
    String label,
    DateTime date,
    ValueChanged<DateTime> onPicked,
  ) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: Localizations.localeOf(context),
        );
        if (mounted && picked != null) onPicked(picked);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${date.day}/${date.month}/${date.year}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(int index, AppLocalizations loc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Renk seçici
                IconButton.filled(
                  tooltip: loc.tallyPickColor,
                  onPressed: () => _showColorPicker(index),
                  style: IconButton.styleFrom(
                    backgroundColor: Color(_statusColors[index]),
                    foregroundColor:
                        ThemeData.estimateBrightnessForColor(
                              Color(_statusColors[index]),
                            ) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  icon: const Icon(Icons.palette_outlined, size: 20),
                ),
                const SizedBox(width: 8),
                // Kod
                Expanded(
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
                      onChanged: (_) {
                        if (_codeErrors.containsKey(index)) {
                          setState(() => _codeErrors.remove(index));
                        }
                      },
                      decoration: InputDecoration(
                        labelText: loc.tallyCode,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                      maxLength: 3,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: loc.delete,
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppTheme.error,
                  ),
                  onPressed: () => _removeStatus(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _statusLabelControllers[index],
              decoration: InputDecoration(
                labelText: loc.tallyStatusLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_codeErrors[index] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _codeErrors[index]!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 12),
                ),
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
                (c) => IconButton.filled(
                  tooltip:
                      '${AppLocalizations.of(context).tallyPickColor} ${_colorPalette.indexOf(c) + 1}',
                  isSelected: _statusColors[index] == c,
                  onPressed: () {
                    setState(() => _statusColors[index] = c);
                    Navigator.pop(ctx);
                  },
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                    backgroundColor: Color(c),
                    foregroundColor:
                        ThemeData.estimateBrightnessForColor(Color(c)) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  icon: const Icon(Icons.circle, color: Colors.transparent),
                  selectedIcon: const Icon(Icons.check_rounded),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (_isSaving || _restoringDraft) return;
    final loc = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    setState(() {
      _nameError = null;
      _dateError = null;
      _statusError = null;
      _codeErrors.clear();
    });
    if (name.isEmpty) {
      setState(() => _nameError = loc.tallyNameRequired);
      _formScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      _nameFocusNode.requestFocus();
      return;
    }
    if (_startDate.isAfter(_endDate)) {
      setState(() => _dateError = loc.tallyDateError);
      return;
    }
    if (_statusCodeControllers.isEmpty) {
      setState(() => _statusError = loc.tallyStatusRequired);
      return;
    }

    // Durumları topla
    final statuses = <TallyStatus>[];
    final usedCodes = <String>{};
    for (int i = 0; i < _statusCodeControllers.length; i++) {
      final code = _statusCodeControllers[i].text.trim();
      final label = _statusLabelControllers[i].text.trim();
      if (code.isEmpty) {
        setState(() => _codeErrors[i] = loc.tallyCodeRequired);
        return;
      }
      if (!usedCodes.add(code.toLowerCase())) {
        setState(() => _codeErrors[i] = loc.duplicateStatusCode);
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

    // Öğeleri topla
    final items = _itemControllers
        .map((c) => c.text.trim())
        .where((name) => name.isNotEmpty)
        .map((name) => TallyItemModel(name: name))
        .toList();

    final table = TallyTableModel(
      tableName: name,
      startDate: _startDate,
      endDate: _endDate,
      statuses: statuses,
      items: items,
    );

    final provider = Provider.of<TallyProvider>(context, listen: false);
    // Premium ya da sınırlardan önceki sürümden gelen kullanıcı.
    final isPremium = context.read<SubscriptionProvider>().hasUnlimitedPlan;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    try {
      final success = await provider.createTable(table, isPremium: isPremium);
      if (!mounted) return;
      if (success) {
        _draftCompleted = true;
        await _draft.clear();
        if (mounted) Navigator.pop(context);
      } else {
        _showError(loc.tallyCreateFailed);
      }
    } catch (_) {
      if (mounted) _showError(loc.tallyCreateFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    AppFeedback.showError(context, msg);
  }
}
