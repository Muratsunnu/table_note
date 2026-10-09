import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/l10n/auth_localizations.dart';
import 'package:table_note/providers/auth_provider.dart';
import 'package:table_note/screens/account_screen.dart';
import 'package:table_note/widgets/auth_callback_router.dart';

class _FakeAuth extends AuthProvider {
  bool recovering = false;
  bool busy = false;
  bool signedIn = false;
  bool guest = false;
  int registrations = 0;
  int deletions = 0;
  String? registeredEmail;
  String? registeredPassword;
  String? note;
  String? failure;
  bool confirmed = false;
  final signIns = <String>[];
  @override
  bool get isAvailable => true;
  @override
  String? get errorMessage => failure;
  @override
  void clearFeedback() {
    failure = null;
    note = null;
    notifyListeners();
  }

  @override
  Future<bool> signInWithEmail(String email, String password) async {
    signIns.add(password);
    failure = confirmed ? null : 'email_not_confirmed';
    signedIn = confirmed;
    notifyListeners();
    return confirmed;
  }

  @override
  bool get isSignedIn => recovering || signedIn || guest;
  @override
  bool get isAnonymous => guest;
  @override
  String? get notice => note;
  @override
  Future<bool> deleteAccount() async {
    deletions++;
    signedIn = false;
    note = 'account_deleted';
    notifyListeners();
    return true;
  }

  @override
  bool get isRecovering => recovering;
  @override
  bool get isLoading => busy;
  @override
  Future<bool> signUp(String name, String email, String password) async {
    registrations++;
    registeredEmail = email;
    registeredPassword = password;
    return true;
  }

  /// E-postayla gelen kod; testler doğrusunu ve yanlışını yazar.
  static const validCode = '123456';
  final checkedCodes = <String>[];
  final sentTo = <String>[];
  bool recoveringInPlace = false;
  String? savedPassword;

  bool _check(String code) {
    checkedCodes.add(code);
    final valid = code == validCode;
    failure = valid ? null : 'code_invalid';
    return valid;
  }

  @override
  Future<bool> verifySignupCode(String email, String code) async {
    signedIn = _check(code);
    notifyListeners();
    return signedIn;
  }

  @override
  Future<bool> verifyRecoveryCode(String email, String code) async {
    recovering = recoveringInPlace = _check(code);
    notifyListeners();
    return recovering;
  }

  @override
  bool get recoveryNeedsScreen => recovering && !recoveringInPlace;

  @override
  Future<bool> requestPasswordReset(String email) async {
    sentTo.add(email);
    note = 'recovery_sent';
    notifyListeners();
    return true;
  }

  @override
  Future<bool> resendConfirmation(String email) async {
    sentTo.add(email);
    note = 'confirmation_sent';
    notifyListeners();
    return true;
  }

  @override
  Future<bool> updatePassword(
    String password, {
    String? currentPassword,
    String? nonce,
  }) async {
    savedPassword = password;
    recovering = recoveringInPlace = false;
    signedIn = true;
    note = 'password_updated';
    notifyListeners();
    return true;
  }

  void recover() {
    recovering = true;
    notifyListeners();
  }
}

Widget _app(
  _FakeAuth auth, {
  Locale locale = const Locale('en'),
  Widget? home,
  GlobalKey<NavigatorState>? navigatorKey,
}) => ChangeNotifierProvider<AuthProvider>.value(
  value: auth,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    locale: locale,
    supportedLocales: const [Locale('tr'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: navigatorKey == null
        ? null
        : (_, child) =>
              AuthCallbackRouter(navigatorKey: navigatorKey, child: child!),
    home: home ?? const AccountScreen(),
  ),
);

void main() {
  testWidgets('Apple button is shown only on iOS', (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    expect(find.byType(SignInWithAppleButton), findsNothing);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    expect(find.byType(SignInWithAppleButton), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    // The framework checks the foundation debug vars when the body returns,
    // before addTearDown runs, so the override has to be cleared here too.
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'signup keeps email when moving to confirmation and preserves password bytes',
    (tester) async {
      final auth = _FakeAuth();
      addTearDown(auth.dispose);
      final en = AppLocalizations(const Locale('en'));
      await tester.pumpWidget(_app(auth));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mode-register')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('name')), 'Test User');
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        ' secret ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirmPassword')),
        ' secret ',
      );
      final submit = find.widgetWithText(FilledButton, en.authText('register'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(auth.registrations, 1);
      expect(auth.registeredPassword, ' secret ');
      final email = tester.widget<TextFormField>(
        find.byKey(const ValueKey('email')),
      );
      expect(email.controller!.text, 'test@example.com');
      expect(find.text(en.authText('verifyTitle')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'locale change retains focused input without disposed focus errors',
    (tester) async {
      final auth = _FakeAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(_app(auth, locale: const Locale('tr')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'test@example.com',
      );
      await tester.pumpWidget(_app(auth));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('email')))
            .controller!
            .text,
        'test@example.com',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'recovery link opens reset form over another screen without current password',
    (tester) async {
      final auth = _FakeAuth();
      addTearDown(auth.dispose);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _app(
          auth,
          navigatorKey: key,
          home: const Scaffold(body: Text('Table')),
        ),
      );
      await tester.pumpAndSettle();
      auth.recover();
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('newPassword')), findsOneWidget);
      expect(find.byKey(const ValueKey('currentPassword')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('in-flight operation disables submission and social login', (
    tester,
  ) async {
    final auth = _FakeAuth()..busy = true;
    addTearDown(auth.dispose);
    await tester.pumpWidget(_app(auth));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> register(WidgetTester tester, AppLocalizations en) async {
    await tester.tap(find.byKey(const ValueKey('mode-register')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('name')), 'Test User');
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'test@example.com',
    );
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret1');
    await tester.enterText(
      find.byKey(const ValueKey('confirmPassword')),
      'secret1',
    );
    final submit = find.widgetWithText(FilledButton, en.authText('register'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'after signup the emailed code verifies the address and signs in',
    (tester) async {
      // Kod, e-posta hangi cihazda okunursa okunsun çalışır; bağlantı yalnızca
      // uygulamanın kurulu olduğu telefonda açılabiliyordu.
      final auth = _FakeAuth();
      addTearDown(auth.dispose);
      final en = AppLocalizations(const Locale('en'));
      await tester.pumpWidget(_app(auth));
      await tester.pumpAndSettle();
      await register(tester, en);

      final code = find.byKey(const ValueKey('email-code'));
      final verify = find.widgetWithText(
        FilledButton,
        en.authText('verifyCode'),
      );
      expect(code, findsOneWidget);
      // Altı rakam yazılmadan düğme kapalıdır.
      await tester.enterText(code, '12345');
      await tester.pump();
      expect(tester.widget<FilledButton>(verify).onPressed, isNull);
      expect(auth.checkedCodes, isEmpty);

      // Yanlış kod: nedenini söyler, hücreler boşalır, ekran yerinde kalır.
      await tester.enterText(code, '654321');
      await tester.pumpAndSettle();
      expect(auth.checkedCodes, ['654321']);
      expect(find.text(en.authText('codeInvalid')), findsOneWidget);
      expect(tester.widget<TextField>(code).controller!.text, isEmpty);
      expect(find.text(en.authText('verifyTitle')), findsOneWidget);

      // Doğru kod altıncı rakamla kendiliğinden gönderilir.
      await tester.enterText(code, _FakeAuth.validCode);
      await tester.pumpAndSettle();
      expect(auth.checkedCodes, ['654321', _FakeAuth.validCode]);
      expect(find.byKey(const ValueKey('action-signOut')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the code can be pasted with the rest of the email', (
    tester,
  ) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final en = AppLocalizations(const Locale('en'));
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await register(tester, en);

    await tester.enterText(
      find.byKey(const ValueKey('email-code')),
      'Table Note code: ${_FakeAuth.validCode}',
    );
    await tester.pumpAndSettle();
    expect(auth.checkedCodes, [_FakeAuth.validCode]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unverified address can ask for a new code from sign-in', (
    tester,
  ) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final en = AppLocalizations(const Locale('en'));
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'test@example.com',
    );
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, en.authText('login')));
    await tester.pumpAndSettle();
    expect(find.text(en.authText('unconfirmed')), findsOneWidget);

    await tester.tap(find.text(en.authText('enterCode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('email-code')), findsOneWidget);
    // Eski kod hâlâ geçerli olabilir; yenisi yalnızca istenince gönderilir.
    expect(auth.sentTo, isEmpty);
    await tester.tap(find.text(en.authText('resend')));
    await tester.pumpAndSettle();
    expect(auth.sentTo, ['test@example.com']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('forgotten password is reset with an emailed code', (
    tester,
  ) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final en = AppLocalizations(const Locale('en'));
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(auth, navigatorKey: key));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.authText('forgot')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'test@example.com',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, en.authText('sendReset')),
    );
    await tester.pumpAndSettle();
    expect(auth.sentTo, ['test@example.com']);
    // Adresin kayıtlı olup olmadığı söylenmez.
    expect(find.text(en.authText('recovery_sent')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('email-code')),
      _FakeAuth.validCode,
    );
    await tester.pumpAndSettle();
    // Yeni şifre aynı ekranda sorulur; üstüne ikinci bir hesap ekranı açılmaz.
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('newPassword')), findsOneWidget);
    expect(find.byKey(const ValueKey('currentPassword')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('newPassword')),
      'secret2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirmPassword')),
      'secret2',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, en.authText('savePassword')),
    );
    await tester.pumpAndSettle();
    expect(auth.savedPassword, 'secret2');
    expect(find.byKey(const ValueKey('action-signOut')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // Hesap ekranını bir iş için açan düğme; dönen sonucu saklar.
  Widget opener(void Function(bool?) onResult, {bool closeOnSignIn = true}) =>
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => onResult(
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountScreen(closeOnSignIn: closeOnSignIn),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

  Future<void> signIn(WidgetTester tester, AppLocalizations en) async {
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'test@example.com',
    );
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, en.authText('login')));
    await tester.pumpAndSettle();
  }

  testWidgets('opened for a task, it closes itself once signed in', (
    tester,
  ) async {
    // Satın alma ya da paylaşım için gelen kişi girişten sonra profil
    // sayfasında bırakılmaz; yarım kalan işine döner.
    final auth = _FakeAuth()..confirmed = true;
    addTearDown(auth.dispose);
    final en = AppLocalizations(const Locale('en'));
    final results = <bool?>[];
    await tester.pumpWidget(_app(auth, home: opener(results.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await signIn(tester, en);

    expect(find.byType(AccountScreen), findsNothing);
    expect(results, [true]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed sign-in keeps it open', (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final en = AppLocalizations(const Locale('en'));
    final results = <bool?>[];
    await tester.pumpWidget(_app(auth, home: opener(results.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await signIn(tester, en);

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(results, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opened from settings, it stays on the profile', (tester) async {
    final auth = _FakeAuth()..confirmed = true;
    addTearDown(auth.dispose);
    final en = AppLocalizations(const Locale('en'));
    final results = <bool?>[];
    await tester.pumpWidget(
      _app(auth, home: opener(results.add, closeOnSignIn: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await signIn(tester, en);

    expect(find.byKey(const ValueKey('action-signOut')), findsOneWidget);
    expect(results, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('during a password reset it waits for the new password', (
    tester,
  ) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final en = AppLocalizations(const Locale('en'));
    final results = <bool?>[];
    await tester.pumpWidget(_app(auth, home: opener(results.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.authText('forgot')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'test@example.com',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, en.authText('sendReset')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('email-code')),
      _FakeAuth.validCode,
    );
    await tester.pumpAndSettle();

    // Kod doğrulandı, oturum açıldı; ama yeni şifre henüz kaydedilmedi.
    expect(find.byKey(const ValueKey('newPassword')), findsOneWidget);
    expect(results, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('newPassword')),
      'secret2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirmPassword')),
      'secret2',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, en.authText('savePassword')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsNothing);
    expect(results, [true]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('guest session gets the sign-in form, not a profile', (
    tester,
  ) async {
    // Kodla katılan kişinin sessiz oturumu hesap değildir. Profil ve çıkış
    // düğmesi gösterilseydi, basan kişi katıldığı tablolara erişimini
    // geri getiremeyecek şekilde kaybederdi.
    final auth = _FakeAuth()..guest = true;
    addTearDown(auth.dispose);
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('email')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-signOut')), findsNothing);
    expect(find.byKey(const ValueKey('action-delete')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('account deletion stays locked until the confirm word is typed', (
    tester,
  ) async {
    final auth = _FakeAuth()..signedIn = true;
    addTearDown(auth.dispose);
    final en = AppLocalizations(const Locale('en'));
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action-delete')));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const ValueKey('deleteConfirm'));
    final field = find.byKey(const ValueKey('deleteConfirmation'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(field, 'delet');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(field, 'delete');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(auth.deletions, 1);
    // Hesap gitti: profil yerine giriş formu ve ne olduğunu söyleyen not.
    expect(find.byKey(const ValueKey('email')), findsOneWidget);
    expect(find.text(en.authText('account_deleted')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('backing out of the delete dialog deletes nothing', (
    tester,
  ) async {
    final auth = _FakeAuth()..signedIn = true;
    addTearDown(auth.dispose);
    final en = AppLocalizations(const Locale('en'));
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, en.cancel));
    await tester.pumpAndSettle();
    expect(auth.deletions, 0);
    expect(find.byKey(const ValueKey('action-delete')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
