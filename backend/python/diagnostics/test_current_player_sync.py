"""자동 동기화가 수동 이름·사진·역할을 보존하고 팀 단위로 저장하는지 확인해요."""
from contextlib import ExitStack, redirect_stdout
from copy import deepcopy
from datetime import date
import io
import sqlite3
import unittest
from unittest.mock import Mock, call, patch

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader import cli
    from one_touch_loader.core import db
    from one_touch_loader.loaders import current_season_sync as sync
    from one_touch_loader.loaders import players_loader as players
    from one_touch_loader.loaders import team_squad_members_loader as squads
    from diagnostics.test_fixture_details import _SqliteCursor


def profile(player_id, **changes):
    result = dict(id=player_id, name=f"Full {player_id}", display_name=f"Updated {player_id}",
                  detailed_position_id=None, position_id=27, nationality_id=1,
                  date_of_birth="2000-01-01", height=190, weight=80,
                  image_path=f"provider-{player_id}.png")
    result.update(changes)
    return result


def member(player_id, jersey=9):
    return dict(id=player_id, player_id=player_id, position_id=27, detailed_position_id=151,
                start='2026-07-01', end='2028-06-30', transfer_id=None,
                jersey_number=jersey, player=profile(player_id))


class Cursor(_SqliteCursor):
    @staticmethod
    def _sql(sql):
        return _SqliteCursor._sql(sql).replace("LEFT(seasons.name, 4)", "substr(seasons.name, 1, 4)")

    @property
    def rowcount(self):
        return self.cursor.rowcount


class SyncDatabaseCase(unittest.TestCase):
    def setUp(self):
        self.sql = sqlite3.connect(":memory:", detect_types=sqlite3.PARSE_DECLTYPES)
        self.addCleanup(self.sql.close)
        self.sql.executescript("""
            PRAGMA foreign_keys=ON;
            CREATE TABLE positions(position_id INTEGER PRIMARY KEY);
            INSERT INTO positions VALUES (151),(154);
            CREATE TABLE countries(country_id INTEGER PRIMARY KEY);
            INSERT INTO countries VALUES (1);
            CREATE TABLE players(player_id INTEGER PRIMARY KEY, display_name TEXT NOT NULL,
                full_name TEXT NOT NULL, position_id INTEGER REFERENCES positions,
                nationality_id INTEGER REFERENCES countries, date_of_birth TEXT,
                height_cm INTEGER, weight_kg INTEGER, image_path TEXT,
                image_is_custom INTEGER NOT NULL DEFAULT 0,
                display_name_ko TEXT, short_name_ko TEXT, short_name TEXT,
                display_name_ja TEXT, display_name_zh TEXT, short_name_ja TEXT, short_name_zh TEXT);
            CREATE TABLE player_external_ids(player_id INTEGER REFERENCES players,
                provider TEXT, external_player_id TEXT, PRIMARY KEY(player_id,provider));
            CREATE TABLE teams(team_id INTEGER PRIMARY KEY, name TEXT, short_code TEXT, image_path TEXT);
            INSERT INTO teams(team_id,name) VALUES(10,'A'),(20,'B'),(30,'Cup opponent');
            CREATE TABLE transfer_types(type_id INTEGER PRIMARY KEY, name TEXT);
            CREATE TABLE transfers(transfer_id INTEGER PRIMARY KEY, player_id INTEGER REFERENCES players,
                from_team_id INTEGER REFERENCES teams, to_team_id INTEGER REFERENCES teams,
                type_id INTEGER REFERENCES transfer_types, amount INTEGER, transfer_date DATE);
            CREATE TABLE player_contracts(team_id INTEGER REFERENCES teams, player_id INTEGER REFERENCES players,
                start_date DATE, end_date DATE, transfer_id INTEGER REFERENCES transfers ON DELETE RESTRICT,
                PRIMARY KEY(team_id,player_id), CHECK(start_date IS NULL OR end_date IS NULL OR start_date<=end_date));
            CREATE TABLE seasons(season_id INTEGER PRIMARY KEY, competition_id INTEGER,
                name TEXT, is_current INTEGER);
            INSERT INTO seasons VALUES(800,8,'2026/2027',1),(799,8,'2025/2026',0),(2400,24,'2026/2027',1);
            CREATE TABLE team_seasons(team_id INTEGER REFERENCES teams, season_id INTEGER REFERENCES seasons,
                PRIMARY KEY(team_id,season_id));
            INSERT INTO team_seasons VALUES(10,800),(20,800),(10,799),(30,2400);
            CREATE TABLE team_squad_members(team_id INTEGER, season_id INTEGER,
                player_id INTEGER REFERENCES players, position_group_id INTEGER, jersey_number INTEGER,
                squad_role TEXT, leadership_role TEXT, PRIMARY KEY(team_id,season_id,player_id),
                FOREIGN KEY(team_id,season_id) REFERENCES team_seasons);
        """)
        self.sql.executemany("""INSERT INTO players(player_id,display_name,full_name,position_id,
            nationality_id,image_path,image_is_custom,display_name_ko,short_name_ko,short_name)
            VALUES(?,'Before','Before',151,1,'custom.png',1,'직접 조사한 이름','조사한 짧은 이름','Manual short')""",
            [(pid,) for pid in (1, 2, 3, 4)])
        self.sql.execute("UPDATE players SET position_id=NULL,display_name_ko=NULL,short_name_ko=NULL WHERE player_id=2")
        self.sql.executemany("INSERT INTO team_squad_members VALUES(?,?,?,25,7,'important','captain')",
                             [(10, 800, 1), (10, 800, 3), (20, 800, 2), (10, 799, 3), (30, 2400, 4)])
        self.sql.commit()
        self.connection = Mock()
        self.connection.cursor.side_effect = lambda: Cursor(self.sql)
        self.connection.commit.side_effect = self.sql.commit
        self.connection.rollback.side_effect = self.sql.rollback
        self.client = Mock(request_count=0, page_count=0)
        self.client.iter_transfers_by_team.side_effect = lambda team: self.api([])
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([])
        self.client.get_team_squad.side_effect = lambda team: self.api(
            [member(1), member(2), member(5)] if team == 10 else [member(2)])
        self.client.get_player_or_none.side_effect = lambda pid: self.api(profile(pid))
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(db, "get_conn", return_value=self.connection))
        self.stack.enter_context(patch.object(sync, "SportmonksClient", return_value=self.client))
        self.stack.enter_context(patch.object(sync, "date")).today.return_value = date(2026, 9, 25)
        self.stack.enter_context(redirect_stdout(io.StringIO()))

    def api(self, value):
        self.assertFalse(self.sql.in_transaction, "API call inside write transaction")
        self.client.request_count += 1
        return deepcopy(value)

    def names(self, pid=1):
        return self.sql.execute("SELECT display_name_ko,short_name_ko,short_name,image_path FROM players WHERE player_id=?",
                                (pid,)).fetchone()


class CurrentPlayerSyncTests(SyncDatabaseCase):
    def test_squads_only_fetch_globally_missing_players_and_preserve_manual_fields(self):
        before = self.names()
        result = sync.sync_current_squads(apply=True)
        self.client.get_player_or_none.assert_called_once_with(5)
        self.assertEqual(self.client.get_team_squad.call_args_list, [call(10), call(20)])
        self.assertEqual(result['profile_fetches'], 1)
        self.assertEqual(result['stored_players'], 1)
        self.assertEqual(self.names(), before)
        self.assertEqual(self.names(2)[:2], (None, None))
        self.assertEqual(self.sql.execute("SELECT display_name,position_id FROM players WHERE player_id=2").fetchone(), ('Before', 151))
        self.assertEqual(self.sql.execute("SELECT position_group_id,jersey_number,squad_role,leadership_role FROM team_squad_members WHERE team_id=10 AND season_id=800 AND player_id=1").fetchone(),
                         (27, 9, 'important', 'captain'))
        self.assertEqual(self.sql.execute("SELECT season_id FROM team_squad_members WHERE player_id=3").fetchall(), [(799,)])
        self.assertIsNotNone(self.sql.execute("SELECT player_id FROM players WHERE player_id=3").fetchone())
        self.assertEqual(self.sql.execute("SELECT position_id,display_name_ko,short_name_ko FROM players WHERE player_id=5").fetchone(), (151, None, None))
        self.sql.execute("UPDATE players SET display_name_ko='새로 조사한 이름',short_name_ko='새 이름' WHERE player_id=5")
        self.sql.commit()
        self.client.get_player_or_none.reset_mock()
        sync.sync_current_squads(apply=True)
        self.client.get_player_or_none.assert_not_called()
        self.assertEqual(self.names(5)[:2], ('새로 조사한 이름', '새 이름'))
        self.assertEqual(self.names(), before)

    def test_latest_preserves_manual_names_and_custom_image_and_only_updates_known_players(self):
        before = self.names()
        self.client.get_latest_players.side_effect = lambda: self.api([
            profile(1, display_name_ko='API 한국어', short_name_ko='API 약칭'), profile(3), profile(999)])
        for _ in range(2):
            result = sync.sync_player_updates(apply=True)
        self.assertEqual(result['stored_players'], 2)
        self.assertEqual(result['skipped_unknown_players'], 1)
        self.assertEqual(self.names(), before)
        self.assertEqual(self.sql.execute("SELECT display_name,height_cm,position_id FROM players WHERE player_id=1").fetchone(), ('Updated 1', 190, 151))
        self.assertIsNone(self.sql.execute("SELECT player_id FROM players WHERE player_id=999").fetchone())
        self.assertEqual(self.sql.execute("SELECT jersey_number FROM team_squad_members WHERE player_id=1").fetchone(), (7,))
        self.client.get_player_or_none.assert_not_called()
        self.client.get_team_squad.assert_not_called()

    def test_reconciliation_deduplicates_current_roster_and_preserves_manual_names(self):
        self.sql.execute("DELETE FROM team_squad_members WHERE player_id=3 AND season_id=800")
        self.sql.execute("INSERT INTO team_squad_members VALUES(10,800,2,27,8,NULL,NULL)")
        self.sql.commit()
        before = self.names()
        result = sync.reconcile_current_players(apply=True)
        self.assertEqual(self.client.get_player_or_none.call_args_list, [call(1), call(2)])
        self.assertEqual(result['requested_players'], 2)
        self.assertEqual(self.names(), before)
        self.assertEqual(self.sql.execute("SELECT display_name FROM players WHERE player_id=3").fetchone(), ('Before',))
        self.assertEqual(self.sql.execute("SELECT height_cm,position_id FROM players WHERE player_id=1").fetchone(), (190, 151))
        self.client.get_team_squad.assert_not_called()

    def test_all_preview_modes_leave_database_unchanged(self):
        before = list(self.sql.iterdump())
        self.client.get_latest_players.return_value = [profile(1)]
        for run in (sync.sync_current_squads, sync.sync_player_updates, sync.reconcile_current_players):
            with self.subTest(run=run.__name__):
                self.assertFalse(run()['apply'])
                self.assertEqual(list(self.sql.iterdump()), before)
                self.connection.commit.assert_not_called()

    def test_empty_current_squad_and_api_failure_leave_team_untouched(self):
        before = list(self.sql.iterdump())
        self.client.get_team_squad.side_effect = lambda team: []
        with self.assertRaisesRegex(ValueError, 'empty current squad'):
            sync.sync_current_squads(apply=True)
        self.assertEqual(list(self.sql.iterdump()), before)
        self.client.get_team_squad.side_effect = lambda team: [member(1), member(5)]
        self.client.get_player_or_none.side_effect = RuntimeError('provider failed')
        with self.assertRaisesRegex(RuntimeError, 'provider failed'):
            sync.sync_current_squads(apply=True)
        self.assertEqual(list(self.sql.iterdump()), before)
        self.connection.commit.assert_not_called()

    def test_squad_write_failure_rolls_back_new_profile_and_memberships(self):
        self.sql.executescript("""CREATE TRIGGER reject_member BEFORE INSERT ON team_squad_members
            WHEN NEW.player_id=5 BEGIN SELECT RAISE(ABORT, 'squad rejected'); END;""")
        before = list(self.sql.iterdump())
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'squad rejected'):
            sync.sync_current_squads(apply=True)
        self.assertEqual(list(self.sql.iterdump()), before)
        self.connection.rollback.assert_called_once()

    def test_contracts_share_squad_response_and_renewals_replace_old_dates(self):
        result = sync.sync_current_squads(apply=True)
        self.assertEqual(result['stored_contracts'], 4)
        self.assertEqual(self.client.get_team_squad.call_count, 2)
        self.client.get_player_current_teams.assert_not_called()
        self.client.get_transfer.assert_not_called()
        renewed = {**member(1), 'end': '2030-06-30'}
        self.client.get_team_squad.side_effect = lambda team: self.api([renewed] if team == 10 else [member(2)])
        sync.sync_current_squads(apply=True)
        self.assertEqual(self.sql.execute('SELECT end_date FROM player_contracts WHERE team_id=10 AND player_id=1').fetchone(), (date(2030, 6, 30),))
        self.assertEqual(self.sql.execute('SELECT player_id FROM player_contracts WHERE team_id=10').fetchall(), [(1,)])

    def test_contract_write_failure_rolls_back_entire_team_snapshot(self):
        self.sql.executescript("""CREATE TRIGGER reject_contract BEFORE INSERT ON player_contracts
            BEGIN SELECT RAISE(ABORT, 'contract rejected'); END;""")
        before = list(self.sql.iterdump())
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'contract rejected'):
            sync.sync_current_squads(apply=True)
        self.assertEqual(list(self.sql.iterdump()), before)

    def test_new_player_profile_failure_does_not_save_other_new_players(self):
        self.client.get_team_squad.side_effect = lambda team: [member(5), member(6)]
        self.client.get_player_or_none.side_effect = [profile(5), {'id': 6, 'name': 'Invalid'}]
        before = list(self.sql.iterdump())
        with self.assertRaisesRegex(ValueError, 'display_name'):
            sync.sync_current_squads(apply=True)
        self.assertEqual(list(self.sql.iterdump()), before)

    def test_unavailable_new_profile_uses_existing_squad_fallback(self):
        self.client.get_player_or_none.side_effect = lambda pid: None
        sync.sync_current_squads(apply=True)
        self.assertEqual(self.sql.execute("SELECT display_name,position_id FROM players WHERE player_id=5").fetchone(), ('Updated 5', 151))

    def test_unavailable_reconciliation_profile_keeps_existing_player(self):
        before = self.names()
        self.client.get_player_or_none.side_effect = lambda pid: None
        result = sync.reconcile_current_players(apply=True)
        self.assertEqual(result['unavailable_player_ids'], [1, 2, 3])
        self.assertEqual(result['stored_players'], 0)
        self.assertEqual(self.names(), before)
        self.connection.commit.assert_not_called()

    def test_empty_latest_response_is_noop(self):
        self.client.get_latest_players.return_value = []
        self.assertEqual(sync.sync_player_updates(apply=True)['stored_players'], 0)
        self.connection.commit.assert_not_called()

    def test_valid_profile_position_and_confirmed_name_override_are_updated(self):
        self.sql.execute("INSERT INTO players(player_id,display_name,full_name,display_name_ko,short_name_ko) VALUES(186733,'Wrong','Wrong','헤르만 페첼라','페첼라')")
        self.sql.commit()
        self.client.get_latest_players.return_value = [profile(1, detailed_position_id=154), profile(186733)]
        sync.sync_player_updates(apply=True)
        self.assertEqual(self.sql.execute("SELECT position_id FROM players WHERE player_id=1").fetchone(), (154,))
        self.assertEqual(self.sql.execute("SELECT display_name,full_name,display_name_ko,short_name_ko FROM players WHERE player_id=186733").fetchone(),
                         ('Germán Pezzella', 'Germán Alejo Pezzella', '헤르만 페첼라', '페첼라'))

    def test_failure_in_later_team_keeps_completed_team_transaction(self):
        self.client.get_team_squad.side_effect = lambda team: [member(1), member(5)] if team == 10 else []
        with self.assertRaisesRegex(ValueError, 'empty current squad'):
            sync.sync_current_squads(apply=True)
        self.assertEqual(self.sql.execute("SELECT team_id,player_id FROM team_squad_members WHERE season_id=800 ORDER BY team_id,player_id").fetchall(),
                         [(10, 1), (10, 5), (20, 2)])
        self.assertIsNotNone(self.sql.execute("SELECT player_id FROM players WHERE player_id=5").fetchone())

    def test_completed_out_is_removed_but_future_transfer_does_not_remove_player(self):
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: [
            dict(id=1, player_id=1, from_team_id=10, to_team_id=30, date='2026-09-20', completed=True),
            dict(id=2, player_id=2, from_team_id=10, to_team_id=30, date='2027-01-01', completed=True)]
        sync.sync_current_squads(apply=True)
        self.assertEqual(self.sql.execute("SELECT player_id FROM team_squad_members WHERE team_id=10 AND season_id=800 ORDER BY player_id").fetchall(), [(2,), (5,)])
        self.assertIsNotNone(self.sql.execute("SELECT player_id FROM players WHERE player_id=1").fetchone())

    def test_shared_writer_keeps_names_even_when_missing_player_is_inserted_concurrently(self):
        # 신규 판단 뒤 다른 수집기가 같은 선수를 저장해도 upsert는 수동 컬럼을 건드리지 않아요.
        before = self.names()
        row, _ = players._build_player_row(players._audit_direct_player_profile(profile(1), 1), [], {151}, 'player_endpoint')
        players._upsert_player_rows([row])
        self.assertEqual(self.names(), before)

    def test_shared_snapshot_still_requires_players_for_historical_load(self):
        before = list(self.sql.iterdump())
        with self.assertRaisesRegex(ValueError, 'Load players before squad members'):
            squads._replace_squad_snapshot(10, 799, [member(999)])
        self.assertEqual(list(self.sql.iterdump()), before)

    def test_cli_modes_default_to_preview_and_legacy_current_command_uses_same_sync(self):
        actions = {'squads': 'sync_current_squads', 'player-updates': 'sync_player_updates',
                   'player-reconciliation': 'reconcile_current_players'}
        for mode, name in actions.items():
            for apply in (False, True):
                with self.subTest(mode=mode, apply=apply), \
                        patch('sys.argv', ['cli', 'current-season', mode] + (['--apply'] if apply else [])), \
                        patch.object(sync, name, return_value={}) as run:
                    cli.main()
                    run.assert_called_once_with(apply=apply)
        with patch.object(sync, 'sync_current_squads', return_value={}) as run:
            squads.refresh_current_squads()
        run.assert_called_once_with(apply=True)


if __name__ == '__main__':
    unittest.main()
