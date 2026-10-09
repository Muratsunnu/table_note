import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/app_config.dart';
import '../models/plan_offer.dart';
import '../services/billing_service.dart';
import '../services/entitlement_service.dart';
import 'auth_provider.dart';

class SubscriptionProvider extends ChangeNotifier {
  // Geliştirme derlemesinde Premium açık sayılır ki özellikler mağaza
  // kurulmadan denenebilsin. Ayarlardaki geliştirici anahtarı bunu kapatıp
  // ücretsiz kullanıcının gördüğünü gösterir. Release derlemesinde kDebugMode
  // false olduğu için ikisinin de etkisi yoktur.
  bool _debugFreeUser = false;

  final BillingService _billing;
  final EntitlementService _entitlements;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  AuthProvider _auth;
  String? _authUserId;
  bool _disposed = false;
  List<PlanOffer> _plans = const [];
  bool _isPremium = false;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _validUntil;

  /// Ücretsiz sınırlar gelmeden önceki sürümden gelen kullanıcı. Tablo,
  /// çetele ve şablon sayısında sınırsız kalır; sesle doldurma, bulut ve
  /// paylaşım gibi yeni özellikler onun için de Premium'dur.
  final bool legacyUnlimited;

  SubscriptionProvider(
    this._auth, {
    BillingService? billing,
    EntitlementService? entitlements,
    this.legacyUnlimited = false,
  }) : _billing = billing ?? BillingService(),
       _entitlements = entitlements ?? EntitlementService() {
    _authUserId = _auth.user?.id;
    _purchaseSubscription = _billing.purchases.listen(
      _handlePurchases,
      onError: (Object error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
    _initialize();
  }

  bool get isPremium => kDebugMode ? !_debugFreeUser : _isPremium;

  /// Geliştirme derlemesinde uygulama ücretsiz kullanıcı gibi mi davranıyor.
  bool get debugFreeUser => kDebugMode && _debugFreeUser;

  /// Yalnızca geliştirme derlemesinde: sınırları, Premium'a yönlendirmeleri
  /// ve satın alma ekranını görmek için ücretsiz kullanıcıya geçer.
  void setDebugFreeUser(bool value) {
    if (!kDebugMode || _debugFreeUser == value) return;
    _debugFreeUser = value;
    notifyListeners();
  }

  /// Satın alma ekranındaki paketler mağazadan değil, örnek mi. Yalnızca
  /// geliştirme derlemesinde, mağaza ürünleri henüz yokken doğrudur.
  bool get showsSamplePlans => debugFreeUser && _plans.isEmpty;

  /// Tablo, çetele ve şablon oluştururken sınır uygulanmıyor mu.
  bool get hasUnlimitedPlan => isPremium || legacyUnlimited;
  bool get isLoading => _isLoading;
  // Misafir oturumu hesap degildir: abonelik ona baglanirsa uygulama
  // silinince kaybolan bir kimlikte kalir.
  bool get requiresSignIn => !_auth.hasAccount;

  /// Mağazanın sunduğu paketler, fiyatlarıyla. Mağazaya ulaşılamadıysa
  /// boştur; uygulama kendi başına fiyat göstermez.
  List<PlanOffer> get plans => showsSamplePlans ? _samplePlans : _plans;

  PlanOffer? plan(PlanPeriod period) {
    for (final plan in plans) {
      if (plan.period == period) return plan;
    }
    return null;
  }

  // Satın alma ekranı mağaza kurulmadan görülebilsin diye; yalnızca
  // geliştirme derlemesinde kullanılır, satın alınamaz.
  static final List<PlanOffer> _samplePlans = [
    for (final (period, price, raw, trial) in [
      (PlanPeriod.yearly, '₺199,99', 199.99, 7),
      (PlanPeriod.monthly, '₺29,99', 29.99, null),
    ])
      PlanOffer(
        period: period,
        product: ProductDetails(
          id: AppConfig.premiumProductIds[period]!,
          title: '',
          description: '',
          price: price,
          rawPrice: raw,
          currencyCode: 'TRY',
        ),
        price: price,
        rawPrice: raw,
        trialDays: trial,
      ),
  ];

  String? get errorMessage => _errorMessage;
  DateTime? get validUntil => _validUntil;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
    final userId = auth.user?.id;
    if (_authUserId == userId) return;
    _authUserId = userId;
    _apply(const Entitlement(isPremium: false));
    _errorMessage = null;
    // ProxyProvider calls this during build; defer listener notifications.
    scheduleMicrotask(() async {
      if (_disposed || _authUserId != userId) return;
      notifyListeners();
      if (userId != null) await refreshEntitlement();
    });
  }

  Future<void> _initialize() async {
    try {
      final userId = _authUserId;
      final cached = await _entitlements.loadCached();
      if (_authUserId == userId) _apply(cached);
      _plans = await _billing.loadPlans();
      if (_auth.isSignedIn) await refreshEntitlement(notify: false);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshEntitlement({bool notify = true}) async {
    final userId = _authUserId;
    try {
      final entitlement = await _entitlements.refresh();
      if (_disposed || _authUserId != userId) return;
      _apply(entitlement);
      _errorMessage = null;
    } catch (error) {
      if (_disposed || _authUserId != userId) return;
      _errorMessage = error.toString();
    }
    if (notify) notifyListeners();
  }

  /// Paketler açılışta alınamadıysa (mağazaya ulaşılamadı) yeniden dener.
  Future<void> reloadPlans() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      _plans = await _billing.loadPlans();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startPurchase(PlanOffer plan) async {
    if (_isLoading || !_auth.hasAccount || showsSamplePlans) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _billing.purchase(plan.product);
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _billing.restore();
    } catch (error) {
      _errorMessage = error.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!AppConfig.premiumProductIds.containsValue(purchase.productID)) {
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        _errorMessage = purchase.error?.message;
      } else if (purchase.status == PurchaseStatus.canceled) {
        _errorMessage = null;
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          final userId = _authUserId;
          final entitlement = await _entitlements.verifyPurchase(
            productId: purchase.productID,
            verificationData: purchase.verificationData.serverVerificationData,
            source: purchase.verificationData.source,
          );
          if (_authUserId == userId) {
            _apply(entitlement);
            _errorMessage = null;
          }
          if (purchase.pendingCompletePurchase) {
            await _billing.complete(purchase);
          }
        } catch (error) {
          _errorMessage = error.toString();
        }
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  void _apply(Entitlement entitlement) {
    _isPremium = entitlement.isPremium;
    _validUntil = entitlement.validUntil;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
