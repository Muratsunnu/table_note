import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../l10n/auth_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/auth_validation.dart';
import '../widgets/join_code_cells.dart';
import '../widgets/ledger.dart';

enum _AccountForm { login, register, forgot, verify, recover, password }

/// Giriş, kayıt, şifre işlemleri ve hesap yönetimi.
///
/// Form bir tablo gibi çizilir: solda etiket sütunu, sağda değer sütunu,
/// aralarda ince çizgiler. Uygulamanın işi tablo; hesabın girildiği yer de
/// öyle görünür.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  var _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _currentPassword = TextEditingController();
  final _nonce = TextEditingController();
  // E-postayla gelen 6 haneli kod: kayıt doğrulaması ve şifre sıfırlama.
  final _code = TextEditingController();
  final _visiblePasswords = <String>{};
  _AccountForm _mode = _AccountForm.login;
  Timer? _cooldownTimer;
  bool _wasRecovering = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final recovering = context.watch<AuthProvider>().isRecovering;
    if (recovering && !_wasRecovering) {
      _clearPasswords();
      _formKey = GlobalKey<FormState>();
    }
    _wasRecovering = recovering;
  }

  @override
  void initState() {
    super.initState();
    _email.text = context.read<AuthProvider>().email ?? '';
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.read<AuthProvider>().emailCooldownSeconds > 0) {
        setState(() {});
      } else if (mounted && _lastCooldown > 0) {
        setState(() {});
      }
    });
  }

  int _lastCooldown = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final controller in [
      _name,
      _email,
      _password,
      _confirmation,
      _currentPassword,
      _nonce,
      _code,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _clearPasswords() {
    _password.clear();
    _confirmation.clear();
    _currentPassword.clear();
    _nonce.clear();
    _visiblePasswords.clear();
  }

  void _changeMode(_AccountForm mode) {
    FocusScope.of(context).unfocus();
    context.read<AuthProvider>().clearFeedback();
    setState(() {
      _formKey = GlobalKey<FormState>();
      _enterMode(mode);
    });
  }

  void _enterMode(_AccountForm mode) {
    _clearPasswords();
    _code.clear();
    _mode = mode;
  }

  /// Kodun yazıldığı adımlar: kayıt doğrulaması ve şifre sıfırlama.
  static bool _entersCode(_AccountForm mode) =>
      mode == _AccountForm.verify || mode == _AccountForm.recover;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final mode = _effectiveMode(auth);
    final succeeded = switch (mode) {
      _AccountForm.login => await auth.signInWithEmail(
        _email.text,
        _password.text,
      ),
      _AccountForm.register => await auth.signUp(
        _name.text,
        _email.text,
        _password.text,
      ),
      _AccountForm.forgot => await auth.requestPasswordReset(_email.text),
      _AccountForm.verify => await auth.verifySignupCode(
        _email.text,
        _code.text,
      ),
      _AccountForm.recover => await auth.verifyRecoveryCode(
        _email.text,
        _code.text,
      ),
      _AccountForm.password => await auth.updatePassword(
        _password.text,
        currentPassword: _currentPassword.text,
        nonce: _nonce.text,
      ),
    };
    if (!mounted) return;
    if (!succeeded) {
      // Yanlış kod yeniden yazılacak; hücreler boşalır.
      if (auth.errorMessage == 'code_invalid') setState(_code.clear);
      return;
    }
    if (mode == _AccountForm.login ||
        mode == _AccountForm.register ||
        mode == _AccountForm.password) {
      TextInput.finishAutofillContext();
    }
    setState(() {
      _formKey = GlobalKey<FormState>();
      _enterMode(switch (mode) {
        // Kayıttan sonra oturum yoksa adres kodla doğrulanır.
        _AccountForm.register when !auth.hasAccount => _AccountForm.verify,
        _AccountForm.forgot => _AccountForm.recover,
        // Sıfırlama kodu doğrulanınca yeni şifre formu kendiliğinden gelir.
        _ => _AccountForm.login,
      });
    });
  }

  Future<void> _signOut() async {
    if (await context.read<AuthProvider>().signOut() && mounted) {
      setState(() {
        _clearPasswords();
        _mode = _AccountForm.login;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;
    if (await auth.deleteAccount() && mounted) {
      setState(() {
        _formKey = GlobalKey<FormState>();
        _clearPasswords();
        // Silinen hesabın adı ve adresi giriş formunda hazır beklemesin.
        _name.clear();
        _email.clear();
        _mode = _AccountForm.login;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mode = _effectiveMode(auth);
    // Misafir oturumu hesap değildir: profil yerine giriş formunu görür.
    final overview = auth.hasAccount && mode != _AccountForm.password;
    final entry =
        !overview &&
        (mode == _AccountForm.login || mode == _AccountForm.register);
    final enabled = auth.isAvailable && !auth.isLoading;
    _lastCooldown = auth.emailCooldownSeconds;
    final emailEnabled = enabled && _lastCooldown == 0;
    final reauthenticating =
        !overview &&
        mode == _AccountForm.password &&
        auth.needsReauthentication;
    final reauthenticationFailed =
        auth.errorMessage == 'reauthentication_needed' ||
        auth.errorMessage == 'reauthentication_not_valid';
    // Test ortamında bu sağlayıcılar olmayabilir; uyarı yalnızca kodla
    // katılınmış bir tablo gerçekten varsa gösterilir.
    final joinedAsGuest =
        auth.isAnonymous &&
        ((context.watch<TableProvider?>()?.hasJoinedTables ?? false) ||
            (context.watch<TallyProvider?>()?.hasJoinedTallies ?? false));

    // Üst bant uygulama çubuğunun devamıdır; kart onun üstüne biner.
    final band = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final ink =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;

    final notes = <Widget>[
      if (!auth.isAvailable)
        LedgerNote(loc.onlineServicesUnavailableDescription),
      if (!auth.isAvailable && _developerHint != null)
        LedgerNote(_developerHint!, tone: LedgerNoteTone.error),
      if (auth.errorMessage != null &&
          !(reauthenticating && reauthenticationFailed))
        LedgerNote(
          loc.authError(auth.errorMessage!),
          tone: LedgerNoteTone.error,
        ),
      if (auth.notice != null)
        LedgerNote(
          loc.authText(auth.notice!),
          tone:
              auth.notice == 'password_updated' ||
                  auth.notice == 'account_deleted'
              ? LedgerNoteTone.success
              : LedgerNoteTone.info,
        ),
      if (entry && joinedAsGuest) LedgerNote(loc.authText('guestNotice')),
    ];

    final Widget card;
    if (overview) {
      card = LedgerCard(
        children: [
          ...notes,
          if (auth.hasEmailIdentity)
            _ActionRow(
              key: const ValueKey('action-password'),
              icon: Icons.key_outlined,
              title: loc.authText('changePassword'),
              chevron: true,
              onTap: enabled ? () => _changeMode(_AccountForm.password) : null,
            ),
          _ActionRow(
            key: const ValueKey('action-signOut'),
            icon: Icons.logout_rounded,
            title: loc.authText('signOut'),
            subtitle: loc.authText('signOutHint'),
            onTap: enabled ? _signOut : null,
          ),
        ],
      );
    } else {
      card = AutofillGroup(
        child: Form(
          key: _formKey,
          child: LedgerCard(
            children: [
              if (entry)
                _ModeTabs(
                  register: mode == _AccountForm.register,
                  enabled: enabled,
                  onChanged: (register) => _changeMode(
                    register ? _AccountForm.register : _AccountForm.login,
                  ),
                ),
              ...notes,
              if (mode == _AccountForm.register)
                _field(
                  'name',
                  _name,
                  enabled: enabled,
                  hints: const [AutofillHints.name],
                  validator: (value) =>
                      value?.trim().isNotEmpty == true ? null : 'requiredName',
                ),
              if (mode != _AccountForm.password)
                _field(
                  'email',
                  _email,
                  enabled: enabled && !_entersCode(mode),
                  keyboard: TextInputType.emailAddress,
                  hints: const [AutofillHints.email],
                  hint: loc.authText('emailHint'),
                  last: mode == _AccountForm.forgot,
                  validator: AuthValidation.email,
                ),
              if (mode == _AccountForm.password && !auth.isRecovering)
                _field(
                  'currentPassword',
                  _currentPassword,
                  enabled: enabled,
                  secret: true,
                  hints: const [AutofillHints.password],
                  validator: AuthValidation.password,
                ),
              if (mode == _AccountForm.login ||
                  mode == _AccountForm.register ||
                  mode == _AccountForm.password)
                _field(
                  mode == _AccountForm.password ? 'newPassword' : 'password',
                  _password,
                  enabled: enabled,
                  secret: true,
                  last: mode == _AccountForm.login,
                  hint: mode != _AccountForm.login
                      ? loc.authText('passwordHint')
                      : null,
                  hints: [
                    mode == _AccountForm.login
                        ? AutofillHints.password
                        : AutofillHints.newPassword,
                  ],
                  validator: (value) => AuthValidation.password(
                    value,
                    isNew: mode != _AccountForm.login,
                  ),
                ),
              if (mode == _AccountForm.register ||
                  mode == _AccountForm.password)
                _field(
                  'confirmPassword',
                  _confirmation,
                  rowLabel: 'confirmShort',
                  enabled: enabled,
                  secret: true,
                  last: !reauthenticating,
                  hints: const [AutofillHints.newPassword],
                  validator: (value) =>
                      AuthValidation.confirmation(value, _password.text),
                ),
              if (reauthenticating) ...[
                LedgerNote(
                  loc.authText('reauthenticate'),
                  tone: reauthenticationFailed
                      ? LedgerNoteTone.error
                      : LedgerNoteTone.info,
                  action: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    onPressed: emailEnabled
                        ? auth.sendReauthenticationCode
                        : null,
                    child: Text(loc.authText('sendCode')),
                  ),
                ),
                _field(
                  'code',
                  _nonce,
                  rowLabel: 'codeShort',
                  enabled: enabled,
                  last: true,
                  keyboard: TextInputType.number,
                  hints: const [AutofillHints.oneTimeCode],
                  validator: (value) =>
                      value?.trim().isNotEmpty == true ? null : 'checkFields',
                ),
              ],
            ],
          ),
        ),
      );
    }

    final showsCooldown =
        _lastCooldown > 0 &&
        (mode == _AccountForm.forgot || _entersCode(mode) || reauthenticating);
    final tall = FilledButton.styleFrom(minimumSize: const Size.fromHeight(52));

    final below = <Widget>[
      if (overview) ...[
        const SizedBox(height: 24),
        LedgerCard(
          children: [
            _ActionRow(
              key: const ValueKey('action-delete'),
              icon: Icons.delete_outline_rounded,
              title: loc.authText('deleteAccount'),
              subtitle: loc.authText('deleteHint'),
              destructive: true,
              onTap: enabled ? _deleteAccount : null,
            ),
          ],
        ),
      ] else ...[
        if (mode == _AccountForm.login)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: enabled
                  ? () => _changeMode(_AccountForm.forgot)
                  : null,
              child: Text(loc.authText('forgot')),
            ),
          )
        else if (_entersCode(mode))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: JoinCodeInput(
              fieldKey: const ValueKey('email-code'),
              controller: _code,
              semanticLabel: loc.authText('code'),
              enabled: enabled,
              hasError: auth.errorMessage == 'code_invalid',
              autofillHints: const [AutofillHints.oneTimeCode],
              // Düğme altıncı rakamla açılır.
              onChanged: (_) => setState(() {}),
              onCompleted: (_) => _submit(),
            ),
          )
        else
          const SizedBox(height: 16),
        FilledButton(
          style: tall,
          onPressed:
              (mode == _AccountForm.forgot ? emailEnabled : enabled) &&
                  (!_entersCode(mode) ||
                      _code.text.length == JoinCodeCells.length)
              ? _submit
              : null,
          child: Text(
            loc.authText(switch (mode) {
              _AccountForm.login => 'login',
              _AccountForm.register => 'register',
              _AccountForm.forgot => 'sendReset',
              _AccountForm.verify || _AccountForm.recover => 'verifyCode',
              _AccountForm.password => 'savePassword',
            }),
          ),
        ),
        if (_entersCode(mode))
          TextButton(
            onPressed: emailEnabled
                ? () => mode == _AccountForm.verify
                      ? auth.resendConfirmation(_email.text)
                      : auth.requestPasswordReset(_email.text)
                : null,
            child: Text(loc.authText('resend')),
          ),
        if (showsCooldown)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              loc.authText('wait').replaceAll('{seconds}', '$_lastCooldown'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (mode == _AccountForm.login &&
            auth.errorMessage == 'email_not_confirmed')
          TextButton(
            onPressed: enabled ? () => _changeMode(_AccountForm.verify) : null,
            child: Text(loc.authText('enterCode')),
          ),
        if (entry) ...[
          const SizedBox(height: 20),
          _OrDivider(loc.authText('or')),
          const SizedBox(height: 20),
          // Tek bir düz OutlinedButton: ikonlu kurucu başka bir sınıf üretir.
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: theme.colorScheme.onSurface,
              backgroundColor: theme.colorScheme.surface,
              side: BorderSide(color: theme.dividerColor),
            ),
            onPressed: enabled ? auth.signInWithGoogle : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CustomPaint(painter: _GoogleMark()),
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(loc.authText('google'))),
              ],
            ),
          ),
          if (auth.supportsApple) ...[
            const SizedBox(height: 12),
            AbsorbPointer(
              absorbing: !enabled,
              child: Opacity(
                opacity: enabled ? 1 : .5,
                child: SignInWithAppleButton(
                  onPressed: auth.signInWithApple,
                  text: loc.authText('apple'),
                  height: 52,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  style: theme.brightness == Brightness.dark
                      ? SignInWithAppleButtonStyle.white
                      : SignInWithAppleButtonStyle.black,
                ),
              ),
            ),
          ],
        ] else if (auth.isRecovering)
          TextButton(
            onPressed: enabled ? _signOut : null,
            child: Text(loc.authText('cancelRecovery')),
          )
        else
          TextButton(
            onPressed: enabled ? () => _changeMode(_AccountForm.login) : null,
            child: Text(
              loc.authText(auth.hasAccount ? 'backToAccount' : 'backToLogin'),
            ),
          ),
      ],
    ];

    // Geniş ekranda içerik ortada dar bir sütunda kalır; sütunun içinde
    // her şey sola yaslıdır, kısa bir başlık bile.
    Widget centered(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );

    return PopScope(
      canPop: !auth.isLoading && !auth.isRecovering,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.account),
          automaticallyImplyLeading: !auth.isRecovering,
          // Bant çubuğun devamı; kaydırınca aralarında renk farkı oluşmasın.
          scrolledUnderElevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: auth.isLoading
                ? const LinearProgressIndicator(minHeight: 3)
                : const SizedBox(height: 3),
          ),
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: band,
                  child: centered(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                      child: _header(auth, mode, overview, ink),
                    ),
                  ),
                ),
                Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 26,
                      child: ColoredBox(color: band),
                    ),
                    centered(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AnimatedSize(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: card,
                        ),
                      ),
                    ),
                  ],
                ),
                centered(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: below,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Yalnızca geliştirme derlemesinde: çevrimiçi hizmetin neden kapalı
  /// olduğu. Kullanıcıya giden sürümde bu durum oluşmaz, metin de derlenmez.
  static String? get _developerHint {
    if (!kDebugMode) return null;
    if (!AppConfig.hasSupabaseConfig) {
      return 'Geliştirici notu: uygulama Supabase ayarları olmadan '
          'başlatıldı, bu yüzden düğmeler kapalı. Uygulamayı tamamen durdur '
          've VS Code\'da "Table Note (Supabase)" ile yeniden başlat.';
    }
    final error = SupabaseService.initializationError;
    return error == null
        ? null
        : 'Geliştirici notu: Supabase başlatılamadı: $error';
  }

  _AccountForm _effectiveMode(AuthProvider auth) => auth.isRecovering
      ? _AccountForm.password
      : _mode == _AccountForm.password && !auth.hasAccount
      ? _AccountForm.login
      : _mode;

  Widget _header(
    AuthProvider auth,
    _AccountForm mode,
    bool overview,
    Color ink,
  ) {
    final loc = AppLocalizations.of(context);
    final title = TextStyle(
      color: ink,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.2,
    );
    final body = TextStyle(
      color: ink.withValues(alpha: .78),
      fontSize: 14.5,
      height: 1.45,
    );
    if (overview) {
      final name = auth.displayName?.trim() ?? '';
      final email = auth.email ?? '';
      final primary = name.isNotEmpty
          ? name
          : email.isNotEmpty
          ? email
          : loc.account;
      return Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ink.withValues(alpha: .14),
              border: Border.all(color: ink.withValues(alpha: .28)),
            ),
            child: ExcludeSemantics(
              child: Text(
                _initials(primary, turkish: loc.locale.languageCode == 'tr'),
                style: TextStyle(
                  color: ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: title.copyWith(fontSize: 20),
                ),
                if (name.isNotEmpty && email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    final (heading, help) = switch (mode) {
      _AccountForm.login || _AccountForm.register => (
        'accountPurpose',
        loc.authText('accountOptional'),
      ),
      _AccountForm.forgot => ('resetTitle', loc.authText('resetHelp')),
      _AccountForm.verify => ('verifyTitle', loc.authText('verifyHelp')),
      _AccountForm.recover => ('resetTitle', loc.authText('verifyHelp')),
      _AccountForm.password => (
        'changePassword',
        auth.isRecovering ? loc.authText('recoveryHelp') : auth.email,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(loc.authText(heading), style: title),
        ),
        if (help != null && help.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(help, style: body),
          ),
      ],
    );
  }

  /// Ad soyadın baş harfleri; ad yoksa e-postanın ilk harfi.
  static String _initials(String text, {required bool turkish}) {
    final words = text
        .split(RegExp(r'[\s@._-]+'))
        .where((word) => word.isNotEmpty)
        .take(text.contains('@') ? 1 : 2);
    return words.map((word) {
      final first = String.fromCharCode(word.runes.first);
      // Dart'ın büyük harfe çevirmesi dile bakmaz: "i" → "I".
      if (turkish && first == 'i') return 'İ';
      return first.toUpperCase();
    }).join();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required bool enabled,
    required String? Function(String?) validator,
    String? rowLabel,
    bool secret = false,
    bool last = false,
    TextInputType? keyboard,
    List<String>? hints,
    String? hint,
  }) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visible = _visiblePasswords.contains(label);
    return LedgerField(
      key: ValueKey('row-$label'),
      label: loc.authText(rowLabel ?? label),
      trailing: secret
          ? IconButton(
              tooltip: loc.authText(visible ? 'hidePassword' : 'showPassword'),
              onPressed: enabled
                  ? () => setState(() {
                      visible
                          ? _visiblePasswords.remove(label)
                          : _visiblePasswords.add(label);
                    })
                  : null,
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            )
          : null,
      builder: (focusNode) => Semantics(
        // Etiket sütunundaki kısa yazı ekran okuyucuya gizlidir; alanın
        // adını buradaki tam etiket taşır.
        label: loc.authText(label),
        child: TextFormField(
          key: ValueKey(label),
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: keyboard,
          autofillHints: hints,
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: last ? (_) => _submit() : null,
          textCapitalization: label == 'name'
              ? TextCapitalization.words
              : TextCapitalization.none,
          autocorrect: !secret && keyboard != TextInputType.emailAddress,
          enableSuggestions: !secret,
          obscureText: secret && !visible,
          validator: (value) {
            final error = validator(value);
            return error == null ? null : loc.authText(error);
          },
          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
          decoration: ledgerInputDecoration(context, hint: hint),
        ),
      ),
    );
  }
}

/// Tablonun başlık satırı: giriş ile kayıt arasında geçiş.
class _ModeTabs extends StatelessWidget {
  final bool register;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _ModeTabs({
    required this.register,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget tab(
      String key,
      String label,
      bool selected,
      bool target,
    ) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          // Seçili olmayan sekme sayfanın rengini alır, geride durur.
          color: selected ? Colors.transparent : theme.scaffoldBackgroundColor,
          child: InkWell(
            key: ValueKey(key),
            onTap: enabled && !selected ? () => onChanged(target) : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2,
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tab('mode-login', loc.authText('login'), !register, false),
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          tab('mode-register', loc.authText('register'), register, true),
        ],
      ),
    );
  }
}

/// Hesap özetindeki dokunulabilir satır.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final bool chevron;
  const _ActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.destructive = false,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final danger = AppTheme.readableAccent(context, theme.colorScheme.error);
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .5 : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: destructive ? danger : muted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: destructive
                                ? danger
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (chevron) Icon(Icons.chevron_right_rounded, color: muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final String label;
  const _OrDivider(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = Expanded(
      child: Divider(height: 1, thickness: 1, color: theme.dividerColor),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Google'ın dört renkli "G" işareti, kendi 18×18 çiziminden.
class _GoogleMark extends CustomPainter {
  const _GoogleMark();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 18, size.height / 18);
    final paint = Paint()..isAntiAlias = true;

    canvas.drawPath(
      Path()
        ..moveTo(17.64, 9.2)
        ..relativeCubicTo(0, -.637, -.057, -1.251, -.164, -1.84)
        ..lineTo(9, 7.36)
        ..relativeLineTo(0, 3.481)
        ..relativeLineTo(4.844, 0)
        ..relativeCubicTo(-.209, 1.125, -.843, 2.078, -1.796, 2.716)
        ..relativeLineTo(0, 2.259)
        ..relativeLineTo(2.908, 0)
        ..relativeCubicTo(1.702, -1.567, 2.684, -3.875, 2.684, -6.615)
        ..close(),
      paint..color = const Color(0xFF4285F4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(9, 18)
        ..relativeCubicTo(2.43, 0, 4.467, -.806, 5.956, -2.18)
        ..relativeLineTo(-2.908, -2.259)
        ..relativeCubicTo(-.806, .54, -1.837, .86, -3.048, .86)
        ..relativeCubicTo(-2.344, 0, -4.328, -1.584, -5.036, -3.711)
        ..lineTo(.957, 10.71)
        ..relativeLineTo(0, 2.332)
        ..arcToPoint(
          const Offset(9, 18),
          radius: const Radius.circular(8.997),
          clockwise: false,
        )
        ..close(),
      paint..color = const Color(0xFF34A853),
    );
    canvas.drawPath(
      Path()
        ..moveTo(3.964, 10.71)
        ..arcToPoint(
          const Offset(3.682, 9),
          radius: const Radius.circular(5.41),
        )
        ..relativeCubicTo(0, -.593, .102, -1.17, .282, -1.71)
        ..lineTo(3.964, 4.958)
        ..lineTo(.957, 4.958)
        ..arcToPoint(
          const Offset(0, 9),
          radius: const Radius.circular(8.996),
          clockwise: false,
        )
        ..relativeCubicTo(0, 1.452, .348, 2.827, .957, 4.042)
        ..relativeLineTo(3.007, -2.332)
        ..close(),
      paint..color = const Color(0xFFFBBC05),
    );
    canvas.drawPath(
      Path()
        ..moveTo(9, 3.58)
        ..relativeCubicTo(1.321, 0, 2.508, .454, 3.44, 1.345)
        ..relativeLineTo(2.582, -2.58)
        ..cubicTo(13.463, .891, 11.426, 0, 9, 0)
        ..arcToPoint(
          const Offset(.957, 4.958),
          radius: const Radius.circular(8.997),
          clockwise: false,
        )
        ..lineTo(3.964, 7.29)
        ..cubicTo(4.672, 5.163, 6.656, 3.58, 9, 3.58)
        ..close(),
      paint..color = const Color(0xFFEA4335),
    );
  }

  @override
  bool shouldRepaint(_GoogleMark oldDelegate) => false;
}

/// Geri alınamayan silme için son onay: neyin gideceği yazar ve onay
/// sözcüğü elle yazılmadan düğme açılmaz.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  // Denetleyici diyaloğa aittir; çağıran taraf tutsaydı diyalog kapanırken
  // hâlâ çizilen alanın altından çekilirdi.
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final word = loc.authText('deleteConfirmWord');
    final store = defaultTargetPlatform == TargetPlatform.iOS
        ? 'App Store'
        : 'Google Play';

    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );

    return AlertDialog(
      scrollable: true,
      title: Text(loc.authText('deleteTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          point(Icons.cloud_off_outlined, loc.authText('deleteCloud')),
          point(Icons.smartphone_outlined, loc.authText('deleteLocal')),
          point(
            Icons.receipt_long_outlined,
            loc.authText('deleteSubscription').replaceAll('{store}', store),
          ),
          const SizedBox(height: 4),
          TextField(
            key: const ValueKey('deleteConfirmation'),
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              final matches = AuthValidation.matchesConfirmWord(value, word);
              if (matches != _matches) setState(() => _matches = matches);
            },
            decoration: InputDecoration(
              labelText: loc
                  .authText('deleteConfirmLabel')
                  .replaceAll('{word}', word),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(loc.cancel),
        ),
        FilledButton(
          key: const ValueKey('deleteConfirm'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.readableAccent(
              context,
              theme.colorScheme.error,
            ),
            foregroundColor: dark ? const Color(0xFF2B0B0B) : Colors.white,
          ),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: Text(loc.authText('deleteConfirm')),
        ),
      ],
    );
  }
}
