import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
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
  bool isLoadingProducts = false;

  final ValueNotifier<bool> isProductsLoadedNotifier = ValueNotifier<bool>(false);

  /// Initialize In-App Purchases, listen for stream events, and auto-sync on launch
  void initialize() async {
    isStoreAvailable = await _iap.isAvailable();

    if (!isStoreAvailable) {
      debugPrint('[InAppPurchaseService] Google Play Store Billing is not available on this device');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('[InAppPurchaseService] Purchase stream error: $error');
      },
    );

    // 1. Fetch available plans from store
    await loadProducts();

    // 2. Auto-sync subscription status on app launch (Handles Reinstall, Cancellation, Refund)
    await syncSubscriptionStatus();
  }

  /// Load available subscription products from Google Play
  Future<void> loadProducts() async {
    if (isLoadingProducts) return;
    try {
      isLoadingProducts = true;
      final ProductDetailsResponse response = await _iap.queryProductDetails(subscriptionIds);

      if (response.error != null) {
        debugPrint('[InAppPurchaseService] Error fetching products: ${response.error!.message}');
        isLoadingProducts = false;
        return;
      }

      products = response.productDetails;
      isProductsLoadedNotifier.value = products.isNotEmpty;
      isLoadingProducts = false;
      debugPrint('[InAppPurchaseService] Loaded ${products.length} subscription products');
    } catch (e) {
      isLoadingProducts = false;
      debugPrint('[InAppPurchaseService] Exception queryProductDetails: $e');
    }
  }

  /// Automatically queries Google Play for current active subscriptions.
  /// Handles:
  /// 1. Reinstallation on new device / fresh install -> Auto unlocks Pro
  /// 2. Cancellation / Expiry / Refund -> Auto revokes Pro
  /// 3. Offline resilience -> If network is absent, keeps previous cached state safely
  Future<void> syncSubscriptionStatus() async {
    if (!isStoreAvailable) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final InAppPurchaseAndroidPlatformAddition androidAddition =
            _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

        // Query active purchases from Google Play cache
        final QueryPurchaseDetailsResponse response =
            await androidAddition.queryPastPurchases();

        if (response.error == null) {
          final activePurchases = response.pastPurchases.where((purchase) {
            final isOurProduct = subscriptionIds.contains(purchase.productID);
            final isValidStatus = purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored;
            return isOurProduct && isValidStatus;
          }).toList();

          if (activePurchases.isNotEmpty) {
            // User has an active Google Play subscription
            await ProSubscriptionManager.setProStatus(true);
            debugPrint('[InAppPurchaseService] Auto-sync: Active subscription found (${activePurchases.first.productID}) -> PRO ACTIVE');
          } else {
            // No active subscription found on Google Play (Expired, Cancelled, or Refunded)
            await ProSubscriptionManager.setProStatus(false);
            debugPrint('[InAppPurchaseService] Auto-sync: No active subscription on Google Play -> PRO REVOKED');
          }
        }
      } else {
        // Fallback for non-android platforms
        await _iap.restorePurchases();
      }
    } catch (e) {
      // Network issues or Google Play offline: Retain cached status without revoking
      debugPrint('[InAppPurchaseService] Sync exception (network offline, keeping cached state): $e');
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

  /// User manually clicks "Restore Purchases" in Settings / Pro Modal
  Future<bool> restorePurchases() async {
    try {
      await _iap.restorePurchases();
      await syncSubscriptionStatus();
      return ProSubscriptionManager.isPro;
    } catch (e) {
      debugPrint('[InAppPurchaseService] Restore error: $e');
      return false;
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
        } else if (purchase.status == PurchaseStatus.canceled) {
          debugPrint('[InAppPurchaseService] User canceled the billing dialog');
        }

        // Acknowledge the purchase with Google Play to prevent 3-day auto-refund
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
