import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/tabel_model.dart';
import '../models/tally_model.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../services/cloud_repository.dart';
import '../services/storage_service.dart';

/// Kayit olmadan bir tabloya katilma. Katilan kisi ne e-posta girer ne sifre
/// belirler; kimlik arka planda sessizce acilir.
///
/// Uc adim halinde sorulur: once kod, kod dogruysa ve tablo sifreliyse
/// sifre, en son ad. Hepsini tek ekranda sormak kullaniciyi bilmedigi
/// seyleri doldurmaya zorluyordu: sifresiz bir tabloya katilirken bile bos
/// bir sifre kutusu goruyor, kodu yanlissa adini bosuna yaziyordu.
enum _JoinStep { code, password, name }

class JoinSharedTableScreen extends StatefulWidget {
  const JoinSharedTableScreen({super.key});

  @override
  State<JoinSharedTableScreen> createState() => _JoinSharedTableScreenState();
}

class _JoinSharedTableScreenState extends State<JoinSharedTableScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _repository = CloudRepository();

  _JoinStep _step = _JoinStep.code;
  SharedTablePeek? _peek;
  bool _isBusy = false;
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
      if (entry.kind == 'tally') {
        final joined = TallyTableModel.fromJson(entry.payload);
        await tallies.importCloudTable(joined, overwrite: true);
        await tallies.setSharedRole(joined.id, 'editor');
      } else if (entry.kind == 'table') {
        final joined = TableModel.fromJson(entry.payload);
        await tables.importCloudTable(joined, overwrite: true);
        // Bundan sonra bu tablodaki duzenlemeler kuyruga yazilir ve butonla
        // gonderilir; aninda gonderim yalnizca paylasan kisidedir.
        await tables.setSharedRole(joined.id, 'editor');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.joinTable),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isBusy ? null : _back,
        ),
      ),
      body: !_nameLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Hangi tabloya girildigi kod dogrulanir dogrulanmaz yazilir;
                // kullanici dogru tabloda oldugunu adini yazmadan once gorur.
                if (_peek != null) ...[
                  Text(
                    loc.joiningTable(_peek!.tableName),
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ..._stepFields(loc),
                if (_errorCode != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    loc.sharedTableError(_errorCode!),
                    style: TextStyle(color: colors.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isBusy ? null : _submitStep,
                  child: Text(
                    _isBusy
                        ? loc.pleaseWait
                        : (_step == _JoinStep.name
                              ? loc.joinAction
                              : loc.continueLabel),
                  ),
                ),
              ],
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

  List<Widget> _stepFields(AppLocalizations loc) {
    final colors = Theme.of(context).colorScheme;
    switch (_step) {
      case _JoinStep.code:
        return [
          Text(
            loc.joinTableExplainer,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _codeController,
            autofocus: true,
            autocorrect: false,
            keyboardType: TextInputType.number,
            inputFormatters: [
              LengthLimitingTextInputFormatter(6),
              FilteringTextInputFormatter.digitsOnly,
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(labelText: loc.joinCode),
            onSubmitted: (_) => _isBusy ? null : _submitCode(),
          ),
        ];
      case _JoinStep.password:
        return [
          Text(
            loc.joinPasswordRequired,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _passwordController,
            autofocus: true,
            autocorrect: false,
            obscureText: true,
            decoration: InputDecoration(
              labelText: loc.joinPassword,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
            ),
            onSubmitted: (_) => _isBusy ? null : _submitPassword(),
          ),
        ];
      case _JoinStep.name:
        return [
          Text(
            loc.joinNameStepExplainer,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(32)],
            decoration: InputDecoration(
              labelText: loc.yourName,
              helperText: loc.yourNameHint,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            onSubmitted: (_) => _isBusy ? null : _submitName(),
          ),
        ];
    }
  }
}
