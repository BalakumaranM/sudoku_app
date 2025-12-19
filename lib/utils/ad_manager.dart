import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'iap_manager.dart';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  static AdManager get instance => _instance;
  AdManager._internal();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  
  // Test IDs - REPLACE WITH REAL IDS IN PRODUCTION
  final String _androidRewardedId = 'ca-app-pub-9616923703751463/3140345175';
  final String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  final String _androidInterstitialId = 'ca-app-pub-9616923703751463/1621774591';
  final String _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  bool _isMobileAdsInitialized = false;

  Future<void> initialize() async {
    if (kIsWeb) return; // Ads not supported on web in this implementation
    try {
      await MobileAds.instance.initialize();
      _isMobileAdsInitialized = true;
      _loadRewardedAd();
      _loadInterstitialAd();
    } catch (e) {
      debugPrint("AdMob initialization failed: $e");
    }
  }

  String get _rewardedAdUnitId {
    if (Platform.isAndroid) return _androidRewardedId;
    if (Platform.isIOS) return _iosRewardedId;
    return '';
  }

  String get _interstitialAdUnitId {
    if (Platform.isAndroid) return _androidInterstitialId;
    if (Platform.isIOS) return _iosInterstitialId;
    return '';
  }

  void _loadRewardedAd() {
    if (!_isMobileAdsInitialized) return;
    
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  void _loadInterstitialAd() {
    if (!_isMobileAdsInitialized) return;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd(); // Reload for next time
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  void showRewardedAd(VoidCallback onReward) {
    if (IAPManager.instance.isPremium) {
      onReward();
      return;
    }

    if (_rewardedAd == null) {
      debugPrint('Warning: Ad not ready, granting reward anyway (fallback)');
      onReward();
      _loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedAd();
        onReward(); // Grant reward on failure to avoid user frustration
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onReward();
      },
    );
    _rewardedAd = null;
  }

  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (IAPManager.instance.isPremium) {
        onAdClosed?.call();
        return;
    }
  
    if (_interstitialAd == null) {
      onAdClosed?.call();
      _loadInterstitialAd();
      return;
    }
    
    // Hook close callback for this specific instance
     _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          onAdClosed?.call();
          _loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
           ad.dispose();
           onAdClosed?.call();
           _loadInterstitialAd();
        },
     );

    _interstitialAd!.show();
    _interstitialAd = null;
  }
}
