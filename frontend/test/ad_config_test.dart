import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/config/ad_config.dart';

void main() {
  // 같은 테스트를 기본 설정과 config/production.json으로 각각 실행해요.
  const hasReleaseIds = bool.hasEnvironment('ADMOB_ANDROID_BANNER_ID') ||
      bool.hasEnvironment('ADMOB_IOS_BANNER_ID');
  const cases = [
    (
      platform: TargetPlatform.android,
      testId: 'ca-app-pub-3940256099942544/9214589741',
      releaseId: 'ca-app-pub-3643320019706741/5013465512',
    ),
    (
      platform: TargetPlatform.iOS,
      testId: 'ca-app-pub-3940256099942544/2435281174',
      releaseId: 'ca-app-pub-3643320019706741/6331161470',
    ),
  ];

  for (final value in cases) {
    test('${value.platform.name} debug/profile builds use the test banner', () {
      expect(
        AdConfig.bannerAdUnitIdFor(
          platform: value.platform,
          isRelease: false,
        ),
        value.testId,
      );
    });

    test(
        hasReleaseIds
            ? '${value.platform.name} release builds use the issued banner ID'
            : '${value.platform.name} release builds without an ID disable ads',
        () {
      expect(
        AdConfig.bannerAdUnitIdFor(
          platform: value.platform,
          isRelease: true,
        ),
        hasReleaseIds ? value.releaseId : isNull,
      );
    });
  }

  test('unsupported platforms do not request an ad', () {
    for (final isRelease in [false, true]) {
      expect(
        AdConfig.bannerAdUnitIdFor(
          platform: TargetPlatform.macOS,
          isRelease: isRelease,
        ),
        isNull,
      );
    }
  });
}
