import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/plan_offer.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/screens/premium_screen.dart';

class _FakeSubscription extends ChangeNotifier implements SubscriptionProvider {
  List<PlanOffer> offers = const [];
  final bought = <PlanPeriod>[];
  int reloads = 0;

  @override
  bool get isPremium => false;
  @override
  bool get isLoading => false;
  @override
  bool get requiresSignIn => false;
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

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(subscription.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionProvider>.value(
        value: subscription,
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
    await tester.pumpAndSettle();
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
    expect(
      find.text(_en.trialTerms(14, '₺249,99', _en.perYear)),
      findsOneWidget,
    );
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
    expect(find.text(_en.renewalTerms('₺29,99', _en.perMonth)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-buy')));
    await tester.pumpAndSettle();
    expect(subscription.bought, [PlanPeriod.monthly]);
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
