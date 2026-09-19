"""팀·언어·기간 경계와 수집 실패를 운영 DB 변경 없이 검증해요."""
from datetime import datetime, timedelta, timezone
import json
import unittest
from unittest.mock import MagicMock, Mock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from one_touch_loader.core.news import (
    ALIASES_PATH, NEWS_MAX_AGE, TeamNewsMatcher, canonical_url, load_sources,
    news_language, parse_feed, select_news,
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
        self.assertEqual(matcher.match({**article(1, title='토트넘은 맨유와 맞붙는다')}, [8]), [6, 14])
        self.assertEqual(matcher.match({**article(1, title='선수의 이적 소식')}, [8]), [])
        self.assertEqual(matcher.match({**article(1, title='PSG sign a player', language='en')}, [301]), [591])
        self.assertEqual(matcher.match({**article(1, title='Paris FC sign a player', language='en')}, [301]), [4508])
        self.assertEqual(matcher.match({**article(1, title='Inter Miami sign a player', language='en')}, [384]), [])
        self.assertEqual(matcher.match({**article(1, title='토트넘 소식')}, [564]), [])
        tagged = {**article(1, title='토트넘 소식'), 'categories': ['맨유']}
        self.assertEqual(matcher.match(tagged, [8]), [6])
        self.assertEqual(matcher.match({**article(1), 'categories': ['토트넘', '맨유']}, [8]), [])


class LoaderTests(unittest.TestCase):
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
