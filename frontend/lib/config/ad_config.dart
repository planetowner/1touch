import 'package:flutter/foundation.dart';

/// 개발·프로파일 빌드는 공식 테스트 광고를, 출시 빌드는 전달받은 광고 ID를 써요.
///
/// 실제 배너 ID는 config/production.json에서 관리해요.
/// 스토어 제출용 빌드에만 이 파일을 지정하고, ID가 없으면 광고를 요청하지 않아요.
///
/// flutter build appbundle --release --dart-define-from-file=config/production.json
/// flutter build ipa --release --dart-define-from-file=config/production.json
/// TestFlight 광고 검증 때만 config/ad-test-device.json을 추가로 지정해요.
abstract final class AdConfig {
  // 테스트 기기 설정은 별도 빌드 옵션으로만 켜서 정식 출시 빌드에 남기지 않아요.
  static const testDeviceId = String.fromEnvironment('ADMOB_TEST_DEVICE_ID');

  static const _androidBannerRealId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
  );
  static const _iosBannerRealId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
  );

  // 출시 설정을 전달해도 개발·프로파일 빌드에서는 실제 광고를 요청하지 않아요.
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
