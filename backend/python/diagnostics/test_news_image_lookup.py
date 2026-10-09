"""원문이 차단된 공급자도 RSS 기사·이미지를 그대로 수집하는지 확인해요."""
from contextlib import redirect_stdout
from datetime import datetime, timezone
import io
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

import requests

from one_touch_loader.core.news import fingerprint, load_sources, parse_feed
from one_touch_loader.loaders import news_loader as loader


class NewsImageLookupTests(unittest.TestCase):
    def setUp(self):
        self.source = next(s for s in load_sources() if s['name'] == 'SempreInter.Com')
        self.feed = (Path(__file__).parent / 'fixtures/sempreinter_feed_metadata.xml').read_bytes()
        self.now = datetime(2026, 10, 9, 5, 25, tzinfo=timezone.utc)
        self.teams = [{'team_id': team_id} for team_id in (113, 398, 1628, 2930)]

    def session(self):
        session = Mock()

        def get(url, **kwargs):
            if url == self.source['feed_url']:
                return Mock(content=self.feed)
            response = requests.Response()
            response.status_code = 403
            response.url = url
            response.raise_for_status()

        session.get.side_effect = get
        return session

    def test_blocked_source_preserves_all_feed_articles_and_images_without_page_requests(self):
        original = parse_feed(self.feed, self.source)
        self.assertEqual(len(original), 20)
        self.assertEqual(sum(bool(row['image_url']) for row in original), 9)
        session = self.session()
        with patch.object(loader, 'save_sources'), patch.object(loader, 'save_articles') as save, \
                patch.object(loader, 'refresh_news_images', return_value={'prepared': 0, 'errors': []}):
            report = loader.refresh(apply=True, sources=[self.source], teams=self.teams,
                                    session=session, now=self.now)
        saved = save.call_args.args[1]
        self.assertEqual([{k: v for k, v in row.items() if k != 'team_ids'} for row in saved], original)
        self.assertEqual(report['sources'][0]['articles'], 20)
        self.assertIsNone(report['sources'][0]['error'])
        session.get.assert_called_once_with(self.source['feed_url'], timeout=20,
                                           headers={'User-Agent': '1Touch-News/1.0'})

    def test_unspecified_or_enabled_lookup_keeps_reporting_blocked_pages(self):
        for enabled in (None, True):
            with self.subTest(enabled=enabled):
                source = {k: v for k, v in self.source.items() if k != 'fetch_article_images'}
                if enabled is not None:
                    source['fetch_article_images'] = enabled
                session = self.session()
                report = loader.refresh(apply=False, sources=[source], teams=self.teams,
                                        session=session, now=self.now)
                self.assertEqual(report['sources'][0]['articles'], 20)
                self.assertEqual(report['sources'][0]['error'], 'HTTPError')
                self.assertEqual(session.get.call_count, 12)

    def test_disabled_page_lookup_does_not_hide_feed_errors(self):
        for error in (requests.HTTPError('feed unavailable'), requests.Timeout('feed timed out')):
            with self.subTest(error=type(error).__name__):
                session = Mock()
                session.get.side_effect = error
                report = loader.refresh(apply=False, sources=[self.source], teams=self.teams,
                                        session=session, now=self.now)
                self.assertEqual(report['sources'][0]['articles'], 0)
                self.assertEqual(report['sources'][0]['error'], type(error).__name__)
                with patch.object(loader, 'refresh', return_value=report), redirect_stdout(io.StringIO()):
                    with self.assertRaises(SystemExit) as raised:
                        loader.run_cli(['refresh', '--check'])
                self.assertEqual(raised.exception.code, 1)

    def test_check_does_not_write_and_cli_succeeds_for_feed_only_source(self):
        with patch.object(loader, 'current_teams', return_value=self.teams), \
                patch.object(loader, 'load_sources', return_value=[self.source]), \
                patch.object(loader.requests, 'Session', return_value=self.session()), \
                patch.object(loader, 'save_sources') as sources, patch.object(loader, 'save_articles') as articles, \
                patch.object(loader, 'refresh_news_images') as thumbnails, \
                patch.object(loader, 'datetime') as clock, redirect_stdout(io.StringIO()):
            clock.now.return_value = self.now
            loader.run_cli(['refresh', '--check'])
        sources.assert_not_called()
        articles.assert_not_called()
        thumbnails.assert_not_called()

    def test_only_verified_blocked_source_disables_page_lookup(self):
        self.assertEqual([s['key'] for s in load_sources() if not s.get('fetch_article_images', True)],
                         [self.source['key']])

    def test_http_failure_identifies_request_without_exposing_url_or_response(self):
        url = 'https://example.com/article?token=private-query'
        for status in (403, 404, 429, 503):
            with self.subTest(status=status):
                response = requests.Response()
                response.status_code = status
                response.url = url
                response.reason = 'private-reason'
                response._content = b'private-response-body'
                session = Mock()
                session.get.return_value = response
                with self.assertLogs(loader.__name__, level='WARNING') as logs:
                    with self.assertRaises(requests.HTTPError) as raised:
                        loader._get_content(session, url)
                self.assertIs(raised.exception.response, response)
                self.assertEqual(len(logs.output), 1)
                self.assertIn(f'status={status}', logs.output[0])
                self.assertIn(f'url_hash={fingerprint(url)}', logs.output[0])
                for private_value in (url, 'private-query', 'private-reason', 'private-response-body'):
                    self.assertNotIn(private_value, logs.output[0])

    def test_successful_request_returns_content_without_warning(self):
        response = requests.Response()
        response.status_code = 200
        response._content = b'<html>article</html>'
        session = Mock()
        session.get.return_value = response
        with self.assertNoLogs(loader.__name__, level='WARNING'):
            self.assertEqual(loader._get_content(session, 'https://example.com/article'), response.content)

    def test_read_timeout_identifies_request_and_preserves_exception_without_retry(self):
        url = 'https://example.com/article?token=private-query'
        error = requests.ReadTimeout('private timeout details: ' + url)
        session = Mock()
        session.get.side_effect = error
        with patch('time.monotonic', side_effect=[10.0, 30.125]), \
                self.assertLogs(loader.__name__, level='WARNING') as logs:
            with self.assertRaises(requests.ReadTimeout) as raised:
                loader._get_content(session, url)
        self.assertIs(raised.exception, error)
        session.get.assert_called_once_with(url, timeout=20, headers={'User-Agent': '1Touch-News/1.0'})
        self.assertEqual(len(logs.output), 1)
        self.assertIn('error=ReadTimeout', logs.output[0])
        self.assertIn('elapsed_seconds=20.125', logs.output[0])
        self.assertIn(f'url_hash={fingerprint(url)}', logs.output[0])
        for private_value in (url, 'private-query', 'private timeout details'):
            self.assertNotIn(private_value, logs.output[0])


if __name__ == '__main__':
    unittest.main()
