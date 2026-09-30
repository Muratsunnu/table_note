import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/tabel_model.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../services/cloud_repository.dart';
import '../services/storage_service.dart';

/// Kayit olmadan bir tabloya katilma. Katilan kisi ne e-posta girer ne sifre
/// belirler; kimlik arka planda sessizce acilir. Ekranda yalnizca kod, varsa
/// tablonun sifresi ve bu tabloda gorunecek ad vardir.
class JoinSharedTableScreen extends StatefulWidget {
  const JoinSharedTableScreen({super.key});

  @override
  State<JoinSharedTableScreen> createState() => _JoinSharedTableScreenState();
}

class _JoinSharedTableScreenState extends State<JoinSharedTableScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isBusy = false;
  bool _nameLoaded = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    // The name typed for an earlier table comes back as the default, but the
    // person still confirms it: it may be taken in this table.
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

  Future<void> _join() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final loc = AppLocalizations.of(context);
    final auth = context.read<AuthProvider>();
    final tables = context.read<TableProvider>();
    // Bildirim tasiyicisi da await'lerden once yakalanir: basarili
    // katilimdan sonra bu ekran zaten kapaniyor.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isBusy = true;
      _errorCode = null;
    });
    try {
      if (!await auth.ensureAnonymousSession()) {
        if (mounted) setState(() => _errorCode = 'authentication_required');
        return;
      }
      final repository = CloudRepository();
      final join = await repository.joinSharedTable(
        code: _codeController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
      if (join.displayName != null) {
        await StorageService.saveSharedDisplayName(join.displayName!);
      }

      // Joining only grants access; the table itself still has to come down.
      final entries = await repository.list();
      final entry = entries
          .where((item) => item.id == join.tableId)
          .firstOrNull;
      if (entry == null) {
        if (mounted) setState(() => _errorCode = 'table_not_found');
        return;
      }
      final joined = TableModel.fromJson(entry.payload);
      await tables.importCloudTable(joined, overwrite: true);
      // Bundan sonra bu tablodaki duzenlemeler kuyruga yazilir ve butonla
      // gonderilir; aninda gonderim yalnizca tabloyu paylasan kisidedir.
      await tables.setSharedRole(joined.id, 'editor');
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text(loc.joinedTable(entry.name))),
      );
    } on SharedTableException catch (error) {
      // Beklenmeyen bir sunucu kodu kullaniciya ham haliyle gosterilmez ama
      // teshis edilemez de kalmamali.
      if (!error.isKnown) debugPrint('Bilinmeyen katilim kodu: ${error.code}');
      if (mounted) {
        setState(() => _errorCode = error.isKnown ? error.code : 'unknown');
      }
    } catch (error) {
      // Beklenmeyen hatayi yutmak teshisi imkansiz kilar; kullaniciya genel
      // mesaj gosterilir ama sebep loga yazilir.
      debugPrint('Tabloya katilinamadi: $error');
      if (mounted) setState(() => _errorCode = 'unknown');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(loc.joinTable)),
      body: !_nameLoaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    loc.joinTableExplainer,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    autocorrect: false,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(6),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: loc.joinCode,
                      prefixIcon: const Icon(Icons.key_rounded),
                    ),
                    validator: (value) =>
                        RegExp(r'^[0-9]{6}$').hasMatch((value ?? '').trim())
                        ? null
                        : loc.sharedTableError('invalid_table_code'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    autocorrect: false,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: loc.joinPasswordOptional,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(32)],
                    decoration: InputDecoration(
                      labelText: loc.yourName,
                      helperText: loc.yourNameHint,
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => (value ?? '').trim().length >= 2
                        ? null
                        : loc.sharedTableError('invalid_display_name'),
                  ),
                  if (_errorCode != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      loc.sharedTableError(_errorCode!),
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isBusy ? null : _join,
                    child: Text(_isBusy ? loc.pleaseWait : loc.joinAction),
                  ),
                ],
              ),
            ),
    );
  }
}
