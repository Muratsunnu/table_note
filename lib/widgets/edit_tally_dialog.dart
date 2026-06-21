import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/tally_model.dart';
import '../providers/tally_provider.dart';
import '../theme/app_theme.dart';

class EditTallyDialog extends StatefulWidget {
  const EditTallyDialog({Key? key}) : super(key: key);

  @override
  State<EditTallyDialog> createState() => _EditTallyDialogState();
}

class _EditTallyDialogState extends State<EditTallyDialog> {
  late final TextEditingController _nameController;
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
    0xFF4CAF50, 0xFFFF9800, 0xFFF44336, 0xFF2196F3,
    0xFF9C27B0, 0xFF00BCD4, 0xFF795548, 0xFF607D8B,
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
    for (var c in _statusCodeControllers) c.dispose();
    for (var c in _statusLabelControllers) c.dispose();
    super.dispose();
  }

  void _addStatus() {
    setState(() {
      _statusCodeControllers.add(TextEditingController());
      _statusLabelControllers.add(TextEditingController());
      _statusColors.add(_colorPalette[_statusColors.length % _colorPalette.length]);
      _originalCodes.add(null);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
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
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
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
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.tallyEditTitle,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: loc.tallyTableName,
                        hintText: loc.tallyTableNameHint,
                        prefixIcon: const Icon(Icons.grid_on_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(loc.tallyDateRange, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateButton(
                            context,
                            loc.tallyStartDate,
                            _startDate,
                            (d) => setState(() => _startDate = d),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, color: AppTheme.textSecondary),
                        ),
                        Expanded(
                          child: _buildDateButton(
                            context,
                            loc.tallyEndDate,
                            _endDate,
                            (d) => setState(() => _endDate = d),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const Icon(Icons.label_rounded, color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(loc.tallyStatuses, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
                          color: AppTheme.warningLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loc.tallyDeleteStatusWarning,
                                style: const TextStyle(fontSize: 13, color: AppTheme.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_statusCodeControllers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loc.tallyAddStatusHint,
                                style: const TextStyle(fontSize: 13, color: AppTheme.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...List.generate(_statusCodeControllers.length, (i) => _buildStatusRow(i, loc)),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!))),
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
                    child: ElevatedButton.icon(
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

  Widget _buildDateButton(BuildContext context, String label, DateTime date, ValueChanged<DateTime> onPicked) {
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
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text('${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
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
              child: TextField(
                controller: _statusCodeControllers[index],
                decoration: InputDecoration(
                  labelText: loc.tallyCode,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                textAlign: TextAlign.center,
                maxLength: 3,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                onChanged: (_) => setState(() {}), // uyarı bandını yenile
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _statusLabelControllers[index],
                decoration: InputDecoration(
                  labelText: loc.tallyStatusLabel,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
              .map((c) => GestureDetector(
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
                        border: _statusColors[index] == c ? Border.all(color: Colors.black, width: 3) : null,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _save() async {
    final loc = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError(loc.tallyNameRequired);
      return;
    }
    if (_startDate.isAfter(_endDate)) {
      _showError(loc.tallyDateError);
      return;
    }
    if (_statusCodeControllers.isEmpty) {
      _showError(loc.tallyStatusRequired);
      return;
    }

    final newStatuses = <TallyStatus>[];
    for (int i = 0; i < _statusCodeControllers.length; i++) {
      final code = _statusCodeControllers[i].text.trim();
      final label = _statusLabelControllers[i].text.trim();
      if (code.isEmpty) {
        _showError(loc.tallyCodeRequired);
        return;
      }
      newStatuses.add(TallyStatus(
        code: code,
        label: label.isNotEmpty ? label : code,
        colorValue: _statusColors[i],
      ));
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}
