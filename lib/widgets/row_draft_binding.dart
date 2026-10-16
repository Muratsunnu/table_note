import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

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
  final String _schema;
  String _lastValues;
  bool isRestoring = true;
  bool _disposed = false;
  bool _applying = false;
  bool _edited = false;
  bool _completed = false;

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
    _store.schedule({
      'schema': _schema,
      'originalRow': originalRow,
      'values': values,
    });
    notifyListeners();
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
