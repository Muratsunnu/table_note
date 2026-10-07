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

  testWidgets(
    'after signup the user continues without the email link opening the app',
    (tester) async {
      // Bağlantı uygulamayı yalnızca bu cihazda açabilir. E-postasını
      // bilgisayarında açan kişi için tek yol buradaki düğmedir; şifresini
      // yeniden yazması da gerekmemeli.
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
      await tester.enterText(find.byKey(const ValueKey('password')), 'secret1');
      await tester.enterText(
        find.byKey(const ValueKey('confirmPassword')),
        'secret1',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, en.authText('register')),
      );
      await tester.pumpAndSettle();

      final proceed = find.widgetWithText(
        FilledButton,
        en.authText('verifiedContinue'),
      );
      // Henüz doğrulanmadı: ekran yerinde kalır ve nedenini söyler.
      await tester.tap(proceed);
      await tester.pumpAndSettle();
      expect(auth.signIns, ['secret1']);
      expect(find.text(en.authText('unconfirmed')), findsOneWidget);
      expect(find.text(en.authText('verifyTitle')), findsOneWidget);

      auth.confirmed = true;
      await tester.tap(proceed);
      await tester.pumpAndSettle();
      expect(auth.signIns, ['secret1', 'secret1']);
      expect(find.byKey(const ValueKey('action-signOut')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
