import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/l10n/auth_localizations.dart';
import 'package:table_note/models/plan_offer.dart';
import 'package:table_note/providers/auth_provider.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/screens/account_screen.dart';
import 'package:table_note/screens/premium_screen.dart';
import 'package:table_note/screens/premium_welcome_screen.dart';

class _FakeSubscription extends ChangeNotifier implements SubscriptionProvider {
  List<PlanOffer> offers = const [];
  final bought = <PlanPeriod>[];
  int reloads = 0;

  bool premium = false;
  bool needsSignIn = false;
  // Girilen hesabın aboneliği zaten varsa girişten sonra Premium çıkar.
  bool premiumAccount = false;
  int refreshes = 0;
  bool verifying = false;
  bool pending = false;
  bool completed = false;
  DateTime? until;

  @override
  bool get isVerifying => verifying;
  @override
  bool get hasPendingPurchase => pending;
  @override
  DateTime? get validUntil => until;
  @override
  bool takePurchaseCompleted() {
    final value = completed;
    completed = false;
    return value;
  }

  /// Mağaza ödemeyi aldı ve sunucu doğruladı.
  void finishPurchase() {
    verifying = false;
    premium = true;
    completed = true;
    until = DateTime(2026, 10, 17);
    notifyListeners();
  }

  @override
  bool get isPremium => premium;
  @override
  bool get isLoading => false;
  @override
  bool get requiresSignIn => needsSignIn;
  @override
  Future<void> refreshEntitlement({bool notify = true}) async {
    refreshes++;
    premium = premiumAccount;
    notifyListeners();
  }

  @override
  bool get showsSamplePlans => false;
  @override
  String? get errorMessage => null;
  @override
  List<PlanOffer> get plans => offers;
  @override
  PlanOffer? plan(PlanPeriod period) =>
      offers.where((offer) => offer.period == period).firstOrNull;
  @override
  Future<bool> startPurchase(PlanOffer plan) async {
    bought.add(plan.period);
    return true;
  }

  @override
  Future<void> reloadPlans() async => reloads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Giriş ekranını gerçekten geçebilmek için: her giriş başarılıdır.
class _FakeAuth extends AuthProvider {
  bool signedIn = false;
  @override
  bool get isAvailable => true;
  @override
  bool get isSignedIn => signedIn;
  @override
  bool get isAnonymous => false;
  @override
  Future<bool> signInWithEmail(String email, String password) async {
    signedIn = true;
    notifyListeners();
    return true;
  }
}

PlanOffer _offer(PlanPeriod period, String price, double raw, {int? trial}) =>
    PlanOffer(
      period: period,
      product: ProductDetails(
        id: period.name,
        title: period.name,
        description: '',
        price: price,
        rawPrice: raw,
        currencyCode: 'TRY',
      ),
      price: price,
      rawPrice: raw,
      trialDays: trial,
    );

final _en = AppLocalizations(const Locale('en'));

void main() {
  late _FakeSubscription subscription;

  Future<void> open(
    WidgetTester tester, {
    _FakeAuth? auth,
    // Doğrulama sürerken düğmedeki halka hiç durmaz; ekran "yerleşmez".
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(subscription.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: subscription,
          ),
          if (auth != null)
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const PremiumScreen(),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('prices, trial and saving all come from the store', (
    tester,
  ) async {
    subscription = _FakeSubscription()
      ..offers = [
        _offer(PlanPeriod.yearly, '₺249,99', 249.99, trial: 14),
        _offer(PlanPeriod.monthly, '₺39,99', 39.99),
      ];
    await open(tester);

    // Mağaza ne dediyse o: uygulamada yazılı bir fiyat ya da süre yok.
    expect(find.text('₺249,99 / ${_en.perYear}'), findsOneWidget);
    expect(find.text('₺39,99 / ${_en.perMonth}'), findsOneWidget);
    expect(find.text(_en.trialBadge(14)), findsOneWidget);
    expect(find.text(_en.savingBadge(48)), findsOneWidget);
    expect(find.text(_en.startTrial(14)), findsOneWidget);
    // Ne zaman, ne kadar ücretleneceği düğmeden önce açıkça yazar.
    expect(find.text(_en.trialTodayText), findsOneWidget);
    expect(find.text(_en.trialChargeLabel(14)), findsOneWidget);
    expect(
      find.text(_en.trialChargeText('₺249,99', _en.perYear)),
      findsOneWidget,
    );
    expect(find.text(_en.trialCancelText('Google Play')), findsOneWidget);
    expect(find.text(_en.premiumKeepsData), findsOneWidget);
  });

  testWidgets('the monthly plan promises no trial it does not have', (
    tester,
  ) async {
    subscription = _FakeSubscription()
      ..offers = [
        _offer(PlanPeriod.yearly, '₺199,99', 199.99, trial: 7),
        _offer(PlanPeriod.monthly, '₺29,99', 29.99),
      ];
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('plan-monthly')));
    await tester.pumpAndSettle();
    expect(find.text(_en.subscribeNow), findsOneWidget);
    expect(
      find.text(_en.renewalTerms('₺29,99', _en.perMonth, 'Google Play')),
      findsOneWidget,
    );
    // Denemesi olmayan pakette "bugün ödeme alınmaz" yazmaz.
    expect(find.text(_en.trialTodayText), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan-buy')));
    await tester.pumpAndSettle();
    expect(subscription.bought, [PlanPeriod.monthly]);
  });

  // Hesabı olmayan kişi: giriş, ardından kaldığı yerden satın alma.
  Future<_FakeAuth> buyWithoutAccount(WidgetTester tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    // Gerçekte bu bağı ProxyProvider kurar.
    auth.addListener(() {
      subscription
        ..needsSignIn = !auth.signedIn
        ..notifyListeners();
    });
    await open(tester, auth: auth);

    expect(find.text(_en.signInToSubscribeHint), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-buy')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);
    // Henüz hiçbir şey satın alınmadı.
    expect(subscription.bought, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('email')), 'a@b.co');
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, _en.authText('login')));
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('after signing in, the purchase continues by itself', (
    tester,
  ) async {
    subscription = _FakeSubscription()
      ..needsSignIn = true
      ..offers = [
        _offer(PlanPeriod.yearly, '₺199,99', 199.99, trial: 7),
        _offer(PlanPeriod.monthly, '₺29,99', 29.99),
      ];

    await buyWithoutAccount(tester);

    // Hesap ekranı kapandı; kişi düğmeye bir kez daha basmadan mağazaya gitti.
    expect(find.byType(AccountScreen), findsNothing);
    expect(subscription.refreshes, 1);
    expect(subscription.bought, [PlanPeriod.yearly]);
  });

  testWidgets('an account that already has Premium is not charged again', (
    tester,
  ) async {
    subscription = _FakeSubscription()
      ..needsSignIn = true
      ..premiumAccount = true
      ..offers = [_offer(PlanPeriod.yearly, '₺199,99', 199.99, trial: 7)];

    await buyWithoutAccount(tester);

    expect(find.byType(AccountScreen), findsNothing);
    expect(subscription.bought, isEmpty);
    expect(find.text(_en.premiumActive), findsOneWidget);
  });

  testWidgets('while the purchase is verified the button waits', (
    tester,
  ) async {
    // Mağaza penceresi kapandı, sunucu henüz doğrulamadı: düğme eski hâliyle
    // durursa kişi yeniden basar.
    subscription = _FakeSubscription()
      ..verifying = true
      ..offers = [_offer(PlanPeriod.yearly, '₺199,99', 199.99, trial: 7)];
    await open(tester, settle: false);

    expect(find.text(_en.verifyingPurchase), findsOneWidget);
    expect(find.text(_en.startTrial(7)), findsNothing);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('plan-buy')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a payment awaiting approval is explained', (tester) async {
    subscription = _FakeSubscription()
      ..pending = true
      ..offers = [_offer(PlanPeriod.yearly, '₺199,99', 199.99, trial: 7)];
    await open(tester);

    expect(find.text(_en.purchasePending), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('plan-buy')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a completed purchase opens the welcome screen once', (
    tester,
  ) async {
    subscription = _FakeSubscription()
      ..verifying = true
      ..offers = [_offer(PlanPeriod.yearly, '₺199,99', 199.99, trial: 7)];
    await open(tester, settle: false);

    subscription.finishPurchase();
    await tester.pumpAndSettle();

    expect(find.byType(PremiumWelcomeScreen), findsOneWidget);
    // Premium ekranının yerini alır; geri dönünce satın alma ekranı çıkmaz.
    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.text(_en.premiumWelcomeTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('premium-valid-until')), findsOneWidget);
    expect(find.textContaining('Oct 17, 2026'), findsOneWidget);
  });

  testWidgets('Premium that was already active shows no welcome', (
    tester,
  ) async {
    // Açılışta hakkın okunması ya da geri yükleme kutlama açmaz.
    subscription = _FakeSubscription()
      ..premium = true
      ..until = DateTime(2026, 10, 30);
    await open(tester);

    expect(find.byType(PremiumWelcomeScreen), findsNothing);
    expect(find.text(_en.premiumActive), findsOneWidget);
    // Ne zamana kadar geçerli olduğu ve nereden yönetileceği yazar.
    expect(find.textContaining('Oct 30, 2026'), findsOneWidget);
    expect(find.text(_en.manageSubscription), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-buy')), findsNothing);
  });

  testWidgets('without the store no price is invented', (tester) async {
    subscription = _FakeSubscription();
    await open(tester);

    expect(find.text(_en.priceUnavailable), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-buy')), findsNothing);
    expect(find.textContaining('₺'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plans-retry')));
    await tester.pump();
    expect(subscription.reloads, 1);
  });
}
