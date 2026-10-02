import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/device_region.dart';
import 'package:onetouch/data/betting/api/api_betting_repository.dart';
import 'package:onetouch/data/betting/betting_repository.dart';

final BettingRepository bettingRepository = ApiBettingRepository(
  api: apiClient,
  // 앱 내 지역 설정이 생기면 이 공급자만 바꾸고 적립 요청은 그대로 사용해요.
  countryCode: const DeviceRegion().readCountryCode,
);
