import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/table_provider.dart';
import '../utils/column_balance.dart';
import '../utils/number_display.dart';

/// Toplamı alınan bir sütunun başlangıç değeri: sermaye, bütçe, stok ya da
/// hedef. Yazılan sayı uygulamanın diline göre okunur ve nasıl anlaşıldığı
/// alanın altında gösterilir; "100.000" yüz bin mi, yüz mü, şüphe kalmaz.
class StartingValueField extends StatefulWidget {
  const StartingValueField({
    super.key,
    required this.value,
    required this.onChanged,
    this.autofocus = false,
  });

  final double? value;

  /// Geçerli bir sayı yazıldıysa o sayı; alan boşsa ya da sayı okunamıyorsa
  /// null.
  final ValueChanged<double?> onChanged;
  final bool autofocus;

  @override
  State<StartingValueField> createState() => _StartingValueFieldState();
}

class _StartingValueFieldState extends State<StartingValueField> {
  TextEditingController? _controller;
  double? _parsed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final language = AppLocalizations.of(context).locale.languageCode;
    _parsed = widget.value;
    _controller = TextEditingController(
      text: widget.value == null
          ? ''
          : formatGroupedNumber(widget.value!, language),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final language = loc.locale.languageCode;
    final text = _controller!.text.trim();
    final invalid = text.isNotEmpty && _parsed == null;
    return TextField(
      key: const ValueKey('starting-value'),
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      decoration: InputDecoration(
        labelText: loc.startingValue,
        hintText: loc.startingValueExample,
        // Okunan sayı: yazılanın nasıl anlaşıldığını gösterir.
        helperText: _parsed == null
            ? loc.startingValueHint
            : '= ${formatGroupedNumber(_parsed!, language)}',
        helperMaxLines: 3,
        errorText: invalid ? loc.startingValueInvalid : null,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.flag_outlined),
      ),
      onChanged: (value) {
        setState(
          () => _parsed = parseTypedNumber(value, languageCode: language),
        );
        widget.onChanged(_parsed);
      },
    );
  }
}

/// Toplamlar kutusundaki "kalan"a dokununca açılır: başlangıç değeri tablo
/// yapısına girmeden değiştirilir. Sermaye arttığında ya da hedef
/// değiştiğinde en kısa yol budur.
Future<void> showStartingValueDialog(
  BuildContext context,
  ColumnBalance balance,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _StartingValueDialog(balance: balance),
  );
}

class _StartingValueDialog extends StatefulWidget {
  const _StartingValueDialog({required this.balance});

  final ColumnBalance balance;

  @override
  State<_StartingValueDialog> createState() => _StartingValueDialogState();
}

class _StartingValueDialogState extends State<_StartingValueDialog> {
  late double? _value = widget.balance.startingValue;
  bool _saving = false;

  Future<void> _save(double? value) async {
    setState(() => _saving = true);
    final tables = context.read<TableProvider>();
    final navigator = Navigator.of(context);
    await tables.setColumnStartingValue(widget.balance.columnIndex, value);
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final language = loc.locale.languageCode;
    final balance = widget.balance;
    final remaining = _value == null ? null : _value! - balance.total;
    return AlertDialog(
      title: Text(loc.startingValueOf(balance.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StartingValueField(
              value: balance.startingValue,
              autofocus: true,
              onChanged: (value) => setState(() => _value = value),
            ),
            const SizedBox(height: 12),
            // Yeni değerle kalanın ne olacağı, kaydetmeden önce görünür.
            Text(
              [
                '${loc.totalLabel}: ${formatGroupedNumber(balance.total, language)}',
                if (remaining != null)
                  '${loc.remaining}: ${formatGroupedNumber(remaining, language)}',
              ].join('  •  '),
              key: const ValueKey('starting-value-preview'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: remaining != null && remaining < 0
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => _save(null),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(loc.startingValueRemove),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: _saving || _value == null ? null : () => _save(_value),
          child: Text(loc.save),
        ),
      ],
    );
  }
}
