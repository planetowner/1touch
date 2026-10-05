import 'package:onetouch/core/api_client_provider.dart';

// 같은 API 계약을 운영·테스트 배포 경로와 관계없이 모의 응답으로 확인해요.
String relativeApiPath(Uri uri) =>
    uri.path.substring(apiClient.baseUri.path.length);
