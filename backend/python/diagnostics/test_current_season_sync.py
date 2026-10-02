from __future__ import annotations

import io
import re
import sqlite3
import unittest
from contextlib import ExitStack, nullcontext, redirect_stdout
from copy import deepcopy
from unittest.mock import MagicMock, Mock, patch

# 테스트 모듈을 직접 실행해도 운영 DB 연결을 만들지 않아요.
with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader import cli
    from one_touch_loader.core import db
    from one_touch_loader.core.fixture_states import LIVE_STATE_IDS, COMPLETED_STATE_IDS
    from one_touch_loader.loaders import current_season_sync as sync
    from one_touch_loader.loaders import fixtures_loader as fixtures
    from one_touch_loader.loaders import teams_loader as teams

from diagnostics.test_fixtures_loader import _fixture_payload


def team(team_id):
    return {"id": team_id, "name": f"Team {team_id}", "short_code": "TEST",
            "image_path": f"https://example.test/{team_id}.png", "placeholder": False}


def fixture(fixture_id=1001, competition_id=24, season_id=2400, home_id=10, away_id=20):
    payload = _fixture_payload()
    payload.update(id=fixture_id, league_id=competition_id, season_id=season_id,
                   state_id=1, scores=[], aggregate_id=None, aggregate=None)
    payload["state"] = {"id": 1, "state": "NS", "name": "Not Started"}
    payload["participants"] = [dict(team(home_id), meta={"location": "home"}),
                               dict(team(away_id), meta={"location": "away"})]
    return payload


class CurrentSeasonSyncTests(unittest.TestCase):
    def setUp(self):
        # 포지션 갱신은 별도 통합 테스트에서 실제 SQL로 확인해요.
        positions = patch.object(fixtures.player_positions, 'refresh_positions_after_fixtures',
                                 side_effect=lambda *args, **kwargs: nullcontext())
        positions.start()
        self.addCleanup(positions.stop)
        self.sqlite = sqlite3.connect(":memory:")
        self.addCleanup(self.sqlite.close)
        self.sqlite.executescript("""
            PRAGMA foreign_keys=ON;
            CREATE TABLE competitions (competition_id INTEGER PRIMARY KEY);
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY, competition_id INTEGER,
                name TEXT, is_current INTEGER);
            CREATE TABLE teams (team_id INTEGER PRIMARY KEY, name TEXT, short_code TEXT,
                image_path TEXT, short_name TEXT);
            CREATE TABLE team_seasons (team_id INTEGER REFERENCES teams, season_id INTEGER REFERENCES seasons,
                PRIMARY KEY(team_id, season_id));
            CREATE TABLE wages (team_id INTEGER, season_id INTEGER, amount INTEGER,
                FOREIGN KEY(team_id,season_id) REFERENCES team_seasons ON DELETE CASCADE);
            CREATE TABLE best_eleven (team_id INTEGER, season_id INTEGER,
                FOREIGN KEY(team_id,season_id) REFERENCES team_seasons ON DELETE RESTRICT);
            CREATE TABLE stages (stage_id INTEGER PRIMARY KEY, season_id INTEGER REFERENCES seasons,
                stage_type_id INTEGER, name TEXT);
            CREATE TABLE stage_groups (group_id INTEGER PRIMARY KEY, stage_id INTEGER REFERENCES stages,
                competition_id INTEGER, season_id INTEGER, name TEXT);
            CREATE TABLE rounds (round_id INTEGER PRIMARY KEY, stage_id INTEGER REFERENCES stages, name TEXT);
            CREATE TABLE venues (venue_id INTEGER PRIMARY KEY, name TEXT);
            CREATE TABLE fixture_states (state_id INTEGER PRIMARY KEY, state_code TEXT, name TEXT);
            CREATE TABLE aggregates (aggregate_id INTEGER PRIMARY KEY, stage_id INTEGER REFERENCES stages,
                winner_team_id INTEGER REFERENCES teams);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY, stage_id INTEGER REFERENCES stages,
                round_id INTEGER REFERENCES rounds, group_id INTEGER REFERENCES stage_groups,
                aggregate_id INTEGER REFERENCES aggregates, leg TEXT, home_team_id INTEGER REFERENCES teams,
                away_team_id INTEGER REFERENCES teams, starting_at TEXT, venue_id INTEGER REFERENCES venues,
                state_id INTEGER REFERENCES fixture_states, home_score INTEGER, away_score INTEGER,
                home_penalty_score INTEGER, away_penalty_score INTEGER);
        """)
        self.sqlite.executemany("INSERT INTO competitions VALUES (?)", [(cid,) for cid in teams.SUPPORTED_COMPETITION_IDS])
        self.sqlite.executemany("INSERT INTO seasons VALUES (?,?,?,?)",
                                [(cid * 100, cid, "2026/2027", 1) for cid in teams.SUPPORTED_COMPETITION_IDS])
        self.sqlite.execute("INSERT INTO teams VALUES (10,'Existing','EX','old.png','앱 이름')")
        self.sqlite.executemany("INSERT INTO team_seasons VALUES (10,?)", [(800,), (38400,), (56400,)])
        self.sqlite.execute("INSERT INTO wages VALUES (10,800,100)")
        self.sqlite.execute("INSERT INTO best_eleven VALUES (10,800)")
        self.sqlite.commit()
        cursor = MagicMock()
        self.sqlite_cursor = self.sqlite.cursor()
        cursor.execute.side_effect = lambda sql, args=(): self.sqlite_cursor.execute(self.translate(sql), args)
        cursor.executemany.side_effect = lambda sql, rows: self.sqlite_cursor.executemany(self.translate(sql), rows)
        cursor.fetchall.side_effect = self.sqlite_cursor.fetchall
        self.connection = MagicMock()
        self.connection.cursor.return_value.__enter__.return_value = cursor
        self.connection.commit.side_effect = self.sqlite.commit
        self.connection.rollback.side_effect = self.sqlite.rollback
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(db, "get_conn", return_value=self.connection))
        self.stack.enter_context(redirect_stdout(io.StringIO()))

    @staticmethod
    def translate(sql):
        # MySQL upsert만 SQLite 문법으로 바꾸고 CASE·FK·트랜잭션은 실제 실행해요.
        sql = sql.replace("%s", "?")
        if "ON DUPLICATE KEY UPDATE" in sql:
            sql = sql.replace("ON DUPLICATE KEY UPDATE", "ON CONFLICT DO UPDATE SET")
            sql = re.sub(r"VALUES\((\w+)\)", r"excluded.\1", sql)
        return sql

    def client(self):
        client = Mock(request_count=0, page_count=0)
        client.get_league_with_seasons.side_effect = lambda cid: {"seasons": [
            {"id": cid * 100 - 1, "name": "2025/2026", "is_current": False},
            {"id": cid * 100, "name": "2026/2027", "is_current": True},
        ]}
        client.iter_teams_by_season.side_effect = lambda sid: [team(10), team(sid + 1)]
        return client

    def metadata(self, client, apply=True):
        with patch.object(sync, "SportmonksClient", return_value=client):
            return sync.sync_current_season_metadata(apply=apply)

    def collect(self, payloads, *, competition_id=24, apply=True):
        client = self.client()
        client.iter_fixtures_by_season.return_value = iter(payloads)
        result = fixtures._collect_and_upsert(
            client, (competition_id * 100, competition_id, "2026/2027", True), set(),
            sync_participants=True, apply=apply,
        )
        client.iter_fixtures_by_season.assert_called_once_with(
            competition_id * 100, per_page=50, include=fixtures.FIXTURE_INCLUDE)
        client.iter_teams_by_season.assert_not_called()
        return result

    def test_metadata_reuses_participants_and_preserves_memberships_and_children(self):
        client = self.client()
        # 응답에서 빠진 기존 관계도 자동 실행으로 삭제하지 않아요.
        client.iter_teams_by_season.side_effect = lambda sid: [team(sid + 1), dict(team(999), placeholder=True)]
        self.metadata(client)
        self.assertEqual(client.get_league_with_seasons.call_count, 12)
        self.assertEqual(client.iter_teams_by_season.call_count, 8)
        self.assertEqual({call.args[0] for call in client.iter_teams_by_season.call_args_list},
                         {cid * 100 for cid in teams.SUPPORTED_COMPETITION_IDS if cid not in teams.CUP_BASE_COMPETITION_IDS})
        client.iter_fixtures_by_season.assert_not_called()
        self.metadata(self.client())
        self.assertEqual(self.sqlite.execute("SELECT * FROM wages").fetchall(), [(10, 800, 100)])
        self.assertEqual(self.sqlite.execute("SELECT * FROM best_eleven").fetchall(), [(10, 800)])
        self.assertEqual(self.sqlite.execute("SELECT short_name FROM teams WHERE team_id=10").fetchone(), ("앱 이름",))
        self.assertIsNone(self.sqlite.execute("SELECT team_id FROM teams WHERE team_id=999").fetchone())
        self.assertEqual(self.sqlite.execute("SELECT COUNT(*) FROM team_seasons WHERE season_id=2400").fetchone()[0], 0)

    def test_metadata_rollover_and_same_name_base_season(self):
        self.sqlite.execute("INSERT INTO seasons VALUES (799,8,'2025/2026',1)")
        self.sqlite.commit()
        client = self.client()
        original = client.get_league_with_seasons.side_effect
        def response(cid):
            payload = original(cid)
            if cid == 24:
                for row in payload['seasons']:
                    row['is_current'] = row['name'] == '2025/2026'
            return payload
        client.get_league_with_seasons.side_effect = response
        self.metadata(client)
        self.assertEqual(self.sqlite.execute("SELECT season_id FROM seasons WHERE competition_id=8 AND is_current=1").fetchall(), [(800,)])
        self.assertEqual(self.sqlite.execute("SELECT season_id FROM seasons WHERE competition_id=24 AND is_current=1").fetchall(), [(2399,)])
        self.assertEqual(sum(call.args == (799,) for call in client.iter_teams_by_season.call_args_list), 1)

    def test_empty_metadata_response_keeps_existing_relations(self):
        client = self.client()
        client.iter_teams_by_season.side_effect = lambda sid: []
        self.metadata(client)
        self.assertEqual(self.sqlite.execute("SELECT * FROM wages").fetchall(), [(10, 800, 100)])
        self.assertEqual(self.sqlite.execute("SELECT COUNT(*) FROM team_seasons").fetchone()[0], 3)

    def test_metadata_failure_does_not_partially_switch_seasons(self):
        client = self.client()
        client.iter_teams_by_season.side_effect = [[team(90)], RuntimeError('provider failed')]
        with self.assertRaisesRegex(RuntimeError, "provider failed"):
            self.metadata(client)
        self.connection.commit.assert_not_called()
        self.assertIsNone(self.sqlite.execute("SELECT team_id FROM teams WHERE team_id=90").fetchone())

    def test_metadata_check_does_not_write(self):
        self.assertFalse(self.metadata(self.client(), apply=False)['apply'])
        self.connection.commit.assert_not_called()
        self.assertEqual(self.sqlite.execute("SELECT COUNT(*) FROM teams").fetchone()[0], 1)

    def test_all_four_cups_filter_before_team_and_membership_storage(self):
        for cup_id in teams.CUP_BASE_COMPETITION_IDS:
            with self.subTest(cup_id=cup_id):
                accepted = fixture(cup_id, cup_id, cup_id * 100)
                unrelated = fixture(cup_id + 1000, cup_id, cup_id * 100, 30, 40)
                pending = fixture(cup_id + 2000, cup_id, cup_id * 100, 10, 999)
                pending['participants'][1]['placeholder'] = True
                result = self.collect([accepted, unrelated, pending], competition_id=cup_id)
                self.collect([accepted], competition_id=cup_id)
                self.assertEqual(result['stored_fixture_count'], 1)
                self.assertEqual(result['skipped_unrelated_cup_count'], 1)
                self.assertEqual(result['skipped_placeholder_count'], 1)
                self.assertEqual(self.sqlite.execute("SELECT team_id FROM team_seasons WHERE season_id=? ORDER BY team_id", (cup_id * 100,)).fetchall(), [(10,), (20,)])
        self.assertEqual(self.sqlite.execute("SELECT team_id FROM teams ORDER BY team_id").fetchall(), [(10,), (20,)])
        self.assertEqual(self.sqlite.execute("SELECT COUNT(*) FROM fixtures").fetchone()[0], 4)

    def test_general_competition_discovers_teams_from_fixtures(self):
        self.collect([fixture(competition_id=8, season_id=800, home_id=30, away_id=40)], competition_id=8)
        self.assertEqual(self.sqlite.execute("SELECT team_id FROM team_seasons WHERE season_id=800 ORDER BY team_id").fetchall(), [(10,), (30,), (40,)])

    def test_late_season_payload_preserves_live_and_finished_results(self):
        payload = fixture()
        self.collect([payload])
        for state_id in (*LIVE_STATE_IDS, *COMPLETED_STATE_IDS):
            with self.subTest(state_id=state_id):
                self.sqlite.execute("INSERT OR IGNORE INTO fixture_states VALUES (?, 'TEST', 'Test')", (state_id,))
                self.sqlite.execute("UPDATE fixtures SET state_id=?,home_score=3,away_score=2,home_penalty_score=4,away_penalty_score=3", (state_id,))
                self.sqlite.commit()
                stale = deepcopy(payload)
                stale['starting_at'] = '2026-09-30 20:00:00'
                self.collect([stale])
                self.assertEqual(self.sqlite.execute("SELECT state_id,home_score,away_score,home_penalty_score,away_penalty_score,starting_at FROM fixtures").fetchone(),
                                 (state_id, 3, 2, 4, 3, '2026-09-30 20:00:00'))

    def test_postponed_cancelled_and_rescheduled_states_are_updated(self):
        payload = fixture()
        for state_id in (1, 10, 15, 1):
            payload['state_id'] = state_id
            payload['state']['id'] = state_id
            self.collect([payload])
            self.assertEqual(self.sqlite.execute("SELECT state_id FROM fixtures").fetchone()[0], state_id)

    def test_fixture_failure_rolls_back_new_teams_and_memberships(self):
        self.sqlite.executescript("""
            CREATE TRIGGER reject_fixture BEFORE INSERT ON fixtures
            BEGIN SELECT RAISE(ABORT, 'fixture rejected'); END;
        """)
        with self.assertRaisesRegex(sqlite3.IntegrityError, "fixture rejected"):
            self.collect([fixture()])
        self.connection.rollback.assert_called_once()
        self.assertIsNone(self.sqlite.execute("SELECT team_id FROM teams WHERE team_id=20").fetchone())
        self.assertEqual(self.sqlite.execute("SELECT COUNT(*) FROM team_seasons WHERE season_id=2400").fetchone()[0], 0)

    def test_fixture_check_does_not_write(self):
        result = self.collect([fixture()], apply=False)
        self.assertEqual(result['selected_fixture_count'], 1)
        self.assertEqual(result['stored_fixture_count'], 0)
        self.connection.commit.assert_not_called()

    def test_page_failure_does_not_save_a_partial_season(self):
        def pages():
            yield fixture()
            raise RuntimeError('second page failed')
        with self.assertRaisesRegex(RuntimeError, 'second page failed'):
            self.collect(pages())
        self.connection.commit.assert_not_called()
        self.assertEqual(self.sqlite.execute("SELECT COUNT(*) FROM fixtures").fetchone()[0], 0)

    def test_historical_loader_retains_missing_team_check_and_full_result_update(self):
        client = self.client()
        payload = fixture()
        client.iter_fixtures_by_season.side_effect = lambda *args, **kwargs: [payload]
        season = (2400, 24, '2026/2027', True)
        with self.assertRaisesRegex(ValueError, 'Run teams collection first'):
            fixtures._collect_and_upsert(client, season, {10})
        self.collect([payload])
        self.sqlite.execute("INSERT INTO fixture_states VALUES (5,'FT','Full Time')")
        self.sqlite.execute("UPDATE fixtures SET state_id=5,home_score=3,away_score=2")
        self.sqlite.commit()
        fixtures._collect_and_upsert(client, season, {10, 20})
        self.assertEqual(self.sqlite.execute("SELECT state_id,home_score FROM fixtures").fetchone(), (1, None))

    def test_ambiguous_current_season_is_rejected_before_writes(self):
        for flags in ((False, False), (True, True)):
            client = self.client()
            client.get_league_with_seasons.return_value = None
            client.get_league_with_seasons.side_effect = lambda cid: {'seasons': [
                {'id': cid * 100 - 1, 'name': '2025/2026', 'is_current': flags[0]},
                {'id': cid * 100, 'name': '2026/2027', 'is_current': flags[1]},
            ]}
            with self.subTest(flags=flags), self.assertRaisesRegex(ValueError, 'Expected one current season'):
                self.metadata(client)
        self.connection.commit.assert_not_called()

    def test_fixture_sync_uses_current_db_scope_without_season_or_team_api_calls(self):
        client = self.client()
        client.iter_fixtures_by_season.side_effect = lambda *args, **kwargs: []
        with patch.object(sync, "SportmonksClient", return_value=client), \
                patch.object(fixtures, "_load_scope", return_value=[(800, 8, '2026/2027', True)]) as scope:
            result = sync.sync_current_season_fixtures()
        scope.assert_called_once_with(None, None, current_only=True)
        client.get_league_with_seasons.assert_not_called()
        client.iter_teams_by_season.assert_not_called()
        self.assertEqual(result['results'][0]['selected_fixture_count'], 0)

    def test_current_cli_requires_apply_flag_and_rejects_unknown_options(self):
        for mode in ('metadata', 'fixtures'):
            for apply in (False, True):
                args = ['cli', 'current-season', mode] + (['--apply'] if apply else [])
                with patch('sys.argv', args), patch.object(sync, f'sync_current_season_{mode}', return_value={}) as run:
                    cli.main()
                run.assert_called_once_with(apply=apply)
        for args in ([], ['metadata', '--aply'], ['other']):
            with patch('sys.argv', ['cli', 'current-season', *args]), self.assertRaises(SystemExit):
                cli.main()


if __name__ == '__main__':
    unittest.main()
