import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/services/formula_service.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ux_localizations.dart';
import 'app_form_scaffold.dart';
import 'row_draft_binding.dart';

class EditRowDialog extends StatefulWidget {
  final int rowIndex;
  final List<String> currentData;

  const EditRowDialog({
    Key? key,
    required this.rowIndex,
    required this.currentData,
  }) : super(key: key);

  @override
  State<EditRowDialog> createState() => _EditRowDialogState();
}

class _EditRowDialogState extends State<EditRowDialog> {
  List<TextEditingController> _controllers = [];
  late List<ColumnModel> _columns;
  late final RowDraftBinding _draft;
  late final String _tableId;
  late final String _schema;
  late final List<String> _originalRow;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TableProvider>(context, listen: false);
    _columns = provider.currentTable!.columns
        .map((column) => column.copyWith())
        .toList();
    _tableId = provider.currentTable!.id;
    _schema = jsonEncode(_columns.map((c) => c.toJson()).toList());
    _originalRow = List<String>.from(widget.currentData);

    // Mevcut verilerle controller'ları oluştur
    _controllers = widget.currentData
        .map((data) => TextEditingController(text: data))
        .toList();

    // Eksik controller varsa ekle
    while (_controllers.length < _columns.length) {
      final col = _columns[_controllers.length];
      final controller = TextEditingController();

      if (col.isConstant && col.constantValue != null) {
        controller.text = _formatNumber(col.constantValue!);
      }

      _controllers.add(controller);
    }

    // Formülleri hesapla
    _recalculateFormulas();
    _draft = RowDraftBinding(
      key: 'edit_row_${_tableId}_${widget.rowIndex}',
      columns: _columns,
      controllers: _controllers,
      originalRow: _originalRow,
      onRestore: () {
        if (!mounted) return;
        _recalculateFormulas();
        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _draft.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Formülleri yeniden hesapla
  // Birden fazla geçiş yaparak bağımlı formülleri doğru hesapla
  void _recalculateFormulas() {
    // Formül sütunu sayısı kadar geçiş yap (en kötü durumda zincir uzunluğu)
    final formulaCount = _columns.where((c) => c.isFormula).length;

    for (int pass = 0; pass < formulaCount; pass++) {
      // Her geçişte güncel rowData'yı al
      final rowData = _controllers.map((c) => c.text).toList();

      for (int i = 0; i < _columns.length; i++) {
        final col = _columns[i];
        if (col.isFormula && col.formula != null) {
          final result = FormulaService.calculate(
            col.formula!,
            rowData,
            _columns,
          );
          if (result != null) {
            _controllers[i].text = _formatNumber(result);
          }
        }
      }
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) => AppFormScaffold(
        title: loc.recordN(widget.rowIndex + 1),
        subtitle: context.read<TableProvider>().currentTable?.tableName,
        icon: Icons.edit_rounded,
        cancelLabel: loc.cancel,
        primaryLabel: loc.update,
        primaryIcon: Icons.check_rounded,
        onPrimary: _updateRow,
        isSaving: _isSaving,
        isRestoring: _draft.isRestoring,
        child: Column(
          children: [
            RowDraftNotice(draft: _draft),
            ..._columns.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildInputField(entry.key, entry.value),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(int colIndex, ColumnModel column) {
    if (colIndex >= _controllers.length) {
      return const SizedBox();
    }

    if (column.isFormula) {
      return _buildFormulaField(colIndex, column);
    }

    if (column.isConstant) {
      return _buildConstantField(colIndex, column);
    }

    if (column.isDate) {
      return _buildDateField(colIndex, column);
    }

    if (column.isTime) {
      return _buildTimeField(colIndex, column);
    }

    if (column.isAutoNumber) {
      return _buildAutoNumberField(colIndex, column);
    }

    return _buildNormalField(colIndex, column);
  }

  Widget _buildNormalField(int colIndex, ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controllers[colIndex],
          decoration: InputDecoration(
            labelText: column.name,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(
              column.isNumeric ? Icons.numbers : Icons.text_fields,
              color: column.isNumeric ? Colors.green : Colors.blue,
            ),
            suffixIcon: column.autoFillOptions.isNotEmpty
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: AppLocalizations.of(context).quickSelect,
                    onSelected: (value) {
                      _controllers[colIndex].text = value;
                      _recalculateFormulas();
                      setState(() {});
                    },
                    itemBuilder: (context) {
                      return column.autoFillOptions.map((option) {
                        return PopupMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList();
                    },
                  )
                : null,
          ),
          keyboardType: column.isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          onChanged: (value) {
            _recalculateFormulas();
            setState(() {});
          },
        ),
        if (column.autoFillOptions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: column.autoFillOptions.map((option) {
              final isSelected = _controllers[colIndex].text == option;
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) {
                  _controllers[colIndex].text = option;
                  _recalculateFormulas();
                  setState(() {});
                },
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildConstantField(int colIndex, ColumnModel column) {
    return TextField(
      controller: _controllers[colIndex],
      decoration: InputDecoration(
        labelText: column.name,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.pin, color: Colors.orange),
        suffixIcon: Tooltip(
          message:
              '${AppLocalizations.of(context).defaultValue}: ${_formatNumber(column.constantValue ?? 0)}',
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: () {
              _controllers[colIndex].text = _formatNumber(
                column.constantValue ?? 0,
              );
              _recalculateFormulas();
              setState(() {});
            },
          ),
        ),
        helperText:
            '${AppLocalizations.of(context).defaultValue}: ${_formatNumber(column.constantValue ?? 0)}',
        helperStyle: TextStyle(
          color: AppTheme.readableAccent(context, Colors.orange),
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        _recalculateFormulas();
        setState(() {});
      },
    );
  }

  Widget _buildFormulaField(int colIndex, ColumnModel column) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.tintedSurface(context, Colors.purple),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.functions,
            color: AppTheme.readableAccent(context, Colors.purple),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.readableAccent(context, Colors.purple),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _controllers[colIndex].text.isEmpty
                      ? AppLocalizations.of(context).calculating
                      : _controllers[colIndex].text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.readableAccent(context, Colors.purple),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${AppLocalizations.of(context).formulaLabel}: ${FormulaService.formatFormula(column.formula ?? '')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.readableAccent(context, Colors.purple),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.tintedSurface(context, Colors.purple),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AppLocalizations.of(context).autoLabel,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.readableAccent(context, Colors.purple),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(int colIndex, ColumnModel column) {
    return TextField(
      controller: _controllers[colIndex],
      decoration: InputDecoration(
        labelText: column.name,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today, color: Colors.teal),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.today, color: Colors.teal),
              onPressed: () {
                _controllers[colIndex].text = _getCurrentDateFormatted();
                setState(() {});
              },
              tooltip: AppLocalizations.of(context).today,
            ),
            IconButton(
              icon: const Icon(Icons.edit_calendar, color: Colors.teal),
              onPressed: () => _selectDate(colIndex),
              tooltip: AppLocalizations.of(context).selectDate,
            ),
          ],
        ),
      ),
      readOnly: true,
      onTap: () => _selectDate(colIndex),
    );
  }

  Widget _buildTimeField(int colIndex, ColumnModel column) {
    return TextField(
      controller: _controllers[colIndex],
      decoration: InputDecoration(
        labelText: column.name,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.access_time, color: Colors.indigo),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.update, color: Colors.indigo),
              onPressed: () {
                _controllers[colIndex].text = _getCurrentTimeFormatted();
                setState(() {});
              },
              tooltip: AppLocalizations.of(context).now,
            ),
            IconButton(
              icon: const Icon(Icons.more_time, color: Colors.indigo),
              onPressed: () => _selectTime(colIndex),
              tooltip: AppLocalizations.of(context).selectTime,
            ),
          ],
        ),
      ),
      readOnly: true,
      onTap: () => _selectTime(colIndex),
    );
  }

  Widget _buildAutoNumberField(int colIndex, ColumnModel column) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.tintedSurface(context, Colors.brown),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.format_list_numbered,
            color: AppTheme.readableAccent(context, Colors.brown),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.readableAccent(context, Colors.brown),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _controllers[colIndex].text,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.readableAccent(context, Colors.brown),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.tintedSurface(context, Colors.brown),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AppLocalizations.of(context).orderNo,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.readableAccent(context, Colors.brown),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(int colIndex) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      _controllers[colIndex].text =
          '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
      setState(() {});
    }
  }

  Future<void> _selectTime(int colIndex) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      _controllers[colIndex].text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  String _getCurrentDateFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }

  String _getCurrentTimeFormatted() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateRow() async {
    if (_isSaving || _draft.isRestoring) return;
    FocusScope.of(context).unfocus();
    final provider = context.read<TableProvider>();
    final table = provider.currentTable;
    final loc = AppLocalizations.of(context);
    if (table?.id != _tableId ||
        jsonEncode(table!.columns.map((c) => c.toJson()).toList()) != _schema ||
        widget.rowIndex < 0 ||
        widget.rowIndex >= table.rows.length ||
        jsonEncode(table.rows[widget.rowIndex]) != jsonEncode(_originalRow)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.recordChanged)));
      return;
    }
    setState(() => _isSaving = true);
    _recalculateFormulas();
    final newRowData = _controllers
        .map((controller) => controller.text.trim())
        .toList();

    try {
      final success = await provider.updateRow(widget.rowIndex, newRowData);
      if (success) await _draft.complete();
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.updateFailed)));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.updateFailed)));
    }
  }
}
