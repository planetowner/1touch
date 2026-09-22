from datetime import datetime
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from one_touch_loader.core.clubelo import parse_ranking, ranking_ratings
from one_touch_loader.loaders import probability_loader as loader, probability_refresh


def page(*, elo='1350', second=''):
    return ('<small>Page created on 2026-09-21 22:32:52.</small>'
            '<div class="accordion-header"><a href="/ENG">England</a></div><table>'
            '<tr><td>Level 1<td>Average<tr><td><a href="/Arsenal"><span class="Ast">Arsenal</span></a>'
            '</td><td>2033</td></tr><tr><td><a href="/LincolnCity"><span class="Ast">Lincoln City</span>'
            '</a></td><td>1610</td></tr></table>'
            '<div class="accordion-header"><a href="/GIB">Gibraltar</a></div><table>'
            '<tr><td><a href="/GIB"><img alt="GIB"></a><span class="Ast">Lincoln</span></td>'
            f'<td>{elo}</td></tr>{second}</table>')


class RankingTests(unittest.TestCase):
    def test_unlinked_club_country_and_lowercase_existing_identifier(self):
        parsed = parse_ranking(page())
        self.assertEqual(parsed['date'], '2026-09-21')
        self.assertEqual(len(parsed['clubs']), 3)
        self.assertEqual(ranking_ratings(parsed, {'arsenal': 19, 'ranking:GIB:Lincoln': 10068}),
                         {19: 2033, 10068: 1350})

    def test_no_name_guess_or_duplicate_selection(self):
        with self.assertRaisesRegex(ValueError, 'found 0'):
            ranking_ratings(parse_ranking(page()), {'ranking:ENG:Lincoln': 10068})
        duplicate = '<tr><td><span class="Ast">Lincoln</span></td><td>1300</td></tr>'
        with self.assertRaisesRegex(ValueError, 'found 2'):
            ranking_ratings(parse_ranking(page(second=duplicate)), {'ranking:GIB:Lincoln': 10068})

    def test_date_and_rating_required(self):
        for elo in ('NaN', 'not available'):
            with self.assertRaisesRegex(ValueError, 'rating'):
                parse_ranking(page(elo=elo))
        with self.assertRaisesRegex(ValueError, 'publication date'):
            parse_ranking(page().replace('Page created on', 'No date'))
        with self.assertRaisesRegex(ValueError, 'marker'):
            ranking_ratings(parse_ranking(page(elo='1350p')), {'ranking:GIB:Lincoln': 10068})

    def test_current_ranking_downloaded_once_without_reading_profile(self):
        with patch.object(loader, 'ClubEloClient') as client:
            client.return_value.get_html.return_value = page()
            rows = loader.collect_elo({'Arsenal': 19, 'ranking:GIB:Lincoln': 10068})
        client.return_value.get_html.assert_called_once_with('Ranking')
        client.return_value.close.assert_called_once()
        self.assertEqual([(r[0], r[1], r[2]) for r in rows], [(19, '2026-09-21', 2033), (10068, '2026-09-21', 1350)])

    def test_latest_rating_preserves_past_and_check_never_writes(self):
        histories = {19: [{'date': '2026-09-20', 'elo': 2000}]}
        with patch.object(loader, 'collect_elo', return_value=[(19, '2026-09-21', 2033, 'hash', datetime(2026, 9, 21))]), \
             patch.object(loader, 'read_histories', return_value=histories), patch.object(loader, 'save_elo') as save:
            result = loader.refresh_histories({'Arsenal': 19}, apply=False)
        self.assertEqual(result[19], [{'date': '2026-09-20', 'elo': 2000}, {'date': '2026-09-21', 'elo': 2033}])
        save.assert_not_called()

    def test_verified_mapping_preserves_existing_ids_and_rejects_conflicts(self):
        with patch.object(loader, '_fetch', return_value=[{'external_team_id': 'arsenal', 'team_id': 19}]):
            mapping = loader.read_clubelo_mapping({19, 10068})
        self.assertEqual(mapping, {'arsenal': 19, 'ranking:GIB:Lincoln': 10068})
        for existing in ([{'external_team_id': 'WrongClub', 'team_id': 19}],
                         [{'external_team_id': 'Arsenal', 'team_id': 999}]):
            with patch.object(loader, '_fetch', return_value=existing), self.assertRaisesRegex(ValueError, 'conflicts|another team'):
                loader.read_clubelo_mapping({19})

    def test_scheduled_entrypoint_shares_one_snapshot_and_read_only_mode(self):
        histories = {19: [{'date': '2026-09-21', 'elo': 2033}]}
        with patch.object(loader, 'read_clubelo_mapping', return_value={'Arsenal': 19}), \
             patch.object(loader, 'refresh_histories', return_value=histories) as source, \
             patch.object(loader, 'refresh', return_value={}) as league, \
             patch.object(probability_refresh.cup_betting_loader, 'refresh', return_value={}) as cup, \
             patch.object(probability_refresh.european_probability_loader, 'refresh', return_value={}) as europe, \
             patch.object(probability_refresh.tournament_bracket_loader, 'refresh', return_value=[]) as brackets:
            result = probability_refresh.refresh(apply=False)
        source.assert_called_once_with({'Arsenal': 19}, apply=False, cache_dir=None)
        self.assertIs(league.call_args.kwargs['histories'], histories)
        self.assertIs(cup.call_args.kwargs['histories'], histories)
        self.assertFalse(league.call_args.kwargs['apply'])
        self.assertFalse(cup.call_args.kwargs['apply'])
        self.assertIs(europe.call_args.kwargs['histories'], histories)
        self.assertFalse(europe.call_args.kwargs['apply'])
        self.assertEqual(europe.call_args.kwargs['brackets'], [])
        brackets.assert_called_once_with(apply=False)
        self.assertEqual(result['strength_source_url'], 'https://clubelo.com/Ranking')

    def test_explicit_history_import_retains_profile_collector(self):
        with tempfile.TemporaryDirectory() as directory:
            mapping = Path(directory) / 'mapping.json'
            mapping.write_text(json.dumps({'Arsenal': 19}))
            with patch.object(loader, '_fetch', side_effect=[[{'team_id': 19}], []]), \
                 patch.object(loader, 'collect_history', return_value=[]) as history, \
                 patch.object(loader, 'collect_elo') as ranking, patch.object(loader, 'save_elo') as save:
                loader.sync_elo(mapping, cache_dir=None, apply=False)
        history.assert_called_once_with({'Arsenal': 19}, cache_dir=None)
        ranking.assert_not_called()
        save.assert_not_called()


if __name__ == '__main__':
    unittest.main()
