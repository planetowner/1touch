import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/home/home_content_repository.dart';
import 'package:onetouch/data/home/home_content_service.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/models/home_content_item.dart';

void main() {
  test('loads a real YouTube highlight feed entry', () async {
    final service = HomeContentService(
      newsRepository: _NewsRepository(),
      languageCode: () => 'ko',
      client: MockClient((request) async {
        expect(request.url.host, 'www.youtube.com');
        return http.Response(_youtubeFeed, 200);
      }),
    );

    final items = await service.fetchHighlights(favoriteTeamId: 8);

    expect(items, hasLength(1));
    expect(items.single.title, contains('Liverpool 1-1 Brentford'));
    expect(items.single.source, 'Liverpool FC');
    expect(items.single.imageUrl, contains('hqdefault.jpg'));
    expect(items.single.destinationUrl, endsWith('Gf2DLAp_oXU'));
    service.dispose();
  });

  test('loads only the selected team through the news repository', () async {
    final news = _NewsRepository(items: const [
      HomeContentItem(title: '팀 기사', source: '공급자', timeLabel: '1시간 전')
    ]);
    final service = HomeContentService(
      newsRepository: news,
      languageCode: () => 'ko',
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );
    final content = await service.loadForTeam(83);
    expect(news.teamId, 83);
    expect(news.language, 'ko');
    expect(content.news, hasLength(1));
    expect(content.news.single.title, '팀 기사');
    expect(content.newsFailed, isFalse);
    service.dispose();
  });

  test('news failure preserves highlights without fabricating articles',
      () async {
    final service = HomeContentService(
      newsRepository: _NewsRepository(fail: true),
      languageCode: () => 'en',
      client: MockClient((_) async => http.Response(_youtubeFeed, 200)),
    );
    final content = await service.loadForTeam(8);
    expect(content.highlights.first.title, contains('Liverpool'));
    expect(content.news, isEmpty);
    expect(content.newsFailed, isTrue);
    service.dispose();
  });

  test('prioritizes favorite-team videos on home', () async {
    final service = HomeContentService(
      newsRepository: _NewsRepository(),
      languageCode: () => 'ko',
      client: MockClient((_) async => http.Response(_rankedYoutubeFeed, 200)),
    );

    final items = await service.fetchHighlights(
      favoriteTeamId: 8,
      limit: 1,
    );

    expect(items.single.title, contains('Liverpool'));
    service.dispose();
  });

  test('does not use an unrelated club feed for an unmapped team', () async {
    final service = HomeContentService(
      newsRepository: _NewsRepository(),
      languageCode: () => 'ko',
      client: MockClient((_) async {
        fail('No feed should be requested for an unmapped team');
      }),
    );

    expect(await service.fetchHighlights(favoriteTeamId: -1), isEmpty);
    service.dispose();
  });

  test('returns an empty list when a feed is unavailable', () async {
    final service = HomeContentService(
      newsRepository: _NewsRepository(),
      languageCode: () => 'ko',
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );

    expect(await service.fetchHighlights(favoriteTeamId: 8), isEmpty);
    service.dispose();
  });

  test(
      'repository load supplies immutable fallbacks when feeds are unavailable',
      () async {
    final service = HomeContentService(
      newsRepository: _NewsRepository(),
      languageCode: () => 'ko',
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );
    final HomeContentRepository repository = service;

    final content = await repository.loadForTeam(8);

    expect(content.highlights, hasLength(2));
    expect(content.news, isEmpty);
    expect(() => content.highlights.clear(), throwsUnsupportedError);
    expect(() => content.news.clear(), throwsUnsupportedError);
    service.dispose();
  });
}

const _youtubeFeed = '''
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <yt:videoId>Gf2DLAp_oXU</yt:videoId>
    <title>Highlights: Liverpool 1-1 Brentford</title>
    <author><name>Liverpool FC</name></author>
    <published>2026-05-24T21:00:11+00:00</published>
    <media:group>
      <media:thumbnail url="https://i4.ytimg.com/vi/Gf2DLAp_oXU/hqdefault.jpg" />
    </media:group>
  </entry>
</feed>
''';

const _rankedYoutubeFeed = '''
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <yt:videoId>unrelated_video</yt:videoId>
    <title>Inside Training: Finishing Drills</title>
    <author><name>Liverpool FC</name></author>
    <published>2026-05-25T21:00:11+00:00</published>
    <media:group>
      <media:thumbnail url="https://i4.ytimg.com/vi/unrelated_video/hqdefault.jpg" />
    </media:group>
  </entry>
  <entry>
    <yt:videoId>Gf2DLAp_oXU</yt:videoId>
    <title>Highlights: Liverpool 1-1 Brentford</title>
    <author><name>Liverpool FC</name></author>
    <published>2026-05-24T21:00:11+00:00</published>
    <media:group>
      <media:thumbnail url="https://i4.ytimg.com/vi/Gf2DLAp_oXU/hqdefault.jpg" />
    </media:group>
  </entry>
</feed>
''';

class _NewsRepository implements NewsRepository {
  _NewsRepository({this.items = const [], this.fail = false});
  final List<HomeContentItem> items;
  final bool fail;
  int? teamId;
  String? language;

  @override
  Future<List<HomeContentItem>> loadForTeam(int teamId,
      {required String language}) async {
    this.teamId = teamId;
    this.language = language;
    if (fail) throw StateError('offline');
    return items;
  }
}
