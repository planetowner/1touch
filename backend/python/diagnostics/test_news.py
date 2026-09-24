"""팀·언어·기간 경계와 수집 실패를 운영 DB 변경 없이 검증해요."""
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import unittest
from unittest.mock import MagicMock, Mock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from one_touch_loader.core.news import (
    ALIASES_PATH, NEWS_MAX_AGE, TeamNewsMatcher, canonical_url, load_sources,
    news_language, parse_article_page, parse_feed, select_news,
)
from one_touch_loader.loaders import news_loader as loader

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api.repos import news_repo
    from one_touch_loader.api.routes import teams as team_routes

NOW = datetime(2026, 9, 19, 18, tzinfo=timezone.utc)
SOURCE = {"key": "sample", "name": "테스트 공급자", "language": "ko", "timezone": "Asia/Seoul",
          "is_active": True, "feed_url": "https://example.com/feed", "competition_ids": [8]}


def article(key, *, age=0, language="ko", title=None):
    return {"article_id": key, "title": title or f"기사 {key}", "source": "공급자", "language": language,
            "url": f"https://example.com/articles/{key}", "image_url": None,
            "published_at": NOW - timedelta(days=age), "categories": []}


class SelectionTests(unittest.TestCase):
    def test_latest_three_sorted_by_publication_and_not_collected_time(self):
        rows = [article(i, age=i) for i in range(5)]
        self.assertEqual([a["article_id"] for a in select_news(rows[::-1], language="ko", now=NOW)], [0, 1, 2])

    def test_fourteen_day_boundary_future_and_language(self):
        boundary = article(1, age=14)
        old = {**article(2), "published_at": NOW - NEWS_MAX_AGE - timedelta(microseconds=1)}
        self.assertEqual(select_news([old, article(3, age=-1), article(4, language="en"), boundary],
                                    language="ko", now=NOW), [boundary])

    def test_empty_and_short_lists_are_not_padded(self):
        self.assertEqual(select_news([], language="ko", now=NOW), [])
        self.assertEqual(len(select_news([article(1)], language="ko", now=NOW)), 1)

    def test_title_and_tracking_url_duplicates_do_not_consume_slots(self):
        first = article(1, title="Arsenal  Transfer")
        duplicate_title = article(2, title="arsenal transfer")
        duplicate_url = {**article(3), "url": first["url"] + "?utm_source=feed#story"}
        selected = select_news([first, duplicate_title, duplicate_url, article(4)], language="ko", now=NOW)
        self.assertEqual(len(selected), 3)
        # 순서와 관계없이 같은 제목 또는 URL을 함께 표시하지 않아요.
        self.assertEqual(len({canonical_url(a['url']) for a in selected}), len(selected))
        self.assertEqual(canonical_url('https://example.com/article?idxno=123&utm_source=rss'),
                         'https://example.com/article?idxno=123')

    def test_locale_policy(self):
        for locale in ("ko", "ko-KR", "KO_kr"):
            self.assertEqual(news_language(locale), "ko")
        for locale in ("en", "zh", "ja", "fr"):
            self.assertEqual(news_language(locale), "en")


class FeedTests(unittest.TestCase):
    def test_euc_kr_and_numeric_publication_formats(self):
        cases = [('20260921013544+0900', '%Y%m%d%H%M%S%z', datetime(2026, 9, 20, 16, 35, 44, tzinfo=timezone.utc)),
                 ('Sun, 20 09 2026 23:10:46 +0900', '%a, %d %m %Y %H:%M:%S %z',
                  datetime(2026, 9, 20, 14, 10, 46, tzinfo=timezone.utc))]
        for value, date_format, expected in cases:
            feed = f'''<?xml version="1.0" encoding="euc-kr"?><rss><channel><language>ko</language><item>
              <title>바르셀로나 경기 소식</title><link>https://example.com/1</link>
              <pubDate>{value}</pubDate></item></channel></rss>'''.encode('euc-kr')
            with self.subTest(date_format=date_format):
                row, = parse_feed(feed, {**SOURCE, 'date_format': date_format})
                self.assertEqual(row['title'], '바르셀로나 경기 소식')
                self.assertEqual(row['published_at'], expected)

    def test_dublin_core_date_and_configured_local_timezone(self):
        for value in ('2026-09-21T01:16:00+09:00', '2026-09-21 01:16:00'):
            feed = f'''<rss xmlns:dc="http://purl.org/dc/elements/1.1/"><channel><item>
              <title>맨시티 소식</title><link>https://example.com/1</link>
              <dc:date>{value}</dc:date></item></channel></rss>'''.encode()
            with self.subTest(value=value):
                row, = parse_feed(feed, SOURCE)
                self.assertEqual(row['published_at'], datetime(2026, 9, 20, 16, 16, tzinfo=timezone.utc))

    def test_confirmed_feed_language_metadata_exception_is_source_specific(self):
        feed = b'''<rss><channel><language>de</language><item><title>Bayern sign a player</title>
          <link>https://example.com/1</link><pubDate>Sun, 20 Sep 2026 16:18:46 +0000</pubDate>
          </item></channel></rss>'''
        with self.assertRaises(ValueError):
            parse_feed(feed, {**SOURCE, 'language': 'en'})
        row, = parse_feed(feed, {**SOURCE, 'language': 'en', 'feed_language': 'de'})
        self.assertEqual(row['language'], 'en')

    def test_news_sitemap_uses_publication_date_and_filters_language(self):
        feed = '''<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
          xmlns:news="http://www.google.com/schemas/sitemap-news/0.9">
          <url><loc>https://example.com/1?utm_source=feed</loc><lastmod>2026-09-21</lastmod><news:news>
            <news:publication><news:name>공급자</news:name><news:language>ko</news:language></news:publication>
            <news:publication_date>2026-09-20T22:00:00+09:00</news:publication_date>
            <news:title>맨시티 경기 소식</news:title><news:keywords>바르셀로나, 뮌헨</news:keywords>
          </news:news></url>
          <url><loc>https://example.com/2</loc><lastmod>2026-09-21</lastmod></url>
          <url><loc>https://example.com/3</loc><news:news>
            <news:publication><news:language>fr</news:language></news:publication>
            <news:publication_date>2026-09-20T23:00:00+09:00</news:publication_date>
            <news:title>Barcelona</news:title></news:news></url></urlset>'''.encode()
        row, = parse_feed(feed, {**SOURCE, 'format': 'news_sitemap'})
        self.assertEqual(row['published_at'], datetime(2026, 9, 20, 13, tzinfo=timezone.utc))
        self.assertEqual(row['url'], 'https://example.com/1')
        self.assertEqual(row['categories'], [])

    def test_articles_with_unreadable_dates_are_reported_as_failure(self):
        feed = b'''<rss><channel><item><title>Barcelona</title><link>https://example.com/1</link>
          <pubDate>unknown</pubDate></item></channel></rss>'''
        with self.assertRaises(ValueError):
            parse_feed(feed, SOURCE)
        self.assertEqual(parse_feed(b'<rss><channel/></rss>', SOURCE), [])

    def test_html_article_metadata_preserves_publication_time_and_not_body(self):
        page = '''<html lang="ko"><head><meta property="og:title" content="맨시티 &amp; 바르셀로나">
          <meta property="article:published_time" content="2026-09-20T22:00:00+09:00">
          <meta property="article:modified_time" content="2026-09-21T01:00:00+09:00">
          <meta property="og:image" content="https://example.com/image.jpg"></head><body>기사 본문</body></html>'''.encode()
        row = parse_article_page(page, SOURCE, 'https://example.com/1')
        self.assertEqual(row['published_at'], datetime(2026, 9, 20, 13, tzinfo=timezone.utc))
        self.assertEqual(row['title'], '맨시티 & 바르셀로나')
        self.assertEqual(row['image_url'], 'https://example.com/image.jpg')
        self.assertNotIn('body', row)
        self.assertNotIn('description', row)
        with self.assertRaises(ValueError):
            parse_article_page(page.replace(b'lang="ko"', b'lang="fr"'), SOURCE, 'https://example.com/1')

    def test_korean_datetime_and_description_image(self):
        feed = '''<rss><channel><language>ko</language><item>
          <title>토트넘 &amp; 아스널</title><link>https://example.com/a?idxno=1&amp;utm_source=feed</link>
          <pubDate>2026-09-20 01:00:00</pubDate>
          <description><![CDATA[<img src="https://example.com/photo.jpg">본문]]></description>
        </item></channel></rss>'''.encode()
        item, = parse_feed(feed, SOURCE)
        self.assertEqual(item['published_at'], datetime(2026, 9, 19, 16, tzinfo=timezone.utc))
        self.assertEqual(item['image_url'], 'https://example.com/photo.jpg')
        self.assertEqual(item['url'], 'https://example.com/a?idxno=1')
        self.assertNotIn('description', item)

    def test_namespaced_image_missing_image_and_invalid_time(self):
        feed = b'''<rss xmlns:media="http://search.yahoo.com/mrss/"><channel><item>
          <title>Arsenal news</title><link>https://example.com/1</link>
          <pubDate>Sat, 19 Sep 2026 18:00:00 GMT</pubDate><category>Arsenal</category>
          <media:group><media:content url="https://example.com/img.jpg" type="image/jpeg" /></media:group>
        </item><item><title>No image</title><link>https://example.com/2</link>
          <pubDate>Sat, 19 Sep 2026 17:00:00 GMT</pubDate></item>
        <item><title>No date</title><link>https://example.com/3</link></item></channel></rss>'''
        items = parse_feed(feed, {**SOURCE, 'language': 'en'})
        self.assertEqual(len(items), 2)
        self.assertEqual(items[0]['image_url'], 'https://example.com/img.jpg')
        self.assertIsNone(items[1]['image_url'])
        self.assertEqual(items[0]['categories'], ['Arsenal'])

    def test_wrong_feed_language_is_not_accepted(self):
        with self.assertRaises(ValueError):
            parse_feed(b'<rss><channel><language>fr</language></channel></rss>', {**SOURCE, 'language': 'en'})

    def test_team_aliases_and_no_player_or_other_team_fallback(self):
        aliases = json.loads(ALIASES_PATH.read_text(encoding='utf-8'))['teams']
        teams = [{'team_id': i, 'competition_id': league} for i, league in [(6, 8), (14, 8), (591, 301), (4508, 301), (2930, 384)]]
        matcher = TeamNewsMatcher(teams, aliases)
        self.assertEqual(matcher.match(article(1, title='토트넘은 맨유와 맞붙는다')), [6, 14])
        self.assertEqual(matcher.match(article(1, title='선수의 이적 소식')), [])
        self.assertEqual(matcher.match(article(1, title='PSG sign a player', language='en')), [591])
        self.assertEqual(matcher.match(article(1, title='Paris FC sign a player', language='en')), [4508])
        self.assertEqual(matcher.match(article(1, title='Inter Miami sign a player', language='en')), [])
        tagged = {**article(1, title='토트넘 소식'), 'categories': ['맨유']}
        self.assertEqual(matcher.match(tagged), [6])
        self.assertEqual(matcher.match({**article(1), 'categories': ['토트넘', '맨유']}), [])


class TeamMatchingRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((Path(__file__).parent / 'fixtures/news_team_matching.json').read_text(encoding='utf-8'))
        cls.aliases = json.loads(ALIASES_PATH.read_text(encoding='utf-8'))['teams']
        cls.matcher = TeamNewsMatcher(cls.fixture['teams'], cls.aliases)

    def test_audited_article_titles_and_tags(self):
        for row in self.fixture['articles']:
            with self.subTest(article_id=row['snapshot_article_id'], title=row['title']):
                self.assertEqual(sorted(self.matcher.match(row)), row['expected_team_ids'])

    def test_registered_names_for_all_current_teams(self):
        self.assertEqual(len(self.fixture['teams']), 96)
        for team in self.fixture['teams']:
            saved = self.aliases[str(team['team_id'])]
            for language in ('ko', 'en'):
                for term in saved[language]:
                    # Nice는 형용사와 구분할 태그가 있어야 짧은 구단명으로 사용할 수 있어요.
                    categories = [term] if term in saved.get('title_requires_category', []) else []
                    with self.subTest(team_id=team['team_id'], term=term):
                        self.assertEqual(self.matcher.match({'title': term, 'language': language,
                                                             'categories': categories}), [team['team_id']])

    def test_long_names_do_not_match_a_different_club_inside_them(self):
        cases = [
            ('Inter Milan sign a defender', [2930]),
            ('인테르 밀란의 이적 소식', [2930]),
            ('RCD Espanyol de Barcelona sign a player', [528]),
            ('Deportivo Alavés sign a player', [2975]),
            ('보루시아 뮌헨글라트바흐 소식', [683]),
            ('보루시아 뮌헨글라드바흐 소식', [683]),
            ('Inter Milan face AC Milan', [113, 2930]),
            ('RCD Espanyol de Barcelona face Barcelona', [83, 528]),
            ('보루시아 뮌헨글라트바흐와 뮌헨의 경기', [503, 683]),
        ]
        for title, expected in cases:
            with self.subTest(title=title):
                self.assertEqual(sorted(self.matcher.match(article(1, title=title))), expected)

    def test_ambiguous_phrases_do_not_select_an_unrelated_team(self):
        for title in ('선수의 리즈 시절을 돌아본다', '리즈시절의 활약',
                      'Inter Miami sign a player', 'Villa Valle sign a player',
                      'A very nice evening', 'Nice evening'):
            with self.subTest(title=title):
                self.assertEqual(self.matcher.match(article(1, title=title)), [])
        self.assertEqual(self.matcher.match({**article(1, title='Inter Miami sign a player'),
                                             'categories': ['Inter']}), [])
        self.assertEqual(self.matcher.match(article(1, title='리즈가 영입한 선수의 리즈 시절')), [71])
        self.assertEqual(self.matcher.match(article(1, title='Inter face Inter Miami')), [2930])
        self.assertEqual(self.matcher.match(article(1, title='OGC Nice sign a player')), [450])
        self.assertEqual(self.matcher.match({**article(1, title='Nice sign a player'),
                                             'categories': ['OGC Nice']}), [450])

    def test_korean_particles_mixed_names_and_word_boundaries(self):
        cases = [('PSG는 인테르와 맞붙는다', [591, 2930]),
                 ('맨체스터 유나이티드vs리버풀', [8, 14]),
                 ('뮌헨글라트바흐 소식', []), ('그리즈만 소식', []),
                 ('Liverpoolian perspective', []), ('Parish news', [])]
        for title, expected in cases:
            with self.subTest(title=title):
                self.assertEqual(sorted(self.matcher.match(article(1, title=title))), expected)


class LoaderTests(unittest.TestCase):
    def test_missing_feed_images_use_article_metadata_without_replacing_feed_fields(self):
        feeds = {
            'rss': '''<rss><channel><item><title>바르셀로나 경기 소식</title>
              <link>https://example.com/1</link><pubDate>Sat, 19 Sep 2026 17:00:00 GMT</pubDate>
              </item></channel></rss>''',
            'news_sitemap': '''<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
              xmlns:news="http://www.google.com/schemas/sitemap-news/0.9">
              <url><loc>https://example.com/1</loc><news:news>
                <news:publication><news:language>ko</news:language></news:publication>
                <news:publication_date>2026-09-19T17:00:00Z</news:publication_date>
                <news:title>바르셀로나 경기 소식</news:title>
              </news:news></url></urlset>''',
        }
        # 마이데일리 원문처럼 발행 시각이 없어도 피드의 제목·시각을 그대로 사용해요.
        page = b'''<html lang="ko"><meta property="og:title" content="Different title">
          <meta property="og:image" content="https://example.com/photo.jpg"></html>'''
        for feed_format, feed in feeds.items():
            with self.subTest(feed_format=feed_format):
                source = {**SOURCE, 'format': feed_format}
                original, = parse_feed(feed.encode(), source)
                session = Mock()
                session.get.side_effect = [Mock(content=feed.encode()), Mock(content=page)]
                with patch.object(loader, 'save_sources'), patch.object(loader, 'save_articles') as save:
                    report = loader.refresh(apply=True, sources=[source],
                                            teams=[{'team_id': 83}], session=session, now=NOW)
                saved, = save.call_args.args[1]
                self.assertEqual(saved, {**original, 'image_url': 'https://example.com/photo.jpg', 'team_ids': [83]})
                self.assertIsNone(report['sources'][0]['error'])
                self.assertEqual([call.args[0] for call in session.get.call_args_list],
                                 [SOURCE['feed_url'], 'https://example.com/1'])

    def test_image_requests_skip_existing_images_unmatched_articles_and_dates_outside_window(self):
        rows = [{**article(1, title='바르셀로나'), 'image_url': 'https://example.com/existing.jpg'},
                article(2, title='다른 소식'), article(3, age=15, title='바르셀로나'),
                article(4, age=-1, title='바르셀로나')]
        session = Mock()
        with patch.object(loader, 'read_source', return_value=rows), \
                patch.object(loader, 'save_sources'), patch.object(loader, 'save_articles') as save:
            loader.refresh(apply=True, sources=[SOURCE], teams=[{'team_id': 83}], session=session, now=NOW)
        session.get.assert_not_called()
        self.assertEqual([row['article_id'] for row in save.call_args.args[1]], [1, 2])
        self.assertEqual(save.call_args.args[1][0]['image_url'], 'https://example.com/existing.jpg')

    def test_html_articles_are_not_fetched_again_when_the_original_has_no_image(self):
        source = {**SOURCE, 'format': 'html', 'article_selector': '.news a[href]'}
        listing = b'<div class="news"><a href="/1">Article</a></div>'
        page = '''<html lang="ko"><meta property="og:title" content="바르셀로나 소식">
          <meta property="article:published_time" content="2026-09-19T17:00:00Z"></html>'''.encode()
        session = Mock()
        session.get.side_effect = [Mock(content=listing), Mock(content=page)]
        report = loader.refresh(apply=False, sources=[source], teams=[{'team_id': 83}], session=session, now=NOW)
        self.assertEqual(session.get.call_count, 2)
        self.assertEqual(report['sources'][0]['matched'], 1)
        self.assertIsNone(report['sources'][0]['error'])

    def test_image_request_failure_keeps_the_article_and_continues_the_source(self):
        rows = [article(1, title='바르셀로나 소식'), article(2, title='바르셀로나 경기')]
        page = b'<meta name="og:image" content="https://example.com/photo.jpg">'
        for response in (loader.requests.Timeout(), Mock(content=b'<html lang="ko">No image</html>')):
            with self.subTest(response=response):
                session = Mock()
                session.get.side_effect = [response, Mock(content=page)]
                with patch.object(loader, 'read_source', return_value=rows), \
                        patch.object(loader, 'save_sources'), patch.object(loader, 'save_articles') as save:
                    report = loader.refresh(apply=True, sources=[SOURCE], teams=[{'team_id': 83}], session=session, now=NOW)
                saved = save.call_args.args[1]
                self.assertEqual(len(saved), 2)
                self.assertIsNone(saved[0]['image_url'])
                self.assertEqual(saved[1]['image_url'], 'https://example.com/photo.jpg')
                self.assertEqual(report['sources'][0]['error'], 'Timeout' if isinstance(response, Exception) else None)

    def test_shared_html_reader_deduplicates_links_and_uses_configured_selector(self):
        source = {**SOURCE, 'format': 'html', 'article_selector': '.news a[href]'}
        listing = b'''<div class="news"><a href="/1">Title</a><a href="/1">Image</a></div>
          <aside><a href="/unrelated">Other</a></aside>'''
        page = b'''<html lang="ko"><meta property="og:title" content="Barcelona">
          <meta property="article:published_time" content="2026-09-20T22:00:00+09:00"></html>'''
        session = Mock()
        session.get.side_effect = [Mock(content=listing), Mock(content=page)]
        rows = loader.read_source(session, source)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['url'], 'https://example.com/1')
        self.assertEqual(session.get.call_count, 2)

    def test_empty_html_list_is_a_source_failure_and_does_not_write(self):
        session = Mock()
        session.get.return_value.content = b'<html><body>No article list</body></html>'
        source = {**SOURCE, 'format': 'html', 'article_selector': '.news a[href]'}
        with patch.object(loader, 'save_articles') as save:
            report = loader.refresh(apply=False, sources=[source], teams=[], session=session, now=NOW)
        self.assertEqual(report['sources'][0]['error'], 'ValueError')
        save.assert_not_called()

    def test_cross_league_title_is_matched_through_refresh(self):
        session = Mock()
        session.get.return_value.content = '''<rss><channel><language>ko</language><item>
          <title>바르사, 토트넘과 맞붙는다</title><link>https://example.com/cross-league</link>
          <pubDate>Sat, 19 Sep 2026 17:00:00 GMT</pubDate>
        </item></channel></rss>'''.encode()
        teams = [{'team_id': 6, 'competition_id': 8}, {'team_id': 83, 'competition_id': 564}]
        report = loader.refresh(apply=False, sources=[SOURCE], teams=teams, session=session, now=NOW)
        self.assertEqual(report['sources'][0]['team_ids'], [6, 83])
        self.assertIsNone(report['sources'][0]['error'])

    def test_check_is_read_only_and_source_failures_are_separate(self):
        session = Mock()
        good = Mock(content=b'<rss><channel/></rss>')
        bad = Mock(content=b'<html>not RSS</html>')
        session.get.side_effect = [bad, good]
        with patch.object(loader, 'save_sources') as sources, patch.object(loader, 'save_articles') as save:
            report = loader.refresh(apply=False, sources=[SOURCE, {**SOURCE, 'key': 'second'}],
                                    teams=[], session=session, now=NOW)
            sources.assert_not_called()
            save.assert_not_called()
        self.assertIsNotNone(report['sources'][0]['error'])
        self.assertIsNone(report['sources'][1]['error'])

    def test_source_catalog_preserves_all_candidates_without_enabling_unknown_urls(self):
        sources = load_sources()
        self.assertEqual(len(sources), 54)
        self.assertTrue(all(s['feed_url'] for s in sources if s['is_active']))
        self.assertEqual({s['language'] for s in sources if s['is_active']}, {'ko', 'en'})
        self.assertEqual({c for s in sources if s['is_active'] for c in s['competition_ids']}, {8, 82, 301, 384, 564})

    def test_apply_stores_actual_team_links_and_failure_does_not_delete_articles(self):
        from one_touch_loader.core import db
        transaction = MagicMock()
        cursor = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
        cursor.lastrowid = 27
        saved = {**article(1), 'url_hash': 'a' * 64, 'team_ids': [6, 14]}
        with patch.object(db, 'transaction', transaction):
            loader.save_articles(SOURCE, [saved], NOW, None)
        self.assertIn('image_url=COALESCE(VALUES(image_url), image_url)', cursor.execute.call_args_list[0].args[0])
        self.assertEqual(cursor.executemany.call_args.args[1], [(27, 6), (27, 14)])
        cursor.reset_mock()
        with patch.object(db, 'transaction', transaction):
            loader.save_articles(SOURCE, [], NOW, 'Timeout')
        self.assertEqual(cursor.execute.call_count, 1)
        self.assertIn('UPDATE news_sources', cursor.execute.call_args.args[0])


class ApiTests(unittest.TestCase):
    def test_repository_uses_team_language_window_and_serializes_utc(self):
        with patch.object(news_repo, 'fetch_all_dict', return_value=[{**article(1), 'published_at': NOW.replace(tzinfo=None)}]) as fetch, \
                patch.object(news_repo, 'datetime') as clock:
            clock.now.return_value = NOW
            result = news_repo.get_team_news(83, 'ko-KR')
        params = fetch.call_args.args[1]
        self.assertEqual(params[:2], (83, 'ko'))
        self.assertEqual(params[2], (NOW - NEWS_MAX_AGE).replace(tzinfo=None))
        self.assertEqual(result['items'][0]['published_at'].utcoffset(), timedelta(0))

    def test_route_auth_missing_team_and_response_contract(self):
        app = FastAPI()
        app.include_router(team_routes.router, prefix='/v1')
        app.dependency_overrides[team_routes.get_user_id] = lambda: 1
        client = TestClient(app)
        payload = {'team_id': 83, 'language': 'ko', 'items': [article(1)]}
        with patch.object(team_routes, 'get_team', return_value={'team_id': 83}), \
                patch.object(team_routes, 'get_team_news', return_value=payload) as get_news:
            response = client.get('/v1/teams/83/news?language=ko')
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()['items'][0]['published_at'], '2026-09-19T18:00:00Z')
            get_news.assert_called_once_with(83, 'ko')
        with patch.object(team_routes, 'get_team', return_value=None):
            self.assertEqual(client.get('/v1/teams/999/news').status_code, 404)
        app.dependency_overrides.clear()
        self.assertEqual(client.get('/v1/teams/83/news').status_code, 401)


if __name__ == '__main__':
    unittest.main()
