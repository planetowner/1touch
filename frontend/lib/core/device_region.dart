import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 화면 언어와 별도로 로그인 추천에 쓸 기기 지역을 읽어요.
class DeviceRegion {
  const DeviceRegion();

  static const channel = MethodChannel('com.onetouch.football/device_region');

  Future<String?> readCountryCode() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS의 선호 언어에 붙은 국가 코드와 설정의 지역은 다를 수 있어요.
      return channel.invokeMethod<String>('getRegionCode');
    }
    return WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  }
}
