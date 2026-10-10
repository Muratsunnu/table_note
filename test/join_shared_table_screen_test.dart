import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/providers/auth_provider.dart';
import 'package:table_note/screens/join_shared_table_screen.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/widgets/join_code_cells.dart';

class _FakeAuth extends AuthProvider {
  @override
  Future<bool> ensureAnonymousSession() async => true;
}

class _FakeRepository implements CloudRepository {
  static const realCode = '463404';
  String? password;
  final asked = <String>[];

  @override
  Future<SharedTablePeek> peekSharedTable({
    required String code,
    String? password,
  }) async {
    asked.add(code);
    if (code != realCode) {
      throw const SharedTableException('invalid_table_code');
    }
    if (this.password != null &&
        password != null &&
        password != this.password) {
      throw const SharedTableException('invalid_table_password');
    }
    return SharedTablePeek(
      tableName: 'seferler',
      kind: 'table',
      requiresPassword: this.password != null,
      passwordOk: password == this.password,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _en = AppLocalizations(const Locale('en'));

Widget _app(_FakeAuth auth, _FakeRepository repository) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: JoinSharedTableScreen(repository: repository),
      ),
    );

void main() {
  group('JoinCodeFormatter', () {
    test('typing keeps digits only and stops at six', () {
      expect(JoinCodeFormatter.extract('46 34'), '4634');
      expect(JoinCodeFormatter.extract('4634041'), '463404');
      expect(JoinCodeFormatter.extract('abc'), '');
    });

    test('a pasted message yields its code, not digits from the name', () {
      // Kod çoğunlukla "Kodu gönder" ile gelen mesajın içinden yapıştırılır.
      // Tablonun adındaki rakam koda karışmamalı.
      expect(
        JoinCodeFormatter.extract(
          'Table Note’ta “test2” paylaşımına katıl.\nKatılım kodu: 463404',
        ),
        '463404',
      );
      expect(JoinCodeFormatter.extract('kod 2024 değil, 000123'), '000123');
    });
  });

  testWidgets('the sixth digit checks the code and moves on by itself', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _FakeAuth();
    final repository = _FakeRepository();
    addTearDown(auth.dispose);
    await tester.pumpWidget(_app(auth, repository));
    await tester.pumpAndSettle();

    final submit = find.byKey(const ValueKey('join-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('join-code')), '46340');
    await tester.pump();
    // Beş rakam henüz kod değil: ne sorulur ne de düğme açılır.
    expect(repository.asked, isEmpty);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('join-code')), '463404');
    await tester.pumpAndSettle();
    expect(repository.asked, ['463404']);
    // Şifresiz tabloda doğrudan ad adımı; hangi tabloya girildiği yazıyor.
    expect(find.text('seferler'), findsOneWidget);
    expect(find.byKey(const ValueKey('join-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('join-password')), findsNothing);
  });

  testWidgets('a wrong code stays put, and editing it clears the error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _FakeAuth();
    final repository = _FakeRepository();
    addTearDown(auth.dispose);
    await tester.pumpWidget(_app(auth, repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('join-code')), '111111');
    await tester.pumpAndSettle();
    final error = find.text(_en.sharedTableError('invalid_table_code'));
    expect(error, findsOneWidget);
    expect(find.byKey(const ValueKey('join-code')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('join-code')), '11111');
    await tester.pump();
    expect(error, findsNothing);
  });

  testWidgets('a protected table asks for its password before the name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _FakeAuth();
    final repository = _FakeRepository()..password = '2468';
    addTearDown(auth.dispose);
    await tester.pumpWidget(_app(auth, repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('join-code')), '463404');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('join-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('join-name')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('join-password')), '0000');
    await tester.tap(find.byKey(const ValueKey('join-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text(_en.sharedTableError('invalid_table_password')),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const ValueKey('join-password')), '2468');
    await tester.tap(find.byKey(const ValueKey('join-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('join-name')), findsOneWidget);
  });
}
