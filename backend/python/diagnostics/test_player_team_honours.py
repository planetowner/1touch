import unittest

from one_touch_loader.loaders.player_team_honours_loader import _winner_rows


class PlayerTeamHonoursTests(unittest.TestCase):
    def trophy(self, *, position=1):
        return {'team_id': 10, 'league_id': 20, 'season_id': 30,
                'trophy_id': position, 'trophy': {'name': 'Winner' if position == 1 else 'Runner-up', 'position': position},
                'team': {'id': 10, 'name': 'Team', 'image_path': 'https://example.com/team.png'},
                'league': {'id': 20, 'name': 'Cup'}, 'season': {'id': 30, 'name': '2025/2026'}}

    def test_winners_keep_provider_metadata_but_runner_up_is_excluded(self):
        rows, count = _winner_rows({'trophies': [self.trophy(), self.trophy(position=2)]}, 1)
        self.assertEqual(count, 2)
        self.assertEqual(rows, [(1, 10, 20, 30, 'Team', 'https://example.com/team.png', 'Cup', '2025/2026')])

    def test_missing_metadata_does_not_invent_names_or_remove_verified_win(self):
        trophy = self.trophy()
        trophy.update(team=None, league=None, season=None)
        self.assertEqual(_winner_rows({'trophies': [trophy]}, 1)[0], [(1, 10, 20, 30, None, None, None, None)])

    def test_mismatched_metadata_is_rejected_before_database_replacement(self):
        trophy = self.trophy()
        trophy['season']['id'] = 31
        with self.assertRaisesRegex(ValueError, 'id mismatch'):
            _winner_rows({'trophies': [trophy]}, 1)

    def test_missing_trophy_collection_is_not_an_empty_history(self):
        with self.assertRaises(ValueError):
            _winner_rows({}, 1)


if __name__ == '__main__':
    unittest.main()
