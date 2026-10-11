import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:onetouch/core/web_links.dart';

class LinkPreviewData {
  const LinkPreviewData({required this.title, this.imageUri});
  final String title;
  final Uri? imageUri;

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
  LinkPreviewRepository({http.Client? client}) : _client = client;
  final http.Client? _client;

  Future<LinkPreviewData> load(Uri uri) async {
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
      return LinkPreviewData.fromHtml(response.bodyBytes, pageUri);
    } finally {
      if (_client == null) client.close();
    }
  }
}
