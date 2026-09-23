import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/device_region.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.platformDispatcher.clearLocaleTestValue();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceRegion.channel, null);
  });

  test('iOS reads the region independently of the preferred language',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    binding.platformDispatcher.localeTestValue = const Locale('en', 'US');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DeviceRegion.channel,
      (call) async {
        expect(call.method, 'getRegionCode');
        return 'KR';
      },
    );

    expect(await const DeviceRegion().readCountryCode(), 'KR');
  });

  test('iOS does not infer a missing region from the language', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    binding.platformDispatcher.localeTestValue = const Locale('ko', 'KR');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DeviceRegion.channel,
      (_) async => null,
    );

    expect(await const DeviceRegion().readCountryCode(), isNull);
  });

  test('reads the system locale region on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    binding.platformDispatcher.localeTestValue = const Locale('en', 'JP');

    expect(await const DeviceRegion().readCountryCode(), 'JP');
  });
}
