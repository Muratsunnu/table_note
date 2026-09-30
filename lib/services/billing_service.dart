import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/app_config.dart';

class BillingService {
  final InAppPurchase _store;

  BillingService({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  Stream<List<PurchaseDetails>> get purchases => _store.purchaseStream;

  Future<ProductDetails?> loadYearlyProduct() async {
    if (!await _store.isAvailable()) return null;
    final response = await _store.queryProductDetails({
      AppConfig.premiumYearlyProductId,
    });
    if (response.error != null || response.productDetails.isEmpty) return null;
    return response.productDetails.first;
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
