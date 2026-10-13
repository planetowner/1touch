import 'dart:async';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/core/web_links.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

final linkPreviewRepository =
    LinkPreviewRepository(cacheStore: localCacheStore);

class LinkPreviewData {
  const LinkPreviewData({required this.title, this.imageUri});
  final String title;
  final Uri? imageUri;

  Map<String, dynamic> toJson() => {
        'title': title,
        'image_url': imageUri?.toString(),
      };

  factory LinkPreviewData.fromJson(Map<String, dynamic> json) =>
      LinkPreviewData(
        title: json['title'] as String,
        imageUri: webUri(json['image_url'] as String? ?? ''),
      );

  factory LinkPreviewData.fromHtml(List<int> bytes, Uri pageUri) {
    final document = html.parse(bytes);
    String? meta(String property) => document
        .querySelector('meta[property="$property"]')
        ?.attributes['content']
        ?.trim();
    final title = meta('og:title');
    final image = meta('og:image:secure_url') ?? meta('og:image');
    return LinkPreviewData(
      title: title != null && title.isNotEmpty
          ? title
          : document.querySelector('title')?.text.trim() ?? pageUri.host,
      imageUri: image == null || image.isEmpty
          ? null
          : webUri(pageUri.resolve(image).toString()),
    );
  }
}

class LinkPreviewRepository {
  LinkPreviewRepository({http.Client? client, LocalCacheStore? cacheStore})
      : _client = client,
        _cacheStore = cacheStore;
  final http.Client? _client;
  final LocalCacheStore? _cacheStore;
  final _cached = <Uri, LinkPreviewData>{};
  final _savedAt = <Uri, DateTime>{};
  final _requests = <Uri, Future<LinkPreviewData>>{};

  LinkPreviewData? cached(Uri uri) => _cached[uri];

  Future<LinkPreviewData> load(Uri uri) async {
    if (!_cached.containsKey(uri)) {
      final record = await _cacheStore?.read(LocalCacheKeys.linkPreview(uri));
      if (record != null) {
        _cached[uri] = LinkPreviewData.fromJson(
            (record.payload as Map).cast<String, dynamic>());
        _savedAt[uri] = record.savedAt;
      }
    }
    final data = _cached[uri];
    if (data == null) return _fetch(uri);
    // 저장된 제목으로 카드 높이를 먼저 확정하고, 갱신 결과는 다음 진입에 사용해요.
    if (AppCachePolicy.freshness(CacheTier.standard, savedAt: _savedAt[uri]) ==
        CacheFreshness.stale) {
      unawaited(_fetch(uri).then<void>((_) {}, onError: (_, __) {}));
    }
    return data;
  }

  Future<LinkPreviewData> _fetch(Uri uri) => _requests.putIfAbsent(uri, () {
        final request = _download(uri);
        return request.whenComplete(() {
          _requests.remove(uri);
        });
      });

  Future<LinkPreviewData> _download(Uri uri) async {
    // 외부 사이트에는 앱 API의 인증 헤더를 보내지 않아요.
    final client = _client ?? http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/html,application/xhtml+xml';
      final stream =
          await client.send(request).timeout(const Duration(seconds: 12));
      // 단축 주소가 이동한 뒤의 상대 이미지 경로는 최종 페이지를 기준으로 풀어요.
      final pageUri = switch (stream) {
        http.BaseResponseWithUrl(:final url) => url,
        _ => uri,
      };
      final response = await http.Response.fromStream(stream)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw http.ClientException('Link preview: ${response.statusCode}', uri);
      }
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('text/html') &&
          !contentType.contains('application/xhtml+xml')) {
        throw const FormatException('Link preview requires an HTML page.');
      }
      final data = LinkPreviewData.fromHtml(response.bodyBytes, pageUri);
      _cached[uri] = data;
      _savedAt[uri] = DateTime.now().toUtc();
      await _cacheStore?.write(LocalCacheKeys.linkPreview(uri), data.toJson());
      return data;
    } finally {
      if (_client == null) client.close();
    }
  }
}
