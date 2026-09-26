import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/config/ad_config.dart';

void main() {
  test('debug builds use the official Android test banner unit', () {
    expect(
      AdConfig.bannerAdUnitIdFor(
        platform: TargetPlatform.android,
        isRelease: false,
      ),
      'ca-app-pub-3940256099942544/9214589741',
    );
  });

  test('debug builds use the official iOS test banner unit', () {
    expect(
      AdConfig.bannerAdUnitIdFor(
        platform: TargetPlatform.iOS,
        isRelease: false,
      ),
      'ca-app-pub-3940256099942544/2435281174',
    );
  });

  test('unsupported platforms do not request an ad', () {
    expect(
      AdConfig.bannerAdUnitIdFor(
        platform: TargetPlatform.macOS,
        isRelease: false,
      ),
      isNull,
    );
  });

  test('release builds fail closed when no real unit ID is supplied', () {
    expect(
      AdConfig.bannerAdUnitIdFor(
        platform: TargetPlatform.android,
        isRelease: true,
      ),
      isNull,
    );
  });
}
