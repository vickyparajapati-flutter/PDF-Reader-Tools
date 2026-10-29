import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  /// In debug mode (development / testing), always uses Google official Test IDs.
  /// In release mode (Play Store production), automatically switches to live IDs!
  static bool get isTestMode => kDebugMode;

  // Real Production AdMob Ad Unit IDs
  static const String _liveAppOpenId = 'ca-app-pub-7517890910821454/7834343622';
  static const String _liveBannerId = 'ca-app-pub-7517890910821454/2438546719';
  static const String _liveInterstitialId = 'ca-app-pub-7517890910821454/1340640355';
  static const String _liveRewardedId = 'ca-app-pub-7517890910821454/2540161057';
  static const String _liveNativeId = 'ca-app-pub-7517890910821454/9546880548';

  /// App Open Ad Unit ID
  static String get appOpenAdUnitId {
    if (isTestMode) {
      if (Platform.isAndroid) {
        // Google's official Android App Open Ad test ID
        return 'ca-app-pub-3940256099942544/9257395921';
      }
    }
    return _liveAppOpenId;
  }

  /// Banner Ad Unit ID
  static String get bannerAdUnitId {
    if (isTestMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Google Test Banner
      }
    }
    return _liveBannerId;
  }

  /// Interstitial Ad Unit ID
  static String get interstitialAdUnitId {
    if (isTestMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/1033173712'; // Google Test Interstitial
      }
    }
    return _liveInterstitialId;
  }

  /// Rewarded Ad Unit ID
  static String get rewardedAdUnitId {
    if (isTestMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/5224354917'; // Google Test Rewarded
      }
    }
    return _liveRewardedId;
  }

  /// Native Advanced Ad Unit ID
  static String get nativeAdUnitId {
    if (isTestMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/2247696110'; // Google Test Native Advanced
      }
    }
    return _liveNativeId;
  }
}

/// Manages loading and showing App Open Ads on app start / resume
class AppOpenAdManager {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  bool _isLoadingAd = false;
  DateTime? _appOpenLoadTime;

  /// Loads an App Open Ad with completion callback
  void loadAd({Function(bool success)? onLoaded}) {
    if (_isLoadingAd || isAdAvailable) {
      onLoaded?.call(isAdAvailable);
      return;
    }

    _isLoadingAd = true;
    debugPrint('[AdHelper] Loading App Open Ad with ID: ${AdHelper.appOpenAdUnitId} (isTestMode: ${AdHelper.isTestMode})');
    AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdHelper] App Open Ad loaded successfully!');
          _appOpenAd = ad;
          _isLoadingAd = false;
          _appOpenLoadTime = DateTime.now();
          onLoaded?.call(true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdHelper] App Open Ad failed to load: ${error.message} (code: ${error.code})');
          _isLoadingAd = false;
          _appOpenAd = null;
          onLoaded?.call(false);
        },
      ),
    );
  }

  /// Whether a valid ad is loaded and ready
  bool get isAdAvailable {
    if (_appOpenAd == null) return false;
    if (_appOpenLoadTime == null) return false;
    // App open ads expire after 4 hours
    return DateTime.now().difference(_appOpenLoadTime!).inHours < 4;
  }

  /// Shows the App Open Ad if available
  void showAdIfAvailable({Function()? onComplete}) {
    if (!isAdAvailable) {
      loadAd();
      onComplete?.call();
      return;
    }

    if (_isShowingAd) return;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd(); // Preload next ad
        onComplete?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd();
        onComplete?.call();
      },
    );

    _appOpenAd!.show();
  }
}

/// Singleton manager for Preloading and Showing Full Screen Interstitial Ads
class InterstitialAdManager {
  static final InterstitialAdManager _instance = InterstitialAdManager._internal();
  factory InterstitialAdManager() => _instance;
  InterstitialAdManager._internal();

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;

  /// Preloads an Interstitial Ad in background so it's instantly ready when user saves
  void loadAd() {
    if (_isLoading || _interstitialAd != null) return;

    _isLoading = true;
    debugPrint('[AdHelper] Preloading Interstitial Ad...');

    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdHelper] Interstitial Ad loaded and ready!');
          _interstitialAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdHelper] Interstitial Ad failed to load: ${error.message} (code: ${error.code})');
          _interstitialAd = null;
          _isLoading = false;
        },
      ),
    );
  }

  /// Shows the Interstitial Ad. Calls [onDismissed] immediately if ad is not loaded
  /// or when user closes the ad.
  void showAd({required VoidCallback onDismissed}) {
    if (_interstitialAd == null) {
      debugPrint('[AdHelper] Interstitial Ad not loaded, proceeding without ad.');
      loadAd(); // Try loading for next time
      onDismissed();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[AdHelper] Interstitial Ad shown on screen');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdHelper] Interstitial Ad dismissed');
        ad.dispose();
        _interstitialAd = null;
        loadAd(); // Preload next one
        onDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdHelper] Interstitial Ad failed to show: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
        loadAd();
        onDismissed();
      },
    );

    _interstitialAd!.show();
  }
}

/// Singleton manager for Preloading and Showing Rewarded Video Ads
class RewardedAdManager {
  static final RewardedAdManager _instance = RewardedAdManager._internal();
  factory RewardedAdManager() => _instance;
  RewardedAdManager._internal();

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// Preloads a Rewarded Ad in background
  void loadAd() {
    if (_isLoading || _rewardedAd != null) return;

    _isLoading = true;
    debugPrint('[AdHelper] Preloading Rewarded Ad...');

    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdHelper] Rewarded Ad loaded and ready!');
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdHelper] Rewarded Ad failed to load: ${error.message} (code: ${error.code})');
          _rewardedAd = null;
          _isLoading = false;
        },
      ),
    );
  }

  /// Whether a rewarded ad is loaded and ready to play
  bool get isAdAvailable => _rewardedAd != null;

  /// Shows the Rewarded Ad and executes [onUserEarnedReward] only if user completed the video.
  /// Calls [onDismissed] when ad closes (regardless of reward).
  void showAd({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onDismissed,
    VoidCallback? onAdNotAvailable,
  }) {
    if (_rewardedAd == null) {
      debugPrint('[AdHelper] Rewarded Ad not ready.');
      loadAd();
      onAdNotAvailable?.call();
      return;
    }

    bool earned = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[AdHelper] Rewarded Ad playing full screen');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdHelper] Rewarded Ad closed. Earned: $earned');
        ad.dispose();
        _rewardedAd = null;
        loadAd(); // Preload next one
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdHelper] Rewarded Ad failed to show: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        loadAd();
        onAdNotAvailable?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
        debugPrint('[AdHelper] User completed video and earned reward: ${reward.type} (${reward.amount})');
        onUserEarnedReward(reward);
      },
    );
  }
}

