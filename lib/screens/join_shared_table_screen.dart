import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/auth_localizations.dart';
import '../models/tabel_model.dart';
import '../models/tally_model.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../services/cloud_repository.dart';
import '../services/storage_service.dart';
import '../widgets/join_code_cells.dart';
import '../widgets/ledger.dart';

/// Kayit olmadan bir tabloya katilma. Katilan kisi ne e-posta girer ne sifre
/// belirler; kimlik arka planda sessizce acilir.
///
/// Uc adim halinde sorulur: once kod, kod dogruysa ve tablo sifreliyse
/// sifre, en son ad. Hepsini tek ekranda sormak kullaniciyi bilmedigi
/// seyleri doldurmaya zorluyordu: sifresiz bir tabloya katilirken bile bos
/// bir sifre kutusu goruyor, kodu yanlissa adini bosuna yaziyordu.
enum _JoinStep { code, password, name }

class JoinSharedTableScreen extends StatefulWidget {
  const JoinSharedTableScreen({super.key, this.repository});

  @visibleForTesting
  final CloudRepository? repository;

  @override
  State<JoinSharedTableScreen> createState() => _JoinSharedTableScreenState();
}

class _JoinSharedTableScreenState extends State<JoinSharedTableScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  late final CloudRepository _repository =
      widget.repository ?? CloudRepository();

  _JoinStep _step = _JoinStep.code;
  SharedTablePeek? _peek;
  bool _isBusy = false;
  bool _passwordVisible = false;
  bool _nameLoaded = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    // Daha once girilen ad varsayilan olarak gelir ama kullanici yine de
    // onaylar: bu tabloda o ad alinmis olabilir.
    StorageService.loadSharedDisplayName().then((name) {
      if (!mounted) return;
      setState(() {
        if (name != null) _nameController.text = name;
        _nameLoaded = true;
      });
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Her adimin ortak kabugu: mesgul isareti, hata kodu cevirisi ve
  /// adim degisirken eski hatanin silinmesi tek yerde.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _errorCode = null;
    });
    try {
      await action();
    } on SharedTableException catch (error) {
      if (!error.isKnown) debugPrint('Bilinmeyen katilim kodu: ${error.code}');
      if (mounted) {
        setState(() => _errorCode = error.isKnown ? error.code : 'unknown');
      }
    } catch (error) {
      debugPrint('Tabloya katilinamadi: $error');
      if (mounted) setState(() => _errorCode = 'unknown');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submitCode() async {
    final auth = context.read<AuthProvider>();
    await _run(() async {
      if (!await auth.ensureAnonymousSession()) {
        if (mounted) setState(() => _errorCode = 'authentication_required');
        return;
      }
      final peek = await _repository.peekSharedTable(
        code: _codeController.text,
      );
      if (!mounted) return;
      setState(() {
        _peek = peek;
        _step = peek.requiresPassword ? _JoinStep.password : _JoinStep.name;
      });
    });
  }

  Future<void> _submitPassword() async {
    await _run(() async {
      final peek = await _repository.peekSharedTable(
        code: _codeController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _peek = peek;
        _step = _JoinStep.name;
      });
    });
  }

  Future<void> _submitName() async {
    final loc = AppLocalizations.of(context);
    final tables = context.read<TableProvider>();
    final tallies = context.read<TallyProvider>();
    // Bildirim tasiyicisi await'lerden once yakalanir: basarili katilimdan
    // sonra bu ekran zaten kapaniyor.
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      final join = await _repository.joinSharedTable(
        code: _codeController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
      if (join.displayName != null) {
        await StorageService.saveSharedDisplayName(join.displayName!);
      }

      // Katilmak yalnizca erisim verir; tablonun kendisi ayrica inmeli.
      final entries = await _repository.list();
      final entry = entries
          .where((item) => item.id == join.tableId)
          .firstOrNull;
      if (entry == null) {
        if (mounted) setState(() => _errorCode = 'table_not_found');
        return;
      }
      // Yeni katilan kisi yalnizca goruntuler; daha once duzenleme yetkisi
      // almis biri yeniden katiliyorsa yetkisi durur. Hangisi oldugunu
      // sunucu bilir.
      final role = await _joinedRole(join.tableId);
      if (entry.kind == 'tally') {
        final joined = TallyTableModel.fromJson(entry.payload);
        await tallies.importCloudTable(joined, overwrite: true);
        await tallies.setSharedRole(joined.id, role);
      } else if (entry.kind == 'table') {
        final joined = TableModel.fromJson(entry.payload);
        await tables.importCloudTable(joined, overwrite: true);
        await tables.setSharedRole(joined.id, role);
      } else {
        if (mounted) setState(() => _errorCode = 'table_not_found');
        return;
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text(loc.joinedTable(entry.name))),
      );
    });
  }

  /// Katilinan tablodaki rol. Okunamazsa goruntuleyen sayilir: yazma yetkisi
  /// zaten sunucuda denetlenir, yanlis tarafa hata yapmak kullaniciya
  /// gonderilemeyecek degisiklikler yaptirirdi.
  Future<String> _joinedRole(String tableId) async {
    try {
      final role = (await _repository.sharedTableAccess(tableId)).role;
      return const {'owner', 'editor'}.contains(role) ? role! : 'viewer';
    } catch (error) {
      debugPrint('Katilim rolu okunamadi: $error');
      return 'viewer';
    }
  }

  /// Geri tusu once adimlari geri alir, en basta ekrani kapatir. Kullanici
  /// yanlis kod girdiginde bastan baslamak zorunda kalmasin diye.
  void _back() {
    if (_step == _JoinStep.code) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _errorCode = null;
      _step = _step == _JoinStep.name && (_peek?.requiresPassword ?? false)
          ? _JoinStep.password
          : _JoinStep.code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final peek = _peek;
    final codeReady = _codeController.text.length == JoinCodeCells.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.joinTable),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isBusy ? null : _back,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _isBusy
              ? const LinearProgressIndicator(minHeight: 3)
              : const SizedBox(height: 3),
        ),
      ),
      body: !_nameLoaded
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    // Hangi tabloya girildiği kod doğrulanır doğrulanmaz
                    // yazılır; kişi doğru tabloda olduğunu adını yazmadan
                    // önce görür. Paylaşan kişinin gördüğü başlıkla aynı.
                    if (_step != _JoinStep.code && peek != null) ...[
                      Row(
                        children: [
                          Icon(
                            peek.kind == 'tally'
                                ? Icons.grid_on_rounded
                                : Icons.table_chart_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              peek.tableName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      switch (_step) {
                        _JoinStep.code => loc.joinTableExplainer,
                        _JoinStep.password => loc.joinPasswordRequired,
                        _JoinStep.name => loc.joinNameStepExplainer,
                      },
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _stepField(loc),
                    if (_step == _JoinStep.name) ...[
                      const SizedBox(height: 8),
                      Text(
                        loc.yourNameHint,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (_errorCode != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          loc.sharedTableError(_errorCode!),
                          style: TextStyle(color: colors.error, height: 1.4),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const ValueKey('join-submit'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed:
                          _isBusy || (_step == _JoinStep.code && !codeReady)
                          ? null
                          : _submitStep,
                      child: Text(
                        _step == _JoinStep.name
                            ? loc.joinAction
                            : loc.continueLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _submitStep() {
    switch (_step) {
      case _JoinStep.code:
        _submitCode();
      case _JoinStep.password:
        _submitPassword();
      case _JoinStep.name:
        _submitName();
    }
  }

  /// Adımın tek alanı. Kod, paylaşan kişinin gördüğü hücrelerle yazılır;
  /// şifre ve ad, hesap ekranındaki tablo satırıyla.
  Widget _stepField(AppLocalizations loc) {
    final colors = Theme.of(context).colorScheme;
    const text = TextStyle(fontSize: 16);
    switch (_step) {
      case _JoinStep.code:
        return JoinCodeInput(
          controller: _codeController,
          semanticLabel: loc.joinCode,
          enabled: !_isBusy,
          hasError: _errorCode != null,
          onChanged: (_) {
            // Rakam eklenip silindikçe düğme açılıp kapanır; düzeltmeye
            // başlanan kodun hatası da ekranda kalmaz.
            setState(() => _errorCode = null);
          },
          // Altıncı rakamla birlikte kod kendiliğinden sorulur.
          onCompleted: (_) => _isBusy ? null : _submitCode(),
        );
      case _JoinStep.password:
        return LedgerCard(
          children: [
            LedgerField(
              key: const ValueKey('row-join-password'),
              label: loc.joinPassword,
              trailing: IconButton(
                tooltip: loc.authText(
                  _passwordVisible ? 'hidePassword' : 'showPassword',
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ),
              builder: (focusNode) => TextField(
                key: const ValueKey('join-password'),
                controller: _passwordController,
                focusNode: focusNode,
                enabled: !_isBusy,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.done,
                style: text,
                decoration: ledgerInputDecoration(context),
                onSubmitted: (_) => _isBusy ? null : _submitPassword(),
              ),
            ),
          ],
        );
      case _JoinStep.name:
        return LedgerCard(
          children: [
            LedgerField(
              key: const ValueKey('row-join-name'),
              label: loc.yourName,
              builder: (focusNode) => TextField(
                key: const ValueKey('join-name'),
                controller: _nameController,
                focusNode: focusNode,
                enabled: !_isBusy,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(32)],
                style: text,
                decoration: ledgerInputDecoration(context),
                onSubmitted: (_) => _isBusy ? null : _submitName(),
              ),
            ),
          ],
        );
    }
  }
}
