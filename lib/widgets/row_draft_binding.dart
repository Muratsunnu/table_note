import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ux_localizations.dart';
import '../models/tabel_model.dart';
import '../services/form_draft_store.dart';

/// Associates a draft with one table schema and, for edits, the original row.
/// An old draft must never silently overwrite a different or changed record.
class RowDraftBinding extends ChangeNotifier with WidgetsBindingObserver {
  RowDraftBinding({
    required String key,
    required this.columns,
    required this.controllers,
    required this.onRestore,
    this.originalRow,
  }) : _store = FormDraftStore(key),
       _initial = controllers.map((c) => c.text).toList(),
       _lastValues = jsonEncode(controllers.map((c) => c.text).toList()),
       _schema = jsonEncode(columns.map((c) => c.toJson()).toList()) {
    for (final controller in controllers) {
      controller.addListener(_changed);
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restore());
  }

  final List<ColumnModel> columns;
  final List<TextEditingController> controllers;
  final List<String>? originalRow;
  final VoidCallback onRestore;
  final FormDraftStore _store;
  final List<String> _initial;
  final String _schema;
  String _lastValues;
  bool isRestoring = true;
  bool _disposed = false;
  bool _applying = false;
  bool _edited = false;
  bool _completed = false;
  bool restored = false;

  bool get hasDraft => _edited || restored;
  bool get hasError => _store.lastError != null;

  Future<void> _restore() async {
    try {
      final data = await _store.read();
      if (_disposed || _edited || _completed || data == null) return;
      if (data['schema'] != _schema ||
          jsonEncode(data['originalRow']) != jsonEncode(originalRow)) {
        return;
      }
      final values = data['values'];
      if (values is! List ||
          values.length != controllers.length ||
          values.any((v) => v is! String)) {
        return;
      }
      _applying = true;
      for (var i = 0; i < columns.length; i++) {
        if (!columns[i].isAutoNumber && !columns[i].isFormula) {
          controllers[i].text = values[i] as String;
        }
      }
      onRestore();
      _applying = false;
      restored = true;
    } finally {
      _applying = false;
      if (!_disposed) {
        _lastValues = jsonEncode(controllers.map((c) => c.text).toList());
        isRestoring = false;
        notifyListeners();
      }
    }
  }

  void _changed() {
    if (_disposed || _applying || _completed || isRestoring) return;
    final values = controllers.map((c) => c.text).toList();
    final serialized = jsonEncode(values);
    if (serialized == _lastValues) return;
    _lastValues = serialized;
    _edited = true;
    restored = false;
    _store.schedule({
      'schema': _schema,
      'originalRow': originalRow,
      'values': values,
    });
    notifyListeners();
  }

  Future<void> discard() async {
    _applying = true;
    // Clear before awaiting I/O so a newer edit is never discarded on completion.
    for (var i = 0; i < controllers.length; i++) {
      controllers[i].text = _initial[i];
    }
    onRestore();
    _lastValues = jsonEncode(controllers.map((c) => c.text).toList());
    _edited = false;
    restored = false;
    _applying = false;
    final removal = _store.clear();
    notifyListeners();
    await removal;
  }

  Future<void> complete() async {
    _completed = true;
    await _store.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_store.flush());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in controllers) {
      controller.removeListener(_changed);
    }
    _store.dispose();
    super.dispose();
  }
}

class RowDraftNotice extends StatelessWidget {
  const RowDraftNotice({super.key, required this.draft});
  final RowDraftBinding draft;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: draft,
    builder: (context, _) {
      if (!draft.hasDraft) return const SizedBox.shrink();
      final loc = AppLocalizations.of(context);
      final colors = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.hasError
                      ? loc.draftSaveFailed
                      : draft.restored
                      ? loc.draftRestored
                      : loc.draftSavedLocally,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton.icon(
                  onPressed: draft.discard,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(loc.discardDraft),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
