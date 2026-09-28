"""부분 조회·전체 이력·계약 참조의 경계를 실제 외래 키로 검증해요."""
from datetime import date
import sqlite3
from unittest.mock import call, patch

from diagnostics.test_current_player_sync import SyncDatabaseCase, member, profile
from one_touch_loader import cli
from one_touch_loader.loaders import current_season_sync as player_sync
from one_touch_loader.loaders import current_transfer_sync as sync
from one_touch_loader.loaders import transfers_loader as transfers


def team(tid):
    return dict(id=tid, name=f'Team {tid}', short_code=None, image_path=None, placeholder=False, type='domestic')


def movement(tid=100, pid=1, source=30, target=10, day='2026-09-24', **changes):
    item = dict(id=tid, player_id=pid, from_team_id=source, to_team_id=target,
                fromteam=team(source), toteam=team(target), type_id=219, type={'name': 'Transfer'},
                amount=None, date=day, completed=True, player=profile(pid))
    item.update(changes)
    return item


class CurrentTransferSyncTests(SyncDatabaseCase):
    def setUp(self):
        super().setUp()
        self.stack.enter_context(patch.object(sync, 'SportmonksClient', return_value=self.client))
        self.stack.enter_context(patch.object(sync, 'date')).today.return_value = date(2026, 9, 25)
        self.stack.enter_context(patch.object(sync, 'load_senior_team_ids', return_value={10, 20, 30}))
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([])
        self.client.iter_transfers_by_player.side_effect = lambda pid: self.api([])
        self.client.get_player_current_teams.side_effect = lambda pid: self.api([])

    def store(self, items):
        for pid in {item['player_id'] for item in items}:
            transfers.replace_player_transfers(pid, transfers.build_transfer_rows(pid, [i for i in items if i['player_id'] == pid], {10, 20, 30}))

    def test_recent_change_fetches_full_history_once_and_repeat_skips_it(self):
        old = movement(tid=90, source=20, target=30, day='2020-01-01')
        new = movement()
        self.store([old])
        before_names = self.names()
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([new])
        self.client.iter_transfers_by_player.side_effect = lambda pid: self.api([old, new])
        first = sync.sync_current_transfers(apply=True)
        second = sync.sync_current_transfers(apply=True)
        self.assertEqual((first['history_players'], second['history_players']), (1, 0))
        self.assertEqual(self.client.iter_transfers_by_player.call_args_list, [call(1)])
        self.assertEqual(self.sql.execute('SELECT transfer_id FROM transfers ORDER BY transfer_id').fetchall(), [(90,), (100,)])
        self.assertEqual(self.names(), before_names)
        self.assertEqual(first['start_date'], '2026-09-19')

    def test_comparison_uses_all_saved_fields_including_null_zero_and_missing_record(self):
        original = movement()
        stored = transfers.build_transfer_rows(1, [original], set())['rows']
        for changes in ({'amount': 0}, {'date': '2026-09-25'}, {'type_id': 218},
                        {'toteam': team(20), 'to_team_id': 20}, {'player_id': 2, 'player': profile(2)}):
            with self.subTest(changes=changes):
                changed = sync.changed_player_ids([{**original, **changes}], stored, {10}, {1})
                self.assertIn(1, changed)
        self.assertEqual(sync.changed_player_ids([original], stored, {10}, {1}), set())
        self.assertEqual(sync.changed_player_ids([], stored, {10}, {1}), {1})
        self.assertEqual(sync.changed_player_ids([{**original, 'completed': False}], stored, {10}, {1}), {1})
        self.assertEqual(sync.changed_player_ids([movement(pid=999, source=80, target=90)], [], {10}, {1}), set())
        # 대상과 무관한 전 세계 원문은 저장 필드 검증 대상으로 끌어들이지 않아요.
        self.assertEqual(sync.changed_player_ids([dict(id=999, player_id=999, from_team_id=80, to_team_id=90)], [], {10}, {1}), set())

    def test_date_moved_into_recent_range_compares_original_db_row(self):
        old = movement(day='2026-08-01')
        new = movement(day='2026-09-25')
        self.store([old])
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([new])
        self.client.iter_transfers_by_player.side_effect = lambda pid: self.api([new])
        self.assertEqual(sync.sync_current_transfers(apply=True)['changed_players'], 1)
        self.assertEqual(self.sql.execute('SELECT transfer_date FROM transfers').fetchone(), (date(2026, 9, 25),))

    def test_departure_renewal_without_transfer_change_does_not_fetch_history(self):
        departed = movement(pid=4, source=10, target=30, day='2026-07-01')
        self.store([departed])
        current = {**member(4), 'team': team(30), 'transfer_id': 100, 'end': '2031-06-30'}
        self.client.get_player_current_teams.side_effect = lambda pid: self.api([current])
        result = sync.sync_current_transfers(apply=True)
        self.assertEqual((result['departure_players'], result['history_players']), (1, 0))
        self.client.iter_transfers_by_player.assert_not_called()
        self.assertEqual(self.sql.execute('SELECT team_id,player_id,end_date,transfer_id FROM player_contracts').fetchone(),
                         (30, 4, date(2031, 6, 30), 100))

    def test_weekly_reconciliation_discovers_old_dated_new_transfers_and_old_deletions(self):
        self.store([movement(tid=90, day='2020-01-01')])
        new = movement(pid=5, day='2026-07-02')
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([new] if start.month == 7 else [])
        self.client.iter_transfers_by_player.side_effect = lambda pid: self.api([new] if pid == 5 else [])
        result = sync.reconcile_current_transfers(apply=True)
        self.assertEqual(result['history_players'], 4)
        self.assertEqual(self.client.iter_transfers_by_player.call_args_list, [call(1), call(2), call(3), call(5)])
        self.assertEqual(self.sql.execute('SELECT transfer_id,player_id FROM transfers').fetchall(), [(100, 5)])
        self.assertEqual(self.names(5)[:2], (None, None))

    def test_full_history_updates_contract_before_deleting_old_restricted_reference(self):
        self.store([movement(tid=90)])
        self.sql.execute("INSERT INTO player_contracts VALUES(10,1,'2025-07-01','2028-06-30',90)")
        self.sql.commit()
        new = movement()
        self.client.iter_transfers_by_player.side_effect = lambda pid: self.api([new])
        self.client.get_player_current_teams.side_effect = lambda pid: self.api([{**member(1), 'team': team(10), 'transfer_id': 100}])
        sync.sync_player_history_and_contracts(self.client, 1, {10, 30}, history=True, apply=True)
        self.assertEqual(self.sql.execute('SELECT transfer_id FROM transfers').fetchall(), [(100,)])
        self.assertEqual(self.sql.execute('SELECT transfer_id FROM player_contracts').fetchone(), (100,))
        self.client.get_transfer.assert_not_called()

    def test_current_contract_reference_absent_from_history_is_preserved(self):
        self.store([movement(tid=90)])
        self.sql.execute("INSERT INTO player_contracts VALUES(10,1,'2025-07-01','2028-06-30',90)")
        self.sql.commit()
        before = list(self.sql.iterdump())
        self.client.get_player_current_teams.side_effect = lambda pid: self.api(None)
        preview = sync.sync_player_history_and_contracts(self.client, 1, set(), history=True, apply=False)
        result = sync.sync_player_history_and_contracts(self.client, 1, set(), history=True, apply=True)
        self.assertEqual(result['retained_contract_transfer_ids'], [90])
        self.assertEqual(preview['retained_contract_transfer_ids'], result['retained_contract_transfer_ids'])
        self.assertTrue(result['contract_unavailable'])
        self.assertEqual(list(self.sql.iterdump()), before)

    def test_empty_current_teams_is_authoritative_and_clears_contract_and_stale_history(self):
        self.store([movement(tid=90)])
        self.sql.execute("INSERT INTO player_contracts VALUES(10,1,'2025-07-01','2028-06-30',90)")
        self.sql.commit()
        sync.sync_player_history_and_contracts(self.client, 1, set(), history=True, apply=True)
        self.assertEqual(self.sql.execute('SELECT * FROM transfers').fetchall(), [])
        self.assertEqual(self.sql.execute('SELECT * FROM player_contracts').fetchall(), [])

    def test_missing_contract_transfer_is_fetched_before_squad_transaction(self):
        self.client.get_team_squad.side_effect = lambda tid: self.api([{**member(1), 'transfer_id': 100}] if tid == 10 else [member(2)])
        self.client.get_transfer.side_effect = lambda tid: self.api(movement())
        before_names = self.names()
        player_sync.sync_current_squads(apply=True)
        self.client.get_transfer.assert_called_once_with(100)
        self.assertEqual(self.sql.execute('SELECT transfer_id FROM player_contracts WHERE player_id=1').fetchone(), (100,))
        self.assertEqual(self.names(), before_names)

    def test_contract_dependency_reuses_supplied_transfer_without_single_fetch(self):
        self.client.get_team_squad.side_effect = lambda tid: self.api([{**member(1), 'transfer_id': 100}] if tid == 10 else [member(2)])
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([movement()])
        player_sync.sync_current_squads(apply=True)
        self.client.get_transfer.assert_not_called()

    def test_squad_contract_dependency_cannot_hide_new_player_career_from_incremental_sync(self):
        old = movement(tid=90, source=20, target=30, day='2020-01-01')
        new = movement()
        self.client.get_team_squad.side_effect = lambda tid: self.api([{**member(1), 'transfer_id': 100}] if tid == 10 else [member(2)])
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([new])
        self.client.iter_transfers_by_player.side_effect = lambda pid: self.api([old, new])
        player_sync.sync_current_squads(apply=True)
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([new])
        result = sync.sync_current_transfers(apply=True)
        self.assertEqual(result['history_players'], 0)
        self.assertEqual(self.sql.execute('SELECT transfer_id FROM transfers ORDER BY transfer_id').fetchall(), [(90,), (100,)])

    def test_unknown_contract_dependency_and_wrong_player_preserve_team(self):
        self.client.get_team_squad.side_effect = lambda tid: self.api([{**member(1), 'transfer_id': 100}])
        before = list(self.sql.iterdump())
        for value in (None, movement(pid=2), movement(completed=False)):
            self.client.get_transfer.side_effect = lambda tid: self.api(value)
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, 'Unresolved contract transfer'):
                player_sync.sync_current_squads(apply=True)
            self.assertEqual(list(self.sql.iterdump()), before)

    def test_partial_page_failure_writes_nothing(self):
        def broken(start, end):
            yield movement()
            raise RuntimeError('page two failed')
        self.client.iter_transfers_between_dates.side_effect = broken
        before = list(self.sql.iterdump())
        with self.assertRaisesRegex(RuntimeError, 'page two failed'):
            sync.sync_current_transfers(apply=True)
        self.assertEqual(list(self.sql.iterdump()), before)
        self.client.iter_transfers_by_player.assert_not_called()

    def test_contract_failure_rolls_back_history_and_existing_contract(self):
        self.store([movement(tid=90)])
        self.sql.executescript("""INSERT INTO player_contracts VALUES(10,1,'2025-07-01','2028-06-30',90);
            CREATE TRIGGER reject_contract BEFORE INSERT ON player_contracts BEGIN SELECT RAISE(ABORT, 'contract rejected'); END;""")
        self.client.iter_transfers_by_player.side_effect = lambda pid: self.api([movement()])
        self.client.get_player_current_teams.side_effect = lambda pid: self.api([{**member(1), 'team': team(10), 'transfer_id': 100}])
        before = list(self.sql.iterdump())
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'contract rejected'):
            sync.sync_player_history_and_contracts(self.client, 1, set(), history=True, apply=True)
        self.assertEqual(list(self.sql.iterdump()), before)

    def test_preview_and_full_history_api_failure_preserve_all_data(self):
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([movement()])
        self.client.iter_transfers_by_player.side_effect = lambda pid: self.api([movement()])
        before = list(self.sql.iterdump())
        self.assertFalse(sync.sync_current_transfers()['apply'])
        self.assertEqual(list(self.sql.iterdump()), before)
        self.client.iter_transfers_by_player.side_effect = RuntimeError('history failed')
        with self.assertRaisesRegex(RuntimeError, 'history failed'):
            sync.sync_current_transfers(apply=True)
        self.assertEqual(list(self.sql.iterdump()), before)

    def test_date_chunks_have_no_gaps_and_never_exceed_31_days(self):
        sync.fetch_transfers_between(self.client, date(2026, 7, 1), date(2026, 9, 25))
        self.assertEqual(self.client.iter_transfers_between_dates.call_args_list, [
            call(date(2026, 7, 1), date(2026, 7, 31)),
            call(date(2026, 8, 1), date(2026, 8, 31)),
            call(date(2026, 9, 1), date(2026, 9, 25)),
        ])

    def test_shared_season_source_covers_internal_and_external_movements_once(self):
        outgoing = movement(source=10, target=30)
        internal = movement(tid=101, source=10, target=20)
        unrelated = movement(tid=102, source=80, target=90)
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api([outgoing, internal, unrelated])
        rows = sync.fetch_current_team_transfers(self.client, [
            {'team_id': 10, 'season_name': '2026/2027'}, {'team_id': 20, 'season_name': '2026/2027'},
        ], date(2026, 9, 25))
        self.assertEqual([item['id'] for item in rows[10]], [100, 101])
        self.assertEqual([item['id'] for item in rows[20]], [101])
        self.assertEqual(self.client.iter_transfers_between_dates.call_count, 3)
        self.client.iter_transfers_by_team.assert_not_called()

    def test_new_cli_modes_default_to_preview(self):
        from one_touch_loader.loaders import injuries_loader
        for mode, module, name in [('transfers', sync, 'sync_current_transfers'),
                                   ('transfer-reconciliation', sync, 'reconcile_current_transfers'),
                                   ('injuries', injuries_loader, 'sync_current_injuries')]:
            for apply in (False, True):
                with self.subTest(mode=mode, apply=apply), \
                        patch('sys.argv', ['cli', 'current-season', mode] + (['--apply'] if apply else [])), \
                        patch.object(module, name, return_value={}) as run:
                    cli.main()
                    run.assert_called_once_with(apply=apply)
