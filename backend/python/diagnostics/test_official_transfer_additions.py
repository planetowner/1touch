"""누락된 공식 이동의 조회 범위와 공급자 원문 병합을 확인해요."""
import json
import unittest
from copy import deepcopy
from datetime import date
from pathlib import Path
from unittest.mock import Mock

from one_touch_loader.core.sportmonks import SportmonksClient

SOURCE = json.loads((Path(__file__).parent / 'fixtures/sportmonks_missing_transfers_20261016.json').read_text())['players']
LOAN_ID = 8_000_000_000_000_001
ARRIVAL_ID = 8_000_000_000_000_002


class OfficialTransferAdditionsTests(unittest.TestCase):
    def setUp(self):
        self.client = SportmonksClient.__new__(SportmonksClient)
        self.client._iter_paginated_data = Mock(return_value=[])
        self.client._get = Mock(side_effect=AssertionError('Unexpected provider request'))

    def test_player_team_and_date_queries_share_the_same_additions(self):
        for pid, tid, team_id in ((37652834, LOAN_ID, 3114), (37707501, ARRIVAL_ID, 5071)):
            with self.subTest(pid=pid):
                expected = self.client.get_transfer(tid)
                self.assertEqual(list(self.client.iter_transfers_by_player(pid)), [expected])
                self.assertEqual(list(self.client.iter_transfers_by_team(team_id)), [expected])
                results = list(self.client.iter_transfers_between_dates(date(2026, 9, 1), date(2026, 9, 1)))
                self.assertIn(expected, results)
                self.assertEqual({x['id'] for x in results}, {LOAN_ID, ARRIVAL_ID})
        self.assertEqual([x['id'] for x in self.client.iter_transfers_by_team(3543)], [LOAN_ID])
        self.assertEqual(list(self.client.iter_transfers_by_player(4313)), [])
        self.assertEqual(list(self.client.iter_transfers_by_team(676)), [])
        self.assertEqual(list(self.client.iter_transfers_between_dates(date(2026, 7, 1), date(2026, 8, 31))), [])
        self.assertEqual(list(self.client.iter_transfers_between_dates(date(2026, 9, 2), date(2026, 9, 30))), [])

    def test_provider_movement_replaces_supplement_without_duplicate(self):
        loan = self.client.get_transfer(LOAN_ID)
        loan['id'] = 605299
        raw = deepcopy(SOURCE['37652834']) + [loan]
        self.client._iter_paginated_data.return_value = raw
        result = list(self.client.iter_transfers_by_player(37652834))
        self.assertEqual(result, raw)
        self.assertNotIn(LOAN_ID, [x['id'] for x in result])
        # 미완료 예정 행은 공식 완료 이동을 대신하지 않아요.
        loan['completed'] = False
        self.assertIn(LOAN_ID, [x['id'] for x in self.client.iter_transfers_by_player(37652834)])

    def test_unknown_provider_origin_matches_verified_arrival(self):
        arrival = self.client.get_transfer(ARRIVAL_ID)
        arrival.update(id=605300, from_team_id=260131, fromteam={'id': 260131, 'placeholder': True})
        self.client._iter_paginated_data.return_value = [arrival]
        self.assertEqual(list(self.client.iter_transfers_by_player(37707501)), [arrival])

    def test_partial_source_failure_does_not_append_supplement(self):
        def incomplete(*args, **kwargs):
            yield SOURCE['37652834'][0]
            raise ConnectionError('page 2 failed')
        self.client._iter_paginated_data.side_effect = incomplete
        result = self.client.iter_transfers_by_player(37652834)
        self.assertEqual(next(result)['id'], 595707)
        with self.assertRaises(ConnectionError):
            next(result)

    def test_local_ids_are_exact_json_integers_and_queries_do_not_mutate_rules(self):
        for tid in (LOAN_ID, ARRIVAL_ID):
            self.assertLessEqual(tid, 2**53 - 1)
            self.assertEqual(int(float(tid)), tid)
            item = self.client.get_transfer(tid)
            self.assertIsNone(item['amount'])
            item['toteam']['name'] = 'changed'
            self.assertNotEqual(self.client.get_transfer(tid)['toteam']['name'], 'changed')
        self.client._get.assert_not_called()


if __name__ == '__main__':
    unittest.main()
