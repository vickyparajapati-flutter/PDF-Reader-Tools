import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../models/ad_helper.dart';
import '../../models/pro_subscription_manager.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!ProSubscriptionManager.isPro) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.banner, // Standard 320x50 Banner
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[BannerAdWidget] Banner Ad loaded successfully');
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[BannerAdWidget] Banner Ad failed to load: ${error.message} (code: ${error.code})');
          ad.dispose();
          _bannerAd = null;
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ProSubscriptionManager.isProUserNotifier,
      builder: (context, isPro, child) {
        if (isPro || !_isLoaded || _bannerAd == null) {
          // Invisible zero-height container when ad is not loaded or user is PRO
          return const SizedBox.shrink();
        }

        return Container(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          alignment: Alignment.center,
          color: Colors.transparent,
          child: AdWidget(ad: _bannerAd!),
        );
      },
    );
  }
}
