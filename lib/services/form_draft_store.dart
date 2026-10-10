import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small, device-local form drafts. Values are snapshots, never live models.
/// Writes are ordered per key so closing and immediately reopening a form is safe.
class FormDraftStore {
  FormDraftStore(String key) : _key = 'form_draft_v1_$key';

  final String _key;
  static final Map<String, Future<void>> _writes = {};
  Timer? _debounce;
  String? _pending;
  bool _disposed = false;
  Object? lastError;

  Future<Map<String, dynamic>?> read() async {
    try {
      await _writes[_key];
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_key);
      if (value == null) return null;
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (error) {
      lastError = error;
      return null;
    }
  }

  void schedule(Map<String, dynamic> snapshot) {
    if (_disposed) return;
    try {
      _pending = jsonEncode(snapshot);
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), flush);
    } catch (error) {
      lastError = error;
    }
  }

  Future<void> flush() {
    _debounce?.cancel();
    final pending = _pending;
    _pending = null;
    if (pending == null) return _writes[_key] ?? Future<void>.value();
    return _enqueue(() async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(_key, pending)) {
        throw StateError('Unable to save local form draft');
      }
    });
  }

  Future<void> clear() {
    _debounce?.cancel();
    _pending = null;
    return _enqueue(() async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.remove(_key)) {
        throw StateError('Unable to clear local form draft');
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() write) {
    final next = (_writes[_key] ?? Future<void>.value()).then((_) async {
      try {
        await write();
        lastError = null;
      } catch (error) {
        // Draft I/O must not turn a successful record save into a retry.
        lastError = error;
      }
    });
    _writes[_key] = next;
    unawaited(
      next.whenComplete(() {
        if (identical(_writes[_key], next)) _writes.remove(_key);
      }),
    );
    return next;
  }

  void dispose() {
    _disposed = true;
    unawaited(flush());
  }
}
