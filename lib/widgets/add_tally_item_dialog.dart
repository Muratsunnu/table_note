import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/tally_provider.dart';

class AddTallyItemDialog extends StatefulWidget {
  const AddTallyItemDialog({super.key});
  @override
  State<AddTallyItemDialog> createState() => _AddTallyItemDialogState();
}

class _AddTallyItemDialogState extends State<AddTallyItemDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final String? _tableId;
  bool _saving = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _tableId = context.read<TallyProvider>().currentTable?.id;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final provider = context.read<TallyProvider>();
    if (_tableId == null || provider.currentTable?.id != _tableId) {
      setState(() => _failed = true);
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    final result = await provider.addItem(_controller.text.trim());
    if (!mounted) return;
    if (result) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(loc.tallyAddItem),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _controller,
                autofocus: true,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: loc.tallyItemName,
                  border: const OutlineInputBorder(),
                ),
                validator: (text) => text?.trim().isNotEmpty == true
                    ? null
                    : loc.recordNameRequired,
              ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    loc.locale.languageCode == 'en'
                        ? 'Could not save. Check the selected tally and try again.'
                        : 'Kaydedilemedi. Seçili çeteleyi kontrol edip yeniden dene.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? loc.pleaseWait : loc.add),
          ),
        ],
      ),
    );
  }
}
