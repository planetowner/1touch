import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:onetouch/config/ad_config.dart';
import 'package:onetouch/services/mobile_ads_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({
    super.key,
    this.adSize = AdSize.banner,
  });

  final AdSize adSize;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    MobileAdsService.adRequestsAllowed.addListener(_refreshAd);
    _loadAd();
  }

  void _loadAd() {
    if (!MobileAdsService.adRequestsAllowed.value) return;

    final adUnitId = AdConfig.bannerAdUnitId;
    if (adUnitId == null) {
      if (kReleaseMode &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        debugPrint(
          'Banner ad disabled: supply the platform AdMob banner unit ID '
          'with --dart-define for release builds.',
        );
      }
      return;
    }

    final ad = BannerAd(
      adUnitId: adUnitId,
      size: widget.adSize,
      // 출시 광고 정책에 따라 모든 배너는 비맞춤형으로 요청해요.
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted || _bannerAd != loadedAd) {
            loadedAd.dispose();
            return;
          }
          setState(() {
            _bannerAd = loadedAd as BannerAd;
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('Banner ad failed to load: $error');
          failedAd.dispose();
          if (!mounted || _bannerAd != failedAd) return;
          setState(() {
            _bannerAd = null;
            _isAdLoaded = false;
          });
        },
      ),
    );

    _bannerAd = ad;
    ad.load();
  }

  @override
  void didUpdateWidget(BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adSize == widget.adSize) return;
    _refreshAd();
  }

  void _refreshAd() {
    _bannerAd?.dispose();
    setState(() {
      _bannerAd = null;
      _isAdLoaded = false;
    });
    _loadAd();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!_isAdLoaded || ad == null) return const SizedBox.shrink();

    return Center(
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }

  @override
  void dispose() {
    MobileAdsService.adRequestsAllowed.removeListener(_refreshAd);
    _bannerAd?.dispose();
    super.dispose();
  }
}
