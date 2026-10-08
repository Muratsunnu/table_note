import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../theme/app_theme.dart';
import 'form_draft_guard.dart';
import 'ledger.dart';

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
  final _highlightTimers = <int, Timer>{};
  final _highlightedFields = <int>{};

  /// Söylenenin sayıya çevrilemediği sayısal sütunlar.
  Set<int> _unreadNumbers = {};

  /// Kaydetmeye çalışılırken sayı olmayan bir şey yazılı bulunan sütunlar.
  final _invalidNumbers = <int>{};
  late final List<ColumnModel> _columns;
  late final List<TextEditingController> _controllers;
  late final String _tableId;
  late final String _tableName;
  late final String _schema;
  late final FormDraftStore _draft;
  bool _ready = false;
  bool _starting = false;
  bool _listening = false;
  bool _acceptResults = false;
  bool _sessionHadResult = false;
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
            setState(() => _listening = false);
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
    setState(() => _listening = false);
  }

  void _applyTranscript({required bool fromSpeech}) {
    if (!fromSpeech) _acceptResults = false;
    final result = _parser.parse(
      _transcript.text,
      _columns,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    _unreadNumbers = result.unreadNumbers;
    for (final entry in result.values.entries) {
      _invalidNumbers.remove(entry.key);
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
    setState(() => _saveFailed = false);
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
    // Sayısal bir hücreye yazı girerse toplam onu sıfır sayar ve kimse fark
    // etmez. Kaydetmeden önce her sayısal hücre gerçekten sayı mı diye
    // bakılır; virgüllü yazılan ondalık da noktaya çevrilir.
    final invalid = <int>{};
    for (var index = 0; index < _columns.length; index++) {
      if (!_typedNumber(_columns[index])) continue;
      final text = _controllers[index].text.trim().replaceAll(',', '.');
      if (text.isEmpty) continue;
      if (double.tryParse(text) == null) {
        invalid.add(index);
      } else {
        _controllers[index].text = text;
      }
    }
    if (invalid.isNotEmpty) {
      setState(() {
        _invalidNumbers
          ..clear()
          ..addAll(invalid);
      });
      return;
    }
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

  /// Kullanıcının kendi yazdığı ya da söylediği sayısal sütun; formül ve
  /// sıra numarası kendiliğinden hesaplandığı için bunlara dahil değildir.
  bool _typedNumber(ColumnModel column) =>
      column.isEffectivelyNumeric && !column.isFormula && !column.isAutoNumber;

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
    _unreadNumbers = {};
    _invalidNumbers.clear();
    _recalculateFormulas();
    await _draft.clear();
    if (!mounted) return;
    setState(() {
      _draftRestored = false;
      _restoringDraft = false;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final busy = _saving || _starting || _restoringDraft;
    final canSpeak = _columns.any((column) => column.isNormal);
    final hasTranscript = _transcript.text.trim().isNotEmpty;
    return FormDraftGuard(
      isSaving: _saving || _restoringDraft,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          // Temanın başlık yazısı koyu çubuk için beyazdır; bu ekranın çubuğu
          // açık renk olduğundan başlık açık temada görünmez kalıyordu.
          titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
            color: colors.onSurface,
          ),
          toolbarHeight: (MediaQuery.textScalerOf(context).scale(36) + 28)
              .clamp(56.0, 112.0),
          // Hangi tabloya eklendiği başlığın altında durur; gövdede ayrı bir
          // satır tutmaz.
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.voiceFill),
              Text(
                _tableName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          leading: IconButton(
            tooltip: loc.close,
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _restoringDraft
                ? const LinearProgressIndicator(minHeight: 3)
                : const SizedBox(height: 3),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_draftRestored) ...[
                _boxed(
                  LedgerNote(
                    loc.draftRestored,
                    action: TextButton(
                      style: _inlineAction,
                      onPressed: _discardDraft,
                      child: Text(loc.discardDraft),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Ekranın işi tek bir şey: mikrofona basıp konuşmak.
              Center(
                child: _MicButton(
                  listening: _listening,
                  starting: _starting,
                  semanticLabel: _listening
                      ? loc.stopListening
                      : loc.tapToSpeak,
                  onPressed: _saving || _restoringDraft || !canSpeak
                      ? null
                      : _toggleListening,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  !canSpeak
                      ? loc.voiceNoEditableColumns
                      : _starting
                      ? loc.preparingMicrophone
                      : _listening
                      ? loc.listening
                      : loc.tapToSpeak,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _listening ? colors.primary : colors.onSurface,
                  ),
                ),
              ),
              // Ne söyleneceğinin örneği yalnızca henüz konuşulmamışken durur.
              if (canSpeak && !hasTranscript) ...[
                const SizedBox(height: 6),
                Text(
                  _example(loc),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (!_listening) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phonelink_lock_rounded,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          loc.onDeviceRecognition,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (_problem != null) ...[
                const SizedBox(height: 16),
                _buildSpeechError(loc),
              ],
              // Konuşma başlayınca söylenen burada belirir; yanlış duyulan
              // yer elle düzeltilebilir ve alanlar yeniden doldurulur.
              if (hasTranscript || _listening) ...[
                const SizedBox(height: 18),
                _sectionLabel(loc.recognizedSpeech),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: AppTheme.tintedSurface(context, colors.primary),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('voice-transcript'),
                          controller: _transcript,
                          minLines: 1,
                          maxLines: 5,
                          readOnly: _listening || busy,
                          onChanged: (_) => _applyTranscript(fromSpeech: false),
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.35,
                            color: colors.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: loc.recognizedSpeechHint,
                            filled: false,
                            isCollapsed: true,
                            // Temanın iç boşluğu yazıyı simgeden aşağı itiyor.
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _sectionLabel(loc.reviewFields),
              // Eklenecek satır, tablodaki haliyle: solda sütun, sağda değer.
              LedgerCard(
                children: [
                  for (final entry in _columns.asMap().entries)
                    _buildFieldRow(entry.key, entry.value),
                ],
              ),
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
                      onPressed: busy || _listening || _tableChanged
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

  /// Not içindeki düğme, notun yazısıyla aynı hizadan başlar.
  static final _inlineAction = TextButton.styleFrom(
    padding: EdgeInsets.zero,
    alignment: AlignmentDirectional.centerStart,
  );

  /// Tek başına duran bir not satırına kartın köşelerini verir.
  Widget _boxed(Widget child) =>
      ClipRRect(borderRadius: BorderRadius.circular(14), child: child);

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );

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

  Widget _buildSpeechError(AppLocalizations loc) {
    final message = switch (_problem!) {
      _SpeechProblem.permission => loc.voicePermissionDenied,
      _SpeechProblem.unavailable => loc.voiceServiceUnavailable,
      _SpeechProblem.noSpeech => loc.voiceNoSpeech,
      _SpeechProblem.recognition => loc.voiceRecognitionFailed,
    };
    return _boxed(
      LedgerNote(
        message,
        tone: LedgerNoteTone.error,
        action: TextButton(
          style: _inlineAction,
          onPressed: _saving || _starting ? null : _toggleListening,
          child: Text(loc.voiceTryAgain),
        ),
      ),
    );
  }

  /// Eklenecek satırın bir hücresi. Konuşmayla az önce dolan hücre kısa bir
  /// süre renklenir ki neyin anlaşıldığı görülsün.
  Widget _buildFieldRow(int index, ColumnModel column) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final highlighted = _highlightedFields.contains(index);
    // Sıra numarası ve formül kendiliğinden hesaplanır.
    final computed = column.isFormula || column.isAutoNumber;
    final Widget? mark = highlighted
        ? Tooltip(
            message: loc.voiceFilledField,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: colors.primary,
              semanticLabel: loc.voiceFilledField,
            ),
          )
        : computed
        ? Icon(_columnIcon(column), size: 18, color: colors.onSurfaceVariant)
        : null;
    return LedgerField(
      key: ValueKey('voice-field-$index'),
      label: column.name,
      highlighted: highlighted,
      trailing: mark == null
          ? null
          : SizedBox.square(dimension: 48, child: Center(child: mark)),
      builder: (focusNode) => TextField(
        controller: _controllers[index],
        focusNode: focusNode,
        readOnly:
            computed || _listening || _starting || _saving || _restoringDraft,
        keyboardType: column.isEffectivelyNumeric
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        textInputAction: TextInputAction.next,
        // Sayısal hücreye harf yazılamaz.
        inputFormatters: _typedNumber(column)
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))]
            : null,
        onChanged: (_) {
          _acceptResults = false;
          _recalculateFormulas();
          _saveDraft();
          setState(() {
            _saveFailed = false;
            _unreadNumbers.remove(index);
            _invalidNumbers.remove(index);
          });
        },
        style: TextStyle(
          fontSize: 16,
          color: computed ? colors.onSurfaceVariant : colors.onSurface,
        ),
        decoration: ledgerInputDecoration(context).copyWith(
          errorText: _invalidNumbers.contains(index)
              ? loc.numberOnly
              : _unreadNumbers.contains(index)
              ? loc.voiceNumberUnread
              : null,
        ),
      ),
    );
  }

  IconData _columnIcon(ColumnModel column) =>
      column.isAutoNumber ? Icons.tag_rounded : Icons.functions_rounded;
}

/// Ekranın tek büyük düğmesi: mavi bir daire. Dinlerken kırmızıya döner,
/// durdurma simgesi gösterir ve çevresinde bir halka genişleyip söner.
class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.listening,
    required this.starting,
    required this.semanticLabel,
    required this.onPressed,
  });

  final bool listening;
  final bool starting;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Halka yalnızca dinlerken ve hareket azaltma kapalıyken döner.
  void _sync() {
    final animate =
        widget.listening && !MediaQuery.disableAnimationsOf(context);
    if (animate) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else if (_pulse.isAnimating || _pulse.value != 0) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null && !widget.starting;
    final fill = widget.onPressed == null
        ? colors.onSurface.withValues(alpha: .12)
        : widget.listening
        ? colors.error
        : colors.primary;
    final ink = widget.onPressed == null
        ? colors.onSurface.withValues(alpha: .38)
        : widget.listening
        ? colors.onError
        : colors.onPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 136,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = _pulse.value;
                  return Container(
                    width: 96 + 40 * t,
                    height: 96 + 40 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill.withValues(
                        alpha: widget.listening ? .26 * (1 - t) : 0,
                      ),
                    ),
                  );
                },
              ),
              Material(
                key: const ValueKey('voice-mic'),
                color: fill,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? widget.onPressed : null,
                  child: SizedBox.square(
                    dimension: 96,
                    child: Center(
                      child: widget.starting
                          ? SizedBox.square(
                              dimension: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: ink,
                              ),
                            )
                          : Icon(
                              widget.listening
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              size: 44,
                              color: ink,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
