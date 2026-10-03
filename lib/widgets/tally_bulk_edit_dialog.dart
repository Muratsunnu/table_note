import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/tally_provider.dart';
import '../theme/app_theme.dart';

class TallyBulkEditDialog extends StatefulWidget {
  const TallyBulkEditDialog({super.key});

  @override
  State<TallyBulkEditDialog> createState() => _TallyBulkEditDialogState();
}

class _TallyBulkEditDialogState extends State<TallyBulkEditDialog> {
  final Set<int> _selectedItems = {};
  late DateTime _startDate;
  late DateTime _endDate;
  String? _statusCode;

  @override
  void initState() {
    super.initState();
    final table = context.read<TallyProvider>().currentTable!;
    final today = _dateOnly(DateTime.now());
    final tableStart = _dateOnly(table.startDate);
    final tableEnd = _dateOnly(table.endDate);
    if (!today.isBefore(tableStart) && !today.isAfter(tableEnd)) {
      _startDate = today;
      _endDate = today;
    } else {
      _startDate = tableStart;
      _endDate = tableEnd;
    }
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isTodayAvailable(TallyProvider provider) {
    final table = provider.currentTable!;
    final today = _dateOnly(DateTime.now());
    return !today.isBefore(_dateOnly(table.startDate)) &&
        !today.isAfter(_dateOnly(table.endDate));
  }

  bool get _isTodaySelected {
    final today = _dateOnly(DateTime.now());
    return _startDate == today && _endDate == today;
  }

  void _selectToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _startDate = today;
      _endDate = today;
    });
  }

  String _formatDate(BuildContext context, DateTime date) {
    final values = Localizations.localeOf(context).languageCode == 'en'
        ? [date.month, date.day, date.year]
        : [date.day, date.month, date.year];
    return '${values[0].toString().padLeft(2, '0')}.'
        '${values[1].toString().padLeft(2, '0')}.${values[2]}';
  }

  Future<void> _pickDate(bool start) async {
    final table = context.read<TallyProvider>().currentTable!;
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : _endDate,
      firstDate: table.startDate,
      lastDate: table.endDate,
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _startDate = picked;
          if (_endDate.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
          if (_startDate.isAfter(picked)) _startDate = picked;
        }
      });
    }
  }

  Future<void> _apply() async {
    if (_selectedItems.isEmpty) return;
    await context.read<TallyProvider>().setBulkStatus(
      itemIndices: _selectedItems.toList(),
      startDate: _startDate,
      endDate: _endDate,
      statusCode: _statusCode,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TallyProvider>();
    final table = provider.currentTable!;
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.bulkMark),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width * .85,
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: _isTodaySelected
                  ? FilledButton.icon(
                      onPressed: _isTodayAvailable(provider)
                          ? _selectToday
                          : null,
                      icon: const Icon(Icons.today_rounded),
                      label: Text(loc.forToday),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: _isTodayAvailable(provider)
                          ? _selectToday
                          : null,
                      icon: const Icon(Icons.today_rounded),
                      label: Text(loc.forToday),
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    loc.chooseDateRange,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_formatDate(context, _startDate)),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_formatDate(context, _endDate)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              initialValue: _statusCode,
              decoration: InputDecoration(labelText: loc.status),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(loc.tallyClear),
                ),
                ...table.statuses.map(
                  (status) => DropdownMenuItem<String?>(
                    value: status.code,
                    child: Text('${status.code} - ${status.label}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _statusCode = value),
            ),
            CheckboxListTile(
              value: _selectedItems.length == table.items.length,
              title: Text(loc.selectAll),
              onChanged: (selected) => setState(() {
                _selectedItems.clear();
                if (selected == true) {
                  _selectedItems.addAll(
                    List.generate(table.items.length, (index) => index),
                  );
                }
              }),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: table.items.length,
                itemBuilder: (context, index) => Material(
                  color: AppTheme.tableRowColor(context, index),
                  child: CheckboxListTile(
                    value: _selectedItems.contains(index),
                    title: Text(table.items[index].name),
                    onChanged: (selected) => setState(() {
                      selected == true
                          ? _selectedItems.add(index)
                          : _selectedItems.remove(index);
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: _selectedItems.isEmpty ? null : _apply,
          child: Text(loc.apply),
        ),
      ],
    );
  }
}
