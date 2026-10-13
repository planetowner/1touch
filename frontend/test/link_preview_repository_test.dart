import 'dart:async';
import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/web_links.dart';
import 'package:onetouch/data/link_previews/link_preview_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/features/community/community_post_rich_body.dart';
import 'package:onetouch/models/post.dart';

void main() {
  test(
      'concurrent loads share a request and reuse persisted metadata after restart',
      () async {
    final response = Completer<http.Response>();
    var requests = 0;
    final store = MemoryLocalCacheStore();
    final repository = LinkPreviewRepository(
        cacheStore: store,
        client: MockClient((_) {
          requests++;
          return response.future;
        }));
    final uri = Uri.parse('https://example.com/cached');
    final first = repository.load(uri);
    final second = repository.load(uri);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    response.complete(http.Response(
        '<title>Saved</title><meta property="og:image" content="/photo.jpg">',
        200,
        headers: {'content-type': 'text/html'}));
    expect((await first).title, 'Saved');
    expect(await second, same(repository.cached(uri)));
    final restarted = LinkPreviewRepository(
        cacheStore: store,
        client: MockClient((_) async {
          fail('Fresh disk cache must not request the network');
        }));
    final restored = await restarted.load(uri);
    expect(restored.title, 'Saved');
    expect(restored.imageUri.toString(), 'https://example.com/photo.jpg');
  });

  test(
      'stale metadata returns before refresh and a failed refresh keeps it usable',
      () async {
    final uri = Uri.parse('https://example.com/stale');
    final store = MemoryLocalCacheStore();
    await store.write(LocalCacheKeys.linkPreview(uri),
        const LinkPreviewData(title: 'Saved').toJson());
    final refresh = Completer<http.Response>();
    final repository = LinkPreviewRepository(
        cacheStore: store, client: MockClient((_) => refresh.future));
    await withClock(Clock.fixed(DateTime.now().add(const Duration(hours: 1))),
        () async {
      expect((await repository.load(uri)).title, 'Saved');
      expect(refresh.isCompleted, isFalse);
      refresh.complete(http.Response('offline', 503));
      await Future<void>.delayed(Duration.zero);
      expect(repository.cached(uri)!.title, 'Saved');
    });
  });

  test('only actual social post hosts and paths use official embeds', () {
    for (final url in [
      'https://x.com/a/status/123?s=20',
      'https://twitter.com/i/web/status/123',
      'https://x.com/i/status/123'
    ]) {
      expect(webLinkKind(Uri.parse(url)), WebLinkKind.x);
    }
    for (final url in [
      'https://www.instagram.com/p/Ab_cd-12/',
      'https://instagram.com/reel/Ab12/?igsh=abc'
    ]) {
      expect(webLinkKind(Uri.parse(url)), WebLinkKind.instagram);
    }
    for (final url in [
      'https://x.com.attacker.test/a/status/123',
      'https://x.com/a',
      'https://instagram.com/stories/a/123',
      'https://example.com'
    ]) {
      expect(webLinkKind(Uri.parse(url)), WebLinkKind.website);
    }
    expect(
        socialPostUri(Uri.parse('https://instagram.com/p/Ab12/?igsh=secret'))
            .toString(),
        'https://www.instagram.com/p/Ab12/');
  });

  test('cards replace URLs in place without moving surrounding paragraphs', () {
    final post = Post(
        postId: 1,
        teamId: 1,
        language: 'ko',
        userId: 1,
        category: PostCategory.general,
        title: 'Title',
        createdAt: '',
        body:
            '앞 문단\n\n첫 번째 https://x.com/a/status/123 그 다음\n\n문단\nwww.example.com/end\n마지막',
        attachments: const [
          PostAttachment(
              attachmentId: 1,
              position: 1,
              linkUrl: 'https://www.example.com/end')
        ]);
    final parts = communityPostParts(post);
    expect(parts.map((part) => part.text), [
      '앞 문단\n\n첫 번째',
      'https://x.com/a/status/123',
      '그 다음\n\n문단',
      'www.example.com/end',
      '마지막'
    ]);
    expect(parts.where((part) => part.uri != null).length, 2);
  });

  test(
      'fetches OG metadata without app credentials and decodes Korean/entities',
      () async {
    final repository =
        LinkPreviewRepository(client: MockClient((request) async {
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(request.headers.containsKey('cookie'), isFalse);
      return http.Response.bytes(
          utf8.encode('''<meta charset="utf-8"><title>Fallback</title>
        <meta property="og:title" content="축구 &amp; 분석">
        <meta property="og:image" content="/photo.jpg">
        <meta property="og:image" content="/second.jpg">'''), 200,
          headers: {'content-type': 'text/html; charset=utf-8'});
    }));
    final result =
        await repository.load(Uri.parse('https://example.com/article'));
    expect(result.title, '축구 & 분석');
    expect(result.imageUri.toString(), 'https://example.com/photo.jpg');
  });

  test('plain pages need no OG image and non-HTTP image schemes are ignored',
      () {
    final page = Uri.parse('https://example.com');
    expect(
        LinkPreviewData.fromHtml(utf8.encode('<title>Plain page</title>'), page)
            .title,
        'Plain page');
    expect(
        LinkPreviewData.fromHtml(
                utf8.encode(
                    '<meta property="og:image" content="javascript:alert(1)">'),
                page)
            .imageUri,
        isNull);
  });

  test('relative images follow the final page after a redirect', () async {
    final finalUri = Uri.parse('https://example.org/news/article');
    final repository = LinkPreviewRepository(client: _RedirectClient(finalUri));
    final data = await repository.load(Uri.parse('https://example.com/short'));
    expect(data.imageUri.toString(), 'https://example.org/news/photo.jpg');
  });

  test(
      'HTTP and non-HTML failures stay errors so the original URL remains usable',
      () async {
    for (final response in [
      http.Response('denied', 403),
      http.Response('%PDF', 200, headers: {'content-type': 'application/pdf'})
    ]) {
      final repository =
          LinkPreviewRepository(client: MockClient((_) async => response));
      await expectLater(
          repository.load(Uri.parse('https://example.com')), throwsA(anything));
    }
  });
}

class _RedirectedResponse extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _RedirectedResponse(Stream<List<int>> stream, this.url)
      : super(stream, 200, headers: {'content-type': 'text/html'});
  @override
  final Uri url;
}

class _RedirectClient extends http.BaseClient {
  _RedirectClient(this.uri);
  final Uri uri;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      _RedirectedResponse(
          Stream.value(
              utf8.encode('<meta property="og:image" content="photo.jpg">')),
          uri);
}
