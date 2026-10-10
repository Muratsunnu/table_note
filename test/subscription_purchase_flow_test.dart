import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/plan_offer.dart';
import 'package:table_note/providers/auth_provider.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/services/billing_service.dart';
import 'package:table_note/services/entitlement_service.dart';

/// Ödeme anı: mağaza satın almayı bildirir, sunucu doğrular, Premium açılır.
class _Store implements BillingService {
  final events = StreamController<List<PurchaseDetails>>();
  final completed = <PurchaseDetails>[];

  @override
  Stream<List<PurchaseDetails>> get purchases => events.stream;
  @override
  Future<List<PlanOffer>> loadPlans() async => const [];
  @override
  Future<void> complete(PurchaseDetails purchase) async =>
      completed.add(purchase);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Server implements EntitlementService {
  /// Doğrulama testin bıraktığı ana kadar bekler.
  Completer<Entitlement> answer = Completer<Entitlement>();
  int verifications = 0;

  @override
  Future<Entitlement> loadCached() async => const Entitlement(isPremium: false);
  @override
  Future<Entitlement> refresh() async => const Entitlement(isPremium: false);
  @override
  Future<Entitlement> verifyPurchase({
    required String productId,
    required String verificationData,
    required String source,
  }) {
    verifications++;
    return answer.future;
  }
}

PurchaseDetails _purchase(PurchaseStatus status) => PurchaseDetails(
  productID: 'table_note_premium_yearly',
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: 'token',
    source: 'google_play',
  ),
  transactionDate: null,
  status: status,
)..pendingCompletePurchase = status == PurchaseStatus.purchased;

void main() {
  late _Store store;
  late _Server server;
  late SubscriptionProvider subscription;
  final premium = Entitlement(
    isPremium: true,
    validUntil: DateTime.now().add(const Duration(days: 7)),
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    server = _Server();
    final auth = AuthProvider();
    subscription = SubscriptionProvider(
      auth,
      billing: store,
      entitlements: server,
    )..setDebugFreeUser(true);
    addTearDown(subscription.dispose);
    addTearDown(auth.dispose);
    addTearDown(store.events.close);
    await settle();
  });

  test(
    'doğrulama sürerken bekler, bitince satın alma bir kez bildirilir',
    () async {
      store.events.add([_purchase(PurchaseStatus.purchased)]);
      await settle();

      // Mağaza ödemeyi aldı; sunucu henüz yanıt vermedi.
      expect(subscription.isVerifying, isTrue);
      expect(subscription.takePurchaseCompleted(), isFalse);

      server.answer.complete(premium);
      await settle();

      expect(subscription.isVerifying, isFalse);
      expect(subscription.validUntil, premium.validUntil);
      expect(store.completed, hasLength(1));
      // Karşılama ekranı için tek seferlik haber.
      expect(subscription.takePurchaseCompleted(), isTrue);
      expect(subscription.takePurchaseCompleted(), isFalse);
    },
  );

  test('geri yükleme karşılama ekranını açtırmaz', () async {
    server.answer.complete(premium);

    store.events.add([_purchase(PurchaseStatus.restored)]);
    await settle();
    await settle();

    expect(server.verifications, 1);
    expect(subscription.validUntil, premium.validUntil);
    expect(subscription.takePurchaseCompleted(), isFalse);
  });

  test(
    'doğrulanamayan satın alma bekleme durumunu bırakır ve hata verir',
    () async {
      store.events.add([_purchase(PurchaseStatus.purchased)]);
      await settle();
      expect(subscription.isVerifying, isTrue);

      server.answer.completeError(StateError('sunucuya ulaşılamadı'));
      await settle();

      expect(subscription.isVerifying, isFalse);
      expect(subscription.errorMessage, isNotNull);
      // Mağaza ödemeyi aldı; sorun internet değil, doğrulama.
      expect(subscription.problem, PurchaseProblem.verification);
      expect(subscription.takePurchaseCompleted(), isFalse);
    },
  );

  test('doğrulama sırasında internet kesilirse bu ayrıca söylenir', () async {
    store.events.add([_purchase(PurchaseStatus.purchased)]);
    await settle();

    server.answer.completeError(const SocketException('Failed host lookup'));
    await settle();

    expect(subscription.problem, PurchaseProblem.network);
  });

  test('hata yokken sorun türü de yoktur', () async {
    expect(subscription.problem, isNull);

    store.events.add([_purchase(PurchaseStatus.purchased)]);
    await settle();
    server.answer.completeError(StateError('doğrulanamadı'));
    await settle();
    expect(subscription.problem, isNotNull);

    // Sonraki deneme başarılı olunca eski hata kalkar.
    server.answer = Completer<Entitlement>()..complete(premium);
    store.events.add([_purchase(PurchaseStatus.restored)]);
    await settle();
    await settle();
    expect(subscription.problem, isNull);
  });

  test('onay bekleyen ödeme bildirilir, onaylanınca kalkar', () async {
    store.events.add([_purchase(PurchaseStatus.pending)]);
    await settle();
    expect(subscription.hasPendingPurchase, isTrue);
    expect(server.verifications, 0);

    server.answer.complete(premium);
    store.events.add([_purchase(PurchaseStatus.purchased)]);
    await settle();
    await settle();

    expect(subscription.hasPendingPurchase, isFalse);
    expect(subscription.takePurchaseCompleted(), isTrue);
  });

  test('vazgeçilen ödeme bekleme durumunu kaldırır', () async {
    store.events.add([_purchase(PurchaseStatus.pending)]);
    await settle();

    store.events.add([_purchase(PurchaseStatus.canceled)]);
    await settle();

    expect(subscription.hasPendingPurchase, isFalse);
    expect(subscription.errorMessage, isNull);
  });
}
