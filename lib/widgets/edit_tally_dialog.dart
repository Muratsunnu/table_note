import 'package:flutter/material.dart';
import 'form_field_reveal.dart';
import 'added_field_focus.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/tally_model.dart';
import '../providers/tally_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_feedback.dart';

class EditTallyDialog extends StatefulWidget {
  const EditTallyDialog({Key? key}) : super(key: key);

  @override
  State<EditTallyDialog> createState() => _EditTallyDialogState();
}

class _EditTallyDialogState extends State<EditTallyDialog> {
  TextEditingController? _newFieldToFocus;

  late final TextEditingController _nameController;
  final _nameFocusNode = FocusNode();
  final _formScrollController = ScrollController();
  String? _nameError;
  String? _dateError;
  String? _statusError;
  final Map<int, String> _codeErrors = {};
  late DateTime _startDate;
  late DateTime _endDate;

  // Her satır için paralel listeler. _originalCodes[i]:
  //   - mevcut bir durumdan geliyorsa, satırın İLK render'ındaki kodu
  //   - yeni eklendiyse null
  // Save aşamasında remap (oldCode -> newCode|null) bunlardan üretilir.
  final List<TextEditingController> _statusCodeControllers = [];
  final List<TextEditingController> _statusLabelControllers = [];
  final List<int> _statusColors = [];
  final List<String?> _originalCodes = [];

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

  @override
  void initState() {
    super.initState();
    final table = context.read<TallyProvider>().currentTable!;
    _nameController = TextEditingController(text: table.tableName);
    _startDate = table.startDate;
    _endDate = table.endDate;

    for (final s in table.statuses) {
      _statusCodeControllers.add(TextEditingController(text: s.code));
      _statusLabelControllers.add(TextEditingController(text: s.label));
      _statusColors.add(s.colorValue);
      _originalCodes.add(s.code);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _formScrollController.dispose();
    for (var c in _statusCodeControllers) c.dispose();
    for (var c in _statusLabelControllers) c.dispose();
    super.dispose();
  }

  void _addStatus() {
    setState(() {
      _statusError = null;
      _statusCodeControllers.add(TextEditingController());
      _statusLabelControllers.add(TextEditingController());
      _statusColors.add(
        _colorPalette[_statusColors.length % _colorPalette.length],
      );
      _originalCodes.add(null);
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
      _originalCodes.removeAt(index);
      _codeErrors.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
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
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.tallyEditTitle,
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
            // Body
            Expanded(
              child: FormFocusScrollView(
                controller: _formScrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    // Silinecek durum varsa veri kaybı uyarısı göster
                    if (_hasDeletedStatus())
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _statusError == null
                              ? AppTheme.tintedSurface(
                                  context,
                                  AppTheme.warning,
                                )
                              : AppTheme.tintedSurface(context, AppTheme.error),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loc.tallyDeleteStatusWarning,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  ],
                ),
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
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(loc.save),
                      onPressed: _save,
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

  bool _hasDeletedStatus() {
    final remainingOriginals = _originalCodes.whereType<String>().toSet();
    final table = context.read<TallyProvider>().currentTable;
    if (table == null) return false;
    return table.statuses.any((s) => !remainingOriginals.contains(s.code));
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
        if (picked != null) onPicked(picked);
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
                GestureDetector(
                  onTap: () => _showColorPicker(index),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(_statusColors[index]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.palette,
                      color: Colors.white,
                      size: 18,
                    ),
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
                      onChanged: (_) => setState(() {
                        _codeErrors.remove(index);
                      }),
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
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppTheme.error,
                  ),
                  onPressed: () => _removeStatus(index),
                ),
              ],
            ),
            if (_codeErrors[index] != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(44, 6, 8, 0),
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

  void _save() async {
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

    final newStatuses = <TallyStatus>[];
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
      newStatuses.add(
        TallyStatus(
          code: code,
          label: label.isNotEmpty ? label : code,
          colorValue: _statusColors[i],
        ),
      );
    }

    // Code remap üretimi
    final remap = <String, String?>{};
    final survivingOriginals = <String>{};
    for (int i = 0; i < _originalCodes.length; i++) {
      final original = _originalCodes[i];
      if (original == null) continue; // yeni satır
      final current = _statusCodeControllers[i].text.trim();
      survivingOriginals.add(original);
      if (original != current) {
        remap[original] = current;
      }
    }
    // Tablodaki ama hayatta kalmayan tüm orijinal kodları sil
    final provider = context.read<TallyProvider>();
    final originalTable = provider.currentTable!;
    for (final s in originalTable.statuses) {
      if (!survivingOriginals.contains(s.code) && !remap.containsKey(s.code)) {
        remap[s.code] = null;
      }
    }

    final success = await provider.updateCurrentTable(
      tableName: name,
      startDate: _startDate,
      endDate: _endDate,
      newStatuses: newStatuses,
      codeRemap: remap,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      _showError(loc.tallyUpdateFailed);
    }
  }

  void _showError(String msg) {
    AppFeedback.showError(context, msg);
  }
}
