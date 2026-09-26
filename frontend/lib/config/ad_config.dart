import 'package:flutter/foundation.dart';

/// AdMob IDs used by the app.
///
/// Debug/profile builds always use Google's official test units. Release IDs
/// are supplied at build time so a placeholder ID can never be requested by a
/// production build:
///
/// flutter build appbundle --dart-define=ADMOB_ANDROID_BANNER_ID=ca-app-pub-...
/// flutter build ipa --dart-define=ADMOB_IOS_BANNER_ID=ca-app-pub-...
abstract final class AdConfig {
  static const _androidBannerRealId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
  );
  static const _iosBannerRealId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
  );

  // Google official test banner ad unit IDs.
  static const _androidBannerTestId = 'ca-app-pub-3940256099942544/9214589741';
  static const _iosBannerTestId = 'ca-app-pub-3940256099942544/2435281174';

  static String? get bannerAdUnitId => bannerAdUnitIdFor(
        platform: defaultTargetPlatform,
        isRelease: kReleaseMode,
      );

  @visibleForTesting
  static String? bannerAdUnitIdFor({
    required TargetPlatform platform,
    required bool isRelease,
  }) {
    final String testId;
    final String realId;
    if (platform == TargetPlatform.android) {
      testId = _androidBannerTestId;
      realId = _androidBannerRealId;
    } else if (platform == TargetPlatform.iOS) {
      testId = _iosBannerTestId;
      realId = _iosBannerRealId;
    } else {
      return null;
    }

    if (!isRelease) return testId;
    return realId.isEmpty ? null : realId;
  }
}
