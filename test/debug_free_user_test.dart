import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/plan_offer.dart';
import 'package:table_note/providers/auth_provider.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/services/billing_service.dart';

/// Mağaza ürünleri henüz tanımlı değil: paket gelmez.
class _EmptyStore implements BillingService {
  int purchases_ = 0;

  @override
  Stream<List<PurchaseDetails>> get purchases => const Stream.empty();
  @override
  Future<List<PlanOffer>> loadPlans() async => const [];
  @override
  Future<bool> purchase(ProductDetails product) async {
    purchases_++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Testler geliştirme kipinde koşar; anahtar yalnızca orada vardır.
  late _EmptyStore store;
  late SubscriptionProvider subscription;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _EmptyStore();
    final auth = AuthProvider();
    subscription = SubscriptionProvider(auth, billing: store);
    addTearDown(subscription.dispose);
    addTearDown(auth.dispose);
    await Future<void>.delayed(Duration.zero);
  });

  test('geliştirme derlemesi Premium açık başlar', () {
    expect(subscription.isPremium, isTrue);
    expect(subscription.debugFreeUser, isFalse);
    // Premium açıkken örnek fiyat gösterilmez.
    expect(subscription.plans, isEmpty);
  });

  test('anahtar ücretsiz kullanıcının gördüğünü açar', () {
    var notified = 0;
    subscription.addListener(() => notified++);

    subscription.setDebugFreeUser(true);

    expect(notified, 1);
    expect(subscription.isPremium, isFalse);
    expect(subscription.hasUnlimitedPlan, isFalse);
    // Mağaza boşken satın alma ekranı örnek paketlerle görülebilir.
    expect(subscription.showsSamplePlans, isTrue);
    expect(subscription.plans.map((plan) => plan.period), [
      PlanPeriod.yearly,
      PlanPeriod.monthly,
    ]);
    expect(subscription.plan(PlanPeriod.yearly)!.trialDays, 7);
    expect(subscription.plan(PlanPeriod.monthly)!.trialDays, isNull);

    subscription.setDebugFreeUser(false);
    expect(subscription.isPremium, isTrue);
    expect(subscription.plans, isEmpty);
  });

  test('örnek paket mağazaya gönderilmez', () async {
    subscription.setDebugFreeUser(true);

    final bought = await subscription.startPurchase(
      subscription.plan(PlanPeriod.yearly)!,
    );

    expect(bought, isFalse);
    expect(store.purchases_, 0);
  });
}
