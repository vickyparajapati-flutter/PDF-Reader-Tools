import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../models/ad_helper.dart';

enum NativeTemplateStyleType { small, medium }

class NativeAdWidget extends StatefulWidget {
  final NativeTemplateStyleType templateType;

  const NativeAdWidget({
    super.key,
    this.templateType = NativeTemplateStyleType.small,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> with AutomaticKeepAliveClientMixin {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  // Prevent disposing and reloading when list scrolls past
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('[NativeAdWidget] Native ad loaded successfully');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[NativeAdWidget] Native ad failed to load: ${error.message} (code: ${error.code})');
          ad.dispose();
          _nativeAd = null;
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.templateType == NativeTemplateStyleType.small
            ? TemplateType.small
            : TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFFE5252A),
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF1E1E1E),
          style: NativeTemplateFontStyle.bold,
          size: 14.5,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF6E6E6E),
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // If ad has not loaded yet, don't show any empty container (0 height)
    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    // Google Mobile Ads standard template dimensions:
    // Small template: 90 - 100 height (perfect for list items)
    // Medium template: 300 - 360 height (perfect for card sections)
    final double height = widget.templateType == NativeTemplateStyleType.small ? 92.0 : 320.0;

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}

