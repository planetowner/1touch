import 'package:cached_network_image/cached_network_image.dart';

// 선로딩과 카드 표시가 같은 키와 디스크 캐시를 써야 다시 다운로드하지 않아요.
CachedNetworkImageProvider homeContentImageProvider(String url) =>
    CachedNetworkImageProvider(url);
