import unittest
from unittest.mock import Mock, patch

from diagnostics import backfill_fixture_event_injured as job
from diagnostics import test_fixture_details as detail_tests
from one_touch_loader.loaders import fixture_details_loader as details


class FixtureEventInjuryBackfillTests(unittest.TestCase):
    setUp = detail_tests.FixtureDetailsStorageTests.setUp
    tearDown = detail_tests.FixtureDetailsStorageTests.tearDown

    def test_only_fills_matching_unknown_injury_values(self):
        payload = detail_tests._payload()
        goal = payload['events'][0]
        payload['events'] = [goal] + [
            dict(goal, id=event_id, type_id=18,
                 type={'id': 18, 'code': 'substitution', 'name': 'Substitution'})
            for event_id in range(901, 906)
        ]
        details.replace_fixture_detail_rows(500, details._normalize_fixture_details(payload, 500), payload['lineups'])
        original = self.connection.execute('SELECT * FROM fixture_events ORDER BY event_id').fetchall()
        source = dict(payload, events=[goal] + [
            dict(payload['events'][1], id=event_id, injured=injured)
            for event_id, injured in ((901, True), (902, False), (903, None), (904, True))
        ])

        def fetch(sql, params):
            return self.connection.execute(sql.replace('%s', '?'), params).fetchall()

        def provider(ids, *, include):
            self.assertEqual((ids, include), ([500], 'events'))
            return [source]

        with patch.object(job, 'fetch_all', side_effect=fetch), \
                patch.object(job, 'SportmonksClient') as client, patch('builtins.print'):
            client.return_value.get_fixtures_batch.side_effect = provider
            client.return_value.request_count = 1
            preview = job.backfill(apply=False, fixture_ids=[500])
            self.assertEqual(self.connection.execute('SELECT * FROM fixture_events ORDER BY event_id').fetchall(), original)
            self.assertEqual((preview['source_true'], preview['source_false'], preview['source_null']), (2, 1, 1))
            self.assertEqual(preview['missing_events'], [{'fixture_id': 500, 'event_id': 905}])

            def refreshed_provider(ids, *, include):
                # 원본 조회 중 라이브 저장이 먼저 끝난 상황이에요.
                self.connection.execute('UPDATE fixture_events SET injured=0 WHERE event_id=904')
                self.connection.commit()
                return provider(ids, include=include)

            client.return_value.get_fixtures_batch.side_effect = refreshed_provider
            result = job.backfill(apply=True)
        stored = self.connection.execute('SELECT * FROM fixture_events ORDER BY event_id').fetchall()
        self.assertEqual([row[:-1] for row in stored], [row[:-1] for row in original])
        self.assertEqual([row[-1] for row in stored], [None, 1, 0, None, 0, None])
        self.assertEqual(result['updated'], 2)

    def test_batches_use_existing_fifty_fixture_lookup(self):
        client = Mock(request_count=2)
        client.get_fixtures_batch.side_effect = lambda ids, **kwargs: [
            {'id': fid, 'events': [{'id': fid, 'type_id': 18, 'injured': None}]} for fid in ids]
        with patch.object(job, 'fetch_all', return_value=[(fid, fid, 18) for fid in range(1, 52)]), \
                patch.object(job, 'SportmonksClient', return_value=client), \
                patch.object(job, 'transaction') as write, patch('builtins.print'):
            result = job.backfill(apply=False)
        self.assertEqual([len(call.args[0]) for call in client.get_fixtures_batch.call_args_list], [50, 1])
        self.assertEqual((result['fixtures'], result['source_null'], result['missing_events']), (51, 51, []))
        write.assert_not_called()
