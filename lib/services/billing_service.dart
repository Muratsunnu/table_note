import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../config/app_config.dart';
import '../models/plan_offer.dart';

class BillingService {
  final InAppPurchase _store;

  BillingService({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  Stream<List<PurchaseDetails>> get purchases => _store.purchaseStream;

  /// Mağazadaki Premium paketleri: fiyatlarıyla ve varsa ücretsiz denemeyle.
  /// Mağazaya ulaşılamıyorsa ya da ürün tanımlı değilse boş döner.
  Future<List<PlanOffer>> loadPlans() async {
    if (!await _store.isAvailable()) return const [];
    final response = await _store.queryProductDetails(
      AppConfig.premiumProductIds.values.toSet(),
    );
    if (response.error != null) return const [];
    final plans = <PlanOffer>[];
    for (final entry in AppConfig.premiumProductIds.entries) {
      final candidates = [
        for (final product in response.productDetails)
          if (product.id == entry.value) product,
      ];
      final plan = await _planFrom(entry.key, candidates);
      if (plan != null) plans.add(plan);
    }
    return plans;
  }

  Future<PlanOffer?> _planFrom(
    PlanPeriod period,
    List<ProductDetails> candidates,
  ) async {
    if (candidates.isEmpty) return null;

    // Android bir aboneliğin her teklifini ayrı bir ürün olarak döndürür ve
    // "fiyat" diye teklifin İLK aşamasını yazar; ücretsiz denemede bu
    // "Ücretsiz"dir. Yalnızca kullanıcının yararlanabileceği teklifler gelir.
    // En uzun denemeyi veren teklif seçilir, gösterilen fiyat son aşamanındır.
    PlanOffer? best;
    for (final candidate in candidates) {
      if (candidate is! GooglePlayProductDetails) continue;
      final index = candidate.subscriptionIndex;
      final offers = candidate.productDetails.subscriptionOfferDetails;
      if (index == null || offers == null || index >= offers.length) continue;
      final read = readPlanPhases([
        for (final phase in offers[index].pricingPhases)
          PlanPhase(
            formattedPrice: phase.formattedPrice,
            priceMicros: phase.priceAmountMicros,
            billingPeriod: phase.billingPeriod,
            cycles: phase.billingCycleCount,
          ),
      ]);
      if (read == null) continue;
      if (best == null || (read.trialDays ?? 0) > (best.trialDays ?? 0)) {
        best = PlanOffer(
          period: period,
          product: candidate,
          price: read.price,
          rawPrice: read.rawPrice,
          trialDays: read.trialDays,
        );
      }
    }
    if (best != null) return best;

    final product = candidates.first;
    return PlanOffer(
      period: period,
      product: product,
      price: product.price,
      rawPrice: product.rawPrice,
      trialDays: await _appStoreTrialDays(period, product),
    );
  }

  /// App Store'un bu kullanıcıya vereceği ücretsiz deneme, gün olarak.
  Future<int?> _appStoreTrialDays(
    PlanPeriod period,
    ProductDetails product,
  ) async {
    try {
      if (product is AppStoreProduct2Details) {
        // StoreKit 2 eklentisi tanıtım teklifinin süresini vermiyor, yalnızca
        // kullanıcının ondan yararlanıp yararlanamayacağını söylüyor. Süre
        // bu yüzden App Store Connect'teki ayarla birlikte tutulan tek bir
        // sabitten okunur; hak yoksa deneme hiç gösterilmez.
        final days = AppConfig.appStoreTrialDays[period];
        if (days == null) return null;
        return await SK2Product.isIntroductoryOfferEligible(product.id)
            ? days
            : null;
      }
      if (product is AppStoreProductDetails) {
        final intro = product.skProduct.introductoryPrice;
        if (intro == null ||
            intro.paymentMode != SKProductDiscountPaymentMode.freeTrail) {
          return null;
        }
        final unitDays = switch (intro.subscriptionPeriod.unit) {
          SKSubscriptionPeriodUnit.day => 1,
          SKSubscriptionPeriodUnit.week => 7,
          SKSubscriptionPeriodUnit.month => 30,
          SKSubscriptionPeriodUnit.year => 365,
        };
        final days =
            unitDays *
            intro.subscriptionPeriod.numberOfUnits *
            (intro.numberOfPeriods < 1 ? 1 : intro.numberOfPeriods);
        return days > 0 ? days : null;
      }
    } catch (error) {
      // Deneme bilgisi okunamadıysa olmayan bir deneme vaat edilmez.
      debugPrint('Deneme bilgisi okunamadı: $error');
    }
    return null;
  }

  Future<bool> purchase(ProductDetails product) {
    return _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> restore() => _store.restorePurchases();

  Future<void> complete(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
}
