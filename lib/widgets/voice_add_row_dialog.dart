import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ux_localizations.dart';
import '../models/tabel_model.dart';
import '../providers/table_provider.dart';
import '../services/form_draft_store.dart';
import '../services/formula_service.dart';
import '../services/voice_row_parser.dart';
import 'form_draft_guard.dart';

enum _SpeechProblem { permission, unavailable, noSpeech, recognition }

class VoiceAddRowDialog extends StatefulWidget {
  const VoiceAddRowDialog({super.key});

  @override
  State<VoiceAddRowDialog> createState() => _VoiceAddRowDialogState();
}

class _VoiceAddRowDialogState extends State<VoiceAddRowDialog>
    with WidgetsBindingObserver {
  final _speech = SpeechToText();
  final _parser = const VoiceRowParser();
  final _transcript = TextEditingController();
  final _reviewKey = GlobalKey();
  final _highlightTimers = <int, Timer>{};
  final _highlightedFields = <int>{};
  late final List<ColumnModel> _columns;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _fieldFocus;
  late final String _tableId;
  late final String _tableName;
  late final String _schema;
  late final FormDraftStore _draft;
  bool _ready = false;
  bool _starting = false;
  bool _listening = false;
  bool _acceptResults = false;
  bool _sessionHadResult = false;
  bool _reviewing = false;
  bool _saving = false;
  bool _restoringDraft = true;
  bool _draftTouched = false;
  bool _draftRestored = false;
  bool _saveFailed = false;
  bool _tableChanged = false;
  _SpeechProblem? _problem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final table = context.read<TableProvider>().currentTable!;
    _tableId = table.id;
    _tableName = table.tableName;
    _columns = table.columns.map((column) => column.copyWith()).toList();
    _schema = jsonEncode(_columns.map((column) => column.toJson()).toList());
    _controllers = List.generate(
      _columns.length,
      (index) => TextEditingController(text: _defaultValue(index, table)),
    );
    _fieldFocus = List.generate(_columns.length, (_) => FocusNode());
    _recalculateFormulas();
    _draft = FormDraftStore('voice_row_$_tableId');
    _restoreDraft();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_draft.flush());
    }
  }

  Future<void> _restoreDraft() async {
    final data = await _draft.read();
    if (!mounted) return;
    if (_draftTouched || data == null || data['schema'] != _schema) {
      setState(() => _restoringDraft = false);
      return;
    }
    final values = data['values'];
    if (values is! List || values.length != _columns.length) {
      setState(() => _restoringDraft = false);
      return;
    }
    for (var index = 0; index < values.length; index++) {
      if (!_columns[index].isAutoNumber && !_columns[index].isFormula) {
        _controllers[index].text = values[index]?.toString() ?? '';
      }
    }
    _transcript.text = data['transcript']?.toString() ?? '';
    _recalculateFormulas();
    setState(() {
      _draftRestored = true;
      _reviewing = true;
      _restoringDraft = false;
    });
  }

  void _saveDraft() {
    _draftTouched = true;
    _draft.schedule({
      'schema': _schema,
      'values': _controllers.map((controller) => controller.text).toList(),
      'transcript': _transcript.text,
    });
  }

  String _defaultValue(int index, TableModel table) {
    final column = _columns[index];
    if (column.isConstant && column.constantValue != null) {
      return _formatNumber(column.constantValue!);
    }
    if (column.isDate) {
      final now = DateTime.now();
      return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    }
    if (column.isTime) {
      final now = TimeOfDay.now();
      return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    if (column.isAutoNumber) return '${table.nextAutoNumber(index)}';
    return '';
  }

  void _onSpeechStatus(String status) {
    if (!mounted || _saving || !_acceptResults) return;
    setState(() {
      _listening = _problem == null && status == 'listening';
      if (!_listening && _sessionHadResult) _reviewing = true;
    });
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted || !_acceptResults) return;
    final problem = _classifyProblem(error.errorMsg);
    setState(() {
      _problem = problem == _SpeechProblem.noSpeech && _sessionHadResult
          ? null
          : problem;
      _listening = false;
      _starting = false;
      if (_sessionHadResult) _reviewing = true;
    });
  }

  Future<bool> _initializeSpeech() async {
    // initialize skips replacing callbacks once the singleton is ready.
    // Rebind them to this form when it is reopened.
    _speech.statusListener = _onSpeechStatus;
    _speech.errorListener = _onSpeechError;
    final ready = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    if (!mounted) return false;
    _ready = ready;
    if (!ready) {
      final permitted = await _speech.hasPermission;
      if (!mounted) return false;
      setState(() {
        _problem = permitted
            ? _SpeechProblem.unavailable
            : _SpeechProblem.permission;
      });
    }
    return ready;
  }

  _SpeechProblem _classifyProblem(String message) {
    final value = message.toLowerCase();
    if (value.contains('permission') || value.contains('not_authorized')) {
      return _SpeechProblem.permission;
    }
    if (value.contains('no_match') || value.contains('speech_timeout')) {
      return _SpeechProblem.noSpeech;
    }
    if (value.contains('language') ||
        value.contains('not_available') ||
        value.contains('not_supported') ||
        value.contains('recognizer_disabled')) {
      return _SpeechProblem.unavailable;
    }
    return _SpeechProblem.recognition;
  }

  Future<void> _toggleListening() async {
    if (_saving || _starting || _restoringDraft) return;
    if (_listening) {
      await _stopListening();
      return;
    }
    FocusScope.of(context).unfocus();
    final languageCode = Localizations.localeOf(context).languageCode;
    setState(() {
      _starting = true;
      _draftTouched = true;
      _problem = null;
      _saveFailed = false;
      _sessionHadResult = false;
      _acceptResults = true;
      _reviewing = false;
    });
    try {
      if (!_ready && !await _initializeSpeech()) return;
      if (!mounted) return;
      await _speech.listen(
        onResult: (result) {
          if (!mounted || !_acceptResults || _saving) return;
          if (result.recognizedWords.trim().isEmpty) return;
          _sessionHadResult = true;
          _transcript.text = result.recognizedWords;
          _applyTranscript(fromSpeech: true);
          if (result.finalResult) {
            _acceptResults = false;
            setState(() {
              _listening = false;
              _reviewing = true;
            });
          }
        },
        listenOptions: SpeechListenOptions(
          onDevice: true,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: languageCode == 'tr' ? 'tr_TR' : 'en_US',
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 45),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _problem = _classifyProblem(error.toString());
          _listening = false;
        });
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {
      // The already recognized text remains available for review.
    }
    if (!mounted) return;
    _acceptResults = false;
    setState(() {
      _listening = false;
      _reviewing = true;
    });
  }

  void _applyTranscript({required bool fromSpeech}) {
    if (!fromSpeech) _acceptResults = false;
    final values = _parser.parse(_transcript.text, _columns);
    for (final entry in values.entries) {
      if (_controllers[entry.key].text == entry.value) continue;
      _controllers[entry.key].text = entry.value;
      if (fromSpeech) {
        _highlightedFields.add(entry.key);
        _highlightTimers[entry.key]?.cancel();
        _highlightTimers[entry.key] = Timer(
          const Duration(milliseconds: 1800),
          () {
            if (!mounted) return;
            setState(() => _highlightedFields.remove(entry.key));
          },
        );
      }
    }
    _recalculateFormulas();
    _saveDraft();
    setState(() {
      if (!fromSpeech) _reviewing = true;
      _saveFailed = false;
    });
  }

  void _recalculateFormulas() {
    final formulaCount = _columns.where((column) => column.isFormula).length;
    for (var pass = 0; pass < formulaCount; pass++) {
      final row = _controllers.map((controller) => controller.text).toList();
      for (var index = 0; index < _columns.length; index++) {
        final column = _columns[index];
        if (column.isFormula && column.formula != null) {
          final result = FormulaService.calculate(
            column.formula!,
            row,
            _columns,
          );
          _controllers[index].text = result == null
              ? ''
              : _formatNumber(result);
        }
      }
    }
  }

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  Future<void> _typeInstead() async {
    if (_restoringDraft || _saving || _starting) return;
    _acceptResults = false;
    await _stopListening();
    if (!mounted) return;
    final reviewContext = _reviewKey.currentContext;
    if (reviewContext != null && reviewContext.mounted) {
      await Scrollable.ensureVisible(
        reviewContext,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
    }
    if (!mounted) return;
    final firstEditable = _columns.indexWhere(
      (column) => !column.isAutoNumber && !column.isFormula,
    );
    if (firstEditable >= 0) _fieldFocus[firstEditable].requestFocus();
  }

  Future<void> _confirm() async {
    if (_saving || _listening || _starting || _restoringDraft) return;
    final provider = context.read<TableProvider>();
    final table = provider.currentTable;
    if (table == null ||
        table.id != _tableId ||
        jsonEncode(table.columns.map((column) => column.toJson()).toList()) !=
            _schema) {
      setState(() => _tableChanged = true);
      return;
    }
    _acceptResults = false;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _draftTouched = true;
      _saveFailed = false;
    });
    try {
      for (var index = 0; index < _columns.length; index++) {
        if (_columns[index].isAutoNumber) {
          _controllers[index].text = table.nextAutoNumber(index).toString();
        }
      }
      _recalculateFormulas();
      final success = await provider.addRow(
        _controllers.map((controller) => controller.text.trim()).toList(),
      );
      if (!success) {
        if (mounted) setState(() => _saveFailed = true);
        return;
      }
      await _draft.clear();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discardDraft() async {
    if (_saving || _restoringDraft || _starting) return;
    _acceptResults = false;
    _draftTouched = true;
    FocusScope.of(context).unfocus();
    setState(() => _restoringDraft = true);
    await _stopListening();
    if (!mounted) return;
    final table = context.read<TableProvider>().currentTable;
    if (table == null) return;
    for (var i = 0; i < _columns.length; i++) {
      _controllers[i].text = _defaultValue(i, table);
    }
    _transcript.clear();
    _recalculateFormulas();
    await _draft.clear();
    if (!mounted) return;
    setState(() {
      _draftRestored = false;
      _restoringDraft = false;
      _reviewing = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _acceptResults = false;
    if (_speech.statusListener == _onSpeechStatus)
      _speech.statusListener = null;
    if (_speech.errorListener == _onSpeechError) _speech.errorListener = null;
    _speech.cancel();
    _draft.dispose();
    for (final timer in _highlightTimers.values) {
      timer.cancel();
    }
    _transcript.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _fieldFocus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return FormDraftGuard(
      isSaving: _saving || _restoringDraft,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          toolbarHeight: (MediaQuery.textScalerOf(context).scale(20) + 32)
              .clamp(56.0, 112.0),
          title: Text(loc.voiceFill),
          leading: IconButton(
            tooltip: loc.close,
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(_tableName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildSteps(loc),
              const SizedBox(height: 16),
              if (_restoringDraft) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              if (_draftRestored) ...[
                _buildNotice(loc.draftRestored, Icons.history_rounded),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _discardDraft,
                    child: Text(loc.discardDraft),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildVoiceCard(loc),
              if (_problem != null) ...[
                const SizedBox(height: 12),
                _buildSpeechError(loc),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _transcript,
                minLines: 2,
                maxLines: 5,
                readOnly: _listening || _starting || _saving || _restoringDraft,
                onChanged: (_) => _applyTranscript(fromSpeech: false),
                decoration: InputDecoration(
                  labelText: loc.recognizedSpeech,
                  hintText: loc.recognizedSpeechHint,
                  prefixIcon: const Icon(Icons.graphic_eq_rounded),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.reviewFields,
                key: _reviewKey,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                loc.voiceReviewHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              ..._columns.asMap().entries.map(_buildFieldCard),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Material(
            color: colors.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_saveFailed || _tableChanged) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _tableChanged ? loc.recordChanged : loc.rowSaveFailed,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                      onPressed:
                          _saving ||
                              _listening ||
                              _starting ||
                              _tableChanged ||
                              _restoringDraft
                          ? null
                          : _confirm,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _saving ? loc.savingProgress : loc.confirmAndAdd,
                        textAlign: TextAlign.center,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSteps(AppLocalizations loc) {
    final colors = Theme.of(context).colorScheme;
    final current = _saving ? 2 : (_reviewing ? 1 : 0);
    final labels = [loc.voiceStepSpeak, loc.voiceStepReview, loc.voiceStepAdd];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (index) {
        final selected = index == current;
        return Semantics(
          selected: selected,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primaryContainer
                  : colors.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '${index + 1}  ${labels[index]}',
              style: TextStyle(
                color: selected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }),
    );
  }

  String _example(AppLocalizations loc) {
    final spokenColumns = _columns.where((column) => column.isNormal).take(3);
    if (spokenColumns.isEmpty) return loc.voiceNoEditableColumns;
    final parts = spokenColumns.map((column) {
      final value = column.isNumeric
          ? '10'
          : column.autoFillOptions
                    .where((value) => value.trim().isNotEmpty)
                    .firstOrNull ??
                loc.voiceExampleValue;
      return '${column.name} $value';
    });
    return loc.voiceExampleFor(parts.join(', '));
  }

  Widget _buildVoiceCard(AppLocalizations loc) {
    final colors = Theme.of(context).colorScheme;
    final canSpeak = _columns.any((column) => column.isNormal);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.phonelink_lock_rounded,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.onDeviceRecognition,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(loc.voiceInstructions),
          const SizedBox(height: 8),
          Text(_example(loc), style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving || _starting || _restoringDraft || !canSpeak
                ? null
                : _toggleListening,
            style: _listening
                ? FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  )
                : null,
            icon: _starting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(
              _starting
                  ? loc.preparingMicrophone
                  : _listening
                  ? loc.stopListening
                  : loc.tapToSpeak,
              textAlign: TextAlign.center,
            ),
          ),
          if (_listening) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                loc.listening,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.primary),
              ),
            ),
          ],
          TextButton.icon(
            onPressed: _saving || _starting || _restoringDraft
                ? null
                : _typeInstead,
            icon: const Icon(Icons.keyboard_alt_outlined),
            label: Text(loc.voiceTypeInstead, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechError(AppLocalizations loc) {
    final colors = Theme.of(context).colorScheme;
    final message = switch (_problem!) {
      _SpeechProblem.permission => loc.voicePermissionDenied,
      _SpeechProblem.unavailable => loc.voiceServiceUnavailable,
      _SpeechProblem.noSpeech => loc.voiceNoSpeech,
      _SpeechProblem.recognition => loc.voiceRecognitionFailed,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: TextStyle(color: colors.onErrorContainer)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving || _starting ? null : _toggleListening,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(loc.voiceTryAgain),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotice(String message, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldCard(MapEntry<int, ColumnModel> entry) {
    final column = entry.value;
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final highlighted = _highlightedFields.contains(entry.key);
    final readOnly = column.isFormula || column.isAutoNumber;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: highlighted ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controllers[entry.key],
        focusNode: _fieldFocus[entry.key],
        readOnly:
            readOnly || _listening || _starting || _saving || _restoringDraft,
        keyboardType: column.isEffectivelyNumeric
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        onTap: () {
          if (!_listening && !_starting && !_saving && !_reviewing) {
            setState(() => _reviewing = true);
          }
        },
        onChanged: (_) {
          _acceptResults = false;
          _recalculateFormulas();
          _saveDraft();
          setState(() {
            _reviewing = true;
            _saveFailed = false;
          });
        },
        decoration: InputDecoration(
          labelText: column.name,
          prefixIcon: Icon(_columnIcon(column), color: colors.primary),
          suffixIcon: highlighted
              ? Tooltip(
                  message: loc.voiceFilledField,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.primary,
                    semanticLabel: loc.voiceFilledField,
                  ),
                )
              : readOnly
              ? const Icon(Icons.lock_outline_rounded, size: 18)
              : null,
          filled: false,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: highlighted ? colors.primary : colors.outlineVariant,
              width: highlighted ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }

  IconData _columnIcon(ColumnModel column) {
    if (column.isDate) return Icons.calendar_today_rounded;
    if (column.isTime) return Icons.schedule_rounded;
    if (column.isAutoNumber) return Icons.tag_rounded;
    if (column.isFormula) return Icons.functions_rounded;
    if (column.isEffectivelyNumeric) return Icons.numbers_rounded;
    return Icons.short_text_rounded;
  }
}
