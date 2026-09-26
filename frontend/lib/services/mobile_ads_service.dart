import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract final class MobileAdsService {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    } on MissingPluginException catch (error) {
      // A newly added native plugin is unavailable until the app is stopped
      // and rebuilt. Keep the app usable and leave ads disabled meanwhile.
      debugPrint('Google Mobile Ads plugin is not registered: $error');
    } on PlatformException catch (error) {
      debugPrint('Google Mobile Ads initialization failed: $error');
    }
  }
}
