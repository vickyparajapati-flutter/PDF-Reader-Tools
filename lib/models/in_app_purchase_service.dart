import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'pro_subscription_manager.dart';

class InAppPurchaseService {
  static final InAppPurchaseService _instance = InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;

  // Google Play Console Subscription Product IDs
  static const String monthlySubscriptionId = 'pdf_pro_monthly';
  static const String yearlySubscriptionId = 'pdf_pro_yearly';

  static const Set<String> subscriptionIds = {
    monthlySubscriptionId,
    yearlySubscriptionId,
  };

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> products = [];
  bool isStoreAvailable = false;
  bool isPurchasePending = false;

  final ValueNotifier<bool> isProductsLoadedNotifier = ValueNotifier<bool>(false);

  /// Initialize In-App Purchases and listen for purchase updates
  void initialize() async {
    isStoreAvailable = await _iap.isAvailable();

    if (!isStoreAvailable) {
      debugPrint('[InAppPurchaseService] In-App Purchase store not available');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('[InAppPurchaseService] Purchase stream error: $error');
      },
    );

    await loadProducts();
  }

  /// Load available subscription products from Google Play
  Future<void> loadProducts() async {
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(subscriptionIds);

      if (response.error != null) {
        debugPrint('[InAppPurchaseService] Error fetching products: ${response.error!.message}');
        return;
      }

      products = response.productDetails;
      isProductsLoadedNotifier.value = products.isNotEmpty;
      debugPrint('[InAppPurchaseService] Loaded ${products.length} subscription products');
    } catch (e) {
      debugPrint('[InAppPurchaseService] Exception queryProductDetails: $e');
    }
  }

  /// Buy a subscription (Monthly or Yearly)
  Future<bool> buySubscription(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      isPurchasePending = true;
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      isPurchasePending = false;
      debugPrint('[InAppPurchaseService] Buy error: $e');
      return false;
    }
  }

  /// Restore previous purchases (e.g. user reinstalled the app)
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[InAppPurchaseService] Restore error: $e');
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        isPurchasePending = true;
      } else {
        isPurchasePending = false;

        if (purchase.status == PurchaseStatus.error) {
          debugPrint('[InAppPurchaseService] Purchase error: ${purchase.error}');
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          // Unlock PRO Features across the app
          ProSubscriptionManager.setProStatus(true);
          debugPrint('[InAppPurchaseService] PRO subscription unlocked for: ${purchase.productID}');
        }

        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
