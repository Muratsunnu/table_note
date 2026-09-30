import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/billing_service.dart';
import '../services/entitlement_service.dart';
import 'auth_provider.dart';

class SubscriptionProvider extends ChangeNotifier {
  // Geçici test erişimi. Release derlemelerinde kDebugMode false olduğu için
  // mağazaya gönderilen uygulamada Premium hakkı vermez.
  static const bool _temporaryDebugPremium = true;

  final BillingService _billing;
  final EntitlementService _entitlements;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  AuthProvider _auth;
  String? _authUserId;
  bool _disposed = false;
  ProductDetails? _yearlyProduct;
  bool _isPremium = false;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _validUntil;

  SubscriptionProvider(
    this._auth, {
    BillingService? billing,
    EntitlementService? entitlements,
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

  bool get isPremium => _isPremium || (kDebugMode && _temporaryDebugPremium);
  bool get isLoading => _isLoading;
  bool get canPurchase => _yearlyProduct != null && !_isLoading;
  bool get requiresSignIn => !_auth.isSignedIn;
  String? get localizedPrice => _yearlyProduct?.price;
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
      _yearlyProduct = await _billing.loadYearlyProduct();
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

  Future<bool> startPurchase() async {
    final product = _yearlyProduct;
    if (product == null || _isLoading || !_auth.isSignedIn) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _billing.purchase(product);
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
      if (purchase.productID != _yearlyProduct?.id &&
          purchase.productID != 'table_note_premium_yearly') {
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
