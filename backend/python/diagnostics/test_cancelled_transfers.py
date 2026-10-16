"""공식 취소된 세비야행이 어느 조회 경로에서도 복원되지 않는지 확인해요."""
import unittest
from datetime import date
from unittest.mock import Mock

from one_touch_loader.core.sportmonks import SportmonksClient


class CancelledTransferTests(unittest.TestCase):
    def test_mercado_cancellation_applies_to_all_transfer_queries(self):
        client = SportmonksClient.__new__(SportmonksClient)
        cancelled = {'id': 560599, 'player_id': 37585108, 'completed': True,
                     'date': '2026-07-01', 'from_team_id': 14635, 'to_team_id': 676}
        client._iter_paginated_data = Mock(return_value=[cancelled])
        for query in (
            lambda: client.iter_transfers_by_player(37585108),
            lambda: client.iter_transfers_by_team(676),
            lambda: client.iter_transfers_by_team(14635),
            lambda: client.iter_transfers_between_dates(date(2026, 7, 1), date(2026, 7, 31)),
        ):
            self.assertEqual(list(query()), [])
        client._get = Mock(return_value={'data': cancelled})
        self.assertIsNone(client.get_transfer(560599))


if __name__ == '__main__':
    unittest.main()
