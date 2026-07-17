import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/home_content_service.dart';

void main() {
  test('loads a real YouTube highlight feed entry', () async {
    final service = HomeContentService(
      random: Random(1),
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

  test('loads and parses BBC football news', () async {
    final service = HomeContentService(
      random: Random(1),
      client: MockClient((request) async {
        expect(request.url.host, 'feeds.bbci.co.uk');
        return http.Response(_bbcFeed, 200);
      }),
    );

    final items = await service.fetchNews();

    expect(items, hasLength(1));
    expect(items.single.title, 'A real football story');
    expect(items.single.source, 'BBC Sport');
    expect(items.single.imageUrl, contains('football.jpg'));
    expect(items.single.destinationUrl, 'https://www.bbc.co.uk/sport/story');
    service.dispose();
  });

  test('loads a highlight for either team in a past match', () async {
    final service = HomeContentService(
      random: Random(1),
      client: MockClient((request) async {
        expect(request.url.host, 'www.youtube.com');
        return http.Response(_rankedYoutubeFeed, 200);
      }),
    );

    final item = await service.fetchMatchHighlight(
      homeTeamId: 8,
      awayTeamId: 236,
    );

    expect(item, isNotNull);
    expect(item!.title, contains('Liverpool 1-1 Brentford'));
    expect(item.destinationUrl, endsWith('Gf2DLAp_oXU'));
    service.dispose();
  });

  test('prioritizes favorite-team videos on home', () async {
    final service = HomeContentService(
      random: Random(1),
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
      client: MockClient((_) async {
        fail('No feed should be requested for an unmapped team');
      }),
    );

    expect(await service.fetchHighlights(favoriteTeamId: -1), isEmpty);
    expect(
      await service.fetchMatchHighlight(homeTeamId: -1, awayTeamId: -2),
      isNull,
    );
    service.dispose();
  });

  test('returns an empty list when a feed is unavailable', () async {
    final service = HomeContentService(
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );

    expect(await service.fetchNews(), isEmpty);
    expect(await service.fetchHighlights(favoriteTeamId: 8), isEmpty);
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

const _bbcFeed = '''
<rss xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
  <channel>
    <item>
      <title>A real football story</title>
      <link>https://www.bbc.co.uk/sport/story</link>
      <pubDate>Thu, 16 Jul 2026 19:54:48 GMT</pubDate>
      <media:thumbnail url="https://ichef.bbci.co.uk/football.jpg" />
    </item>
  </channel>
</rss>
''';
