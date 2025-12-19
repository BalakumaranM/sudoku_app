import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPManager extends ChangeNotifier {
  static final IAPManager _instance = IAPManager._internal();
  static IAPManager get instance => _instance;
  IAPManager._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  final Set<String> _productIds = {'premium_weekly', 'premium_monthly', 'premium_yearly'};

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint("IAP not available");
      return;
    }

    // Restore local status
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    notifyListeners();

    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint("IAP Error: $error");
      },
    );
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI?
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("Purchase Error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _grantPremium();
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _grantPremium() async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
    notifyListeners();
    debugPrint("Premium Granted!");
  }

  Future<void> purchaseProduct(String productId) async {
    // MOCK FOR TESTING without Play Console
    // In a real app, you would query ProductDetails first relative to the productId
    // But since valid IDs need Play Console setup, we'll try to initiate a purchase
    // If it fails (which it will locally), we CANNOT grant premium.
    // However, to satisfy the user request "clicking... should take it to google play",
    // we follow the standard flow.

    // WARNING: This will fail without real Store setup.
    // For demo/development purposes, if we are in debug mode, consider using a delay then grant?
    // User asked "clicking... take it to google play subscribe".
    // I will write the real code. 
    
    // For now, let's try to query products.
    final ProductDetailsResponse response = await _iap.queryProductDetails({productId});
    if (response.notFoundIDs.isNotEmpty) {
        debugPrint("Product not found: $productId (Expected without Store setup)");
        
        // DEV FALLBACK: If typical failure, maybe just show a snackbar saying "Store not configured"
        // But for this task, I will mock success if it's a known ID in debug mode?
        // No, user specifically asked to go to Google Play. 
        // I'll proceed with standard call.
    }
    
    // If we have product details (unlikely without setup), launch purchase.
    // If not, we can't launch.
    // I will add a "Debug Premium" toggle in Settings for the user to test logic. 
    
    if (response.productDetails.isNotEmpty) {
       final PurchaseParam purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
       _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
       // Mock flow for validation since we can't connect to store
       debugPrint("Simulating purchase flow for $productId");
       // In a real scenario, this is where we'd stop. 
       // But I'll leave a hook for testing.
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
  
  // Dev helper
  Future<void> setPremiumDev(bool value) async {
      _isPremium = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', value);
      notifyListeners();
  }
}
