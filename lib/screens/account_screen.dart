import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../l10n/app_localizations.dart';
import '../l10n/auth_localizations.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_validation.dart';

enum _AccountForm { login, register, forgot, verify, password }

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
      _clearPasswords();
      _mode = mode;
    });
  }

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
      _AccountForm.verify => await auth.resendConfirmation(_email.text),
      _AccountForm.password => await auth.updatePassword(
        _password.text,
        currentPassword: _currentPassword.text,
        nonce: _nonce.text,
      ),
    };
    if (!mounted || !succeeded) return;
    if (mode == _AccountForm.login ||
        mode == _AccountForm.register ||
        mode == _AccountForm.password) {
      TextInput.finishAutofillContext();
      setState(() {
        _formKey = GlobalKey<FormState>();
        _clearPasswords();
        _mode = mode == _AccountForm.register && !auth.isSignedIn
            ? _AccountForm.verify
            : _AccountForm.login;
      });
    }
  }

  Future<void> _signOut() async {
    if (await context.read<AuthProvider>().signOut() && mounted) {
      setState(() {
        _clearPasswords();
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
    final overview = auth.isSignedIn && mode != _AccountForm.password;
    final enabled = auth.isAvailable && !auth.isLoading;
    _lastCooldown = auth.emailCooldownSeconds;
    final emailEnabled = enabled && _lastCooldown == 0;
    final title = overview
        ? loc.account
        : loc.authText(switch (mode) {
            _AccountForm.login => 'login',
            _AccountForm.register => 'register',
            _AccountForm.forgot => 'resetTitle',
            _AccountForm.verify => 'verifyTitle',
            _AccountForm.password => 'changePassword',
          });

    Widget feedback(String message, {bool error = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: error
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: error
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !auth.isLoading && !auth.isRecovering,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          automaticallyImplyLeading: !auth.isRecovering,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (auth.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: LinearProgressIndicator(),
                    ),
                  if (!auth.isAvailable)
                    feedback(loc.onlineServicesUnavailableDescription),
                  if (auth.errorMessage != null)
                    feedback(loc.authError(auth.errorMessage!), error: true),
                  if (auth.notice != null) feedback(loc.authText(auth.notice!)),
                  if (overview) ...[
                    const CircleAvatar(
                      radius: 36,
                      child: Icon(Icons.person_outline, size: 36),
                    ),
                    const SizedBox(height: 16),
                    if (auth.displayName?.isNotEmpty == true)
                      Text(
                        auth.displayName!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      auth.email ?? loc.account,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (auth.hasEmailIdentity)
                      OutlinedButton(
                        onPressed: enabled
                            ? () => _changeMode(_AccountForm.password)
                            : null,
                        child: Text(loc.authText('changePassword')),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: enabled ? _signOut : null,
                      icon: const Icon(Icons.logout),
                      label: Text(loc.authText('signOut')),
                    ),
                  ] else ...[
                    if (mode == _AccountForm.login ||
                        mode == _AccountForm.register) ...[
                      Text(
                        loc.authText('offlineHelp'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (mode == _AccountForm.forgot ||
                        mode == _AccountForm.verify ||
                        auth.isRecovering) ...[
                      Text(
                        loc.authText(
                          auth.isRecovering
                              ? 'recoveryHelp'
                              : mode == _AccountForm.verify
                              ? 'verifyHelp'
                              : 'resetHelp',
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (mode == _AccountForm.register)
                              _field(
                                'name',
                                _name,
                                enabled: enabled,
                                hints: const [AutofillHints.name],
                                validator: (value) =>
                                    value?.trim().isNotEmpty == true
                                    ? null
                                    : 'requiredName',
                              ),
                            if (mode != _AccountForm.password)
                              _field(
                                'email',
                                _email,
                                enabled: enabled && mode != _AccountForm.verify,
                                keyboard: TextInputType.emailAddress,
                                hints: const [AutofillHints.email],
                                validator: AuthValidation.email,
                              ),
                            if (mode == _AccountForm.password &&
                                !auth.isRecovering)
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
                                mode == _AccountForm.password
                                    ? 'newPassword'
                                    : 'password',
                                _password,
                                enabled: enabled,
                                secret: true,
                                helper: mode != _AccountForm.login
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
                                enabled: enabled,
                                secret: true,
                                hints: const [AutofillHints.newPassword],
                                validator: (value) =>
                                    AuthValidation.confirmation(
                                      value,
                                      _password.text,
                                    ),
                              ),
                            if (mode == _AccountForm.password &&
                                auth.needsReauthentication) ...[
                              Text(loc.authText('reauthenticate')),
                              TextButton(
                                onPressed: emailEnabled
                                    ? auth.sendReauthenticationCode
                                    : null,
                                child: Text(loc.authText('sendCode')),
                              ),
                              _field(
                                'code',
                                _nonce,
                                enabled: enabled,
                                keyboard: TextInputType.number,
                                hints: const [AutofillHints.oneTimeCode],
                                validator: (value) =>
                                    value?.trim().isNotEmpty == true
                                    ? null
                                    : 'checkFields',
                              ),
                            ],
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed:
                                  (mode == _AccountForm.forgot ||
                                          mode == _AccountForm.verify
                                      ? emailEnabled
                                      : enabled)
                                  ? _submit
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  loc.authText(switch (mode) {
                                    _AccountForm.login => 'login',
                                    _AccountForm.register => 'register',
                                    _AccountForm.forgot => 'sendReset',
                                    _AccountForm.verify => 'resend',
                                    _AccountForm.password => 'savePassword',
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_lastCooldown > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${loc.authText('wait')} $_lastCooldown s',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (mode == _AccountForm.login) ...[
                      TextButton(
                        onPressed: enabled
                            ? () => _changeMode(_AccountForm.forgot)
                            : null,
                        child: Text(loc.authText('forgot')),
                      ),
                      if (auth.errorMessage == 'email_not_confirmed')
                        TextButton(
                          onPressed: enabled
                              ? () => _changeMode(_AccountForm.verify)
                              : null,
                          child: Text(loc.authText('resend')),
                        ),
                    ],
                    if (mode == _AccountForm.login ||
                        mode == _AccountForm.register) ...[
                      TextButton(
                        onPressed: enabled
                            ? () => _changeMode(
                                mode == _AccountForm.login
                                    ? _AccountForm.register
                                    : _AccountForm.login,
                              )
                            : null,
                        child: Text(
                          loc.authText(
                            mode == _AccountForm.login
                                ? 'register'
                                : 'backToLogin',
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          loc.authText('or'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: enabled ? auth.signInWithGoogle : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(loc.authText('google')),
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
                        onPressed: enabled
                            ? () => _changeMode(_AccountForm.login)
                            : null,
                        child: Text(
                          auth.isSignedIn
                              ? loc.account
                              : loc.authText('backToLogin'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _AccountForm _effectiveMode(AuthProvider auth) => auth.isRecovering
      ? _AccountForm.password
      : _mode == _AccountForm.password && !auth.isSignedIn
      ? _AccountForm.login
      : _mode;

  Widget _field(
    String label,
    TextEditingController controller, {
    required bool enabled,
    required String? Function(String?) validator,
    bool secret = false,
    TextInputType? keyboard,
    List<String>? hints,
    String? helper,
  }) {
    final loc = AppLocalizations.of(context);
    final visible = _visiblePasswords.contains(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey(label),
        controller: controller,
        enabled: enabled,
        keyboardType: keyboard,
        autofillHints: hints,
        textInputAction: TextInputAction.next,
        autocorrect: !secret && keyboard != TextInputType.emailAddress,
        enableSuggestions: !secret,
        obscureText: secret && !visible,
        validator: (value) {
          final error = validator(value);
          return error == null ? null : loc.authText(error);
        },
        decoration: InputDecoration(
          labelText: loc.authText(label),
          helperText: helper,
          border: const OutlineInputBorder(),
          errorMaxLines: 3,
          suffixIcon: secret
              ? IconButton(
                  tooltip: loc.authText(
                    visible ? 'hidePassword' : 'showPassword',
                  ),
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
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
