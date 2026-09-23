"""예약 수집의 기간·중복 건너뛰기·동시 저장·명단 갱신을 확인해요."""
import copy
import json
from contextlib import contextmanager, nullcontext
from datetime import date
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from diagnostics.test_opta_bulk import CASES, StorageTests, SqliteCursor, empty_ids
from diagnostics.test_live_fixtures import live_payload
from one_touch_loader.core import db
from one_touch_loader.loaders import opta_shots_loader as loader, opta_shots_store as store


class ScheduleTests(unittest.TestCase):
    def run_sync(self, *, saved_shots=(), saved_analysis=(), apply=True, targets=None):
        raw = json.loads((Path(__file__).parent / 'fixtures/opta-valencia-analysis.json').read_text(encoding='utf-8'))
        case = CASES[1]
        eid = case['raw']['match_id']
        fid = case['fixtures'][0]['fixture_id']
        with TemporaryDirectory() as directory:
            args = SimpleNamespace(dataset='both', apply=apply, output_dir=Path(directory),
                competition_ids=[564], season='2026/2027', from_date=date(2026,9,6),
                to_date=date(2026,9,6), refresh=False, limit=None, retry_report=None,
                refresh_details=False, fixtures=targets)
            with patch.object(db,'fetch_all',side_effect=[[(1,)], list(saved_shots), [(1,)], list(saved_analysis)]), \
                 patch.object(loader,'load_known_ids',return_value=empty_ids()), \
                 patch.object(loader,'fetch_schedule',return_value={'season_name':'2026/2027','matches':[case['match']]}), \
                 patch.object(loader,'load_scope',return_value=(case['fixtures'],case['lineups'])), \
                 patch.object(loader,'open_browser',return_value=nullcontext(object())), \
                 patch.object(loader,'collect_snapshot',return_value=raw) as collect, \
                 patch.object(loader,'save_match_datasets') as save:
                report = loader.sync_matches(args)
                calls = save.call_args_list
        return report, collect, calls, eid, fid

    def test_targeted_collection_reads_only_the_requested_finished_fixture(self):
        target = copy.deepcopy(CASES[1]['fixtures'][0])
        report, collect, calls, _, _ = self.run_sync(targets=[target])
        self.assertEqual(report['stored'], 1)
        collect.assert_called_once()
        target['starting_at'] = '2026-09-07 18:00:00'
        report, collect, calls, _, _ = self.run_sync(targets=[target])
        self.assertEqual(report['stored'], 0)
        collect.assert_not_called()
        self.assertEqual(calls, [])

    def test_one_capture_saves_both_and_check_never_writes(self):
        for apply in (False, True):
            with self.subTest(apply=apply):
                report, collect, calls, _, _ = self.run_sync(apply=apply)
                self.assertEqual(report['failed'],0)
                self.assertEqual(report['ready'],1)
                self.assertEqual(report['stored'],int(apply))
                self.assertEqual(report['matches'][0]['datasets'],['shots','analysis'])
                collect.assert_called_once()
                self.assertEqual(collect.call_args.kwargs['dataset'],'analysis')
                self.assertEqual(len(calls),int(apply))

    def test_partial_data_adds_only_missing_dataset_and_complete_data_is_skipped(self):
        case=CASES[1]
        pair=(case['raw']['match_id'],case['fixtures'][0]['fixture_id'])
        report, collect, calls, _, _ = self.run_sync(saved_analysis=[pair])
        self.assertEqual(report['failed'],0)
        self.assertEqual(set(calls[0].args[0]),{'shots'})
        report, collect, calls, _, _ = self.run_sync(saved_shots=[pair],saved_analysis=[pair])
        self.assertEqual(report['skipped'],1)
        collect.assert_not_called()
        self.assertEqual(calls,[])

    def test_recent_days_is_inclusive_and_invalid_options_do_not_start_collection(self):
        with patch.object(loader,'sync_matches',return_value={'failed':0}) as sync:
            loader.sync_main(['--dataset','both','--recent-days','7','--to-date','2026-09-15','--refresh-details','--check'])
            args=sync.call_args.args[0]
            self.assertEqual((args.from_date,args.to_date),(date(2026,9,9),date(2026,9,15)))
            self.assertFalse(args.apply)
        for options in [['--recent-days','0'],['--refresh-details'],['--recent-days','7','--from-date','2026-09-01']]:
            with self.subTest(options=options),patch.object(loader,'sync_matches') as sync:
                with self.assertRaises(SystemExit): loader.sync_main(options)
                sync.assert_not_called()

    def test_refresh_uses_same_verified_provider_roster_in_check_and_apply(self):
        from one_touch_loader.core.sportmonks import SportmonksClient
        from one_touch_loader.loaders import live_fixtures_loader as live
        payload=live_payload()
        payload['state_id']=5
        for i,lineup in enumerate(payload['lineups']):
            lineup['player']={'id':lineup['player_id'],'display_name':f'Player {i}','name':f'Full Player {i}'}
        fid=payload['id']
        fixtures=[dict(fixture_id=fid,home_team_id=10,away_team_id=20,starting_at='2026-09-14 19:00:00',state_id=1),
                  dict(fixture_id=99,home_team_id=10,away_team_id=20,starting_at='2026-09-08 19:00:00',state_id=1),
                  dict(fixture_id=98,home_team_id=10,away_team_id=20,starting_at='2026-09-14 19:00:00',state_id=5)]
        for apply in (False,True):
            with self.subTest(apply=apply),patch.object(SportmonksClient,'get_live_fixtures_batch',return_value=[payload]) as read, \
                 patch.object(SportmonksClient,'correct_fixture_details',side_effect=lambda p:p), \
                 patch.object(live,'store_live_fixture') as save:
                rows=store.refresh_recent_rosters(fixtures,[],from_date=date(2026,9,9),to_date=date(2026,9,15),stored_ids={98},apply=apply)
                read.assert_called_once_with([fid])
                self.assertTrue(rows)
                self.assertEqual(rows[0]['full_name'],'Full Player 0')
                self.assertEqual(save.call_count,int(apply))
        payload['participants'][0]['id']=999
        with patch.object(SportmonksClient,'get_live_fixtures_batch',return_value=[payload]), \
             patch.object(SportmonksClient,'correct_fixture_details',side_effect=lambda p:p), \
             patch.object(live,'store_live_fixture') as save:
            with self.assertRaisesRegex(ValueError,'participants differ'):
                store.refresh_recent_rosters(fixtures,[],from_date=date(2026,9,9),to_date=date(2026,9,15),stored_ids={98},apply=True)
            save.assert_not_called()


class CombinedStorageTests(StorageTests):
    def test_second_dataset_failure_rolls_back_first_dataset_and_mappings(self):
        original=store.replace_match
        @contextmanager
        def transaction():
            with self.conn:
                yield SimpleNamespace(cursor=lambda:nullcontext(SqliteCursor(self.conn)))
        def replace(cursor,result,plan,known,collected_at,*,dataset):
            if dataset=='analysis':
                self.assertEqual(known['fixture'],self.plan['mappings']['fixture'])
                raise ValueError('second dataset failure')
            original(cursor,result,plan,known,collected_at,dataset=dataset)
        with patch.object(db,'transaction',transaction),patch.object(store,'replace_match',side_effect=replace):
            with self.assertRaisesRegex(ValueError,'second dataset failure'):
                store.save_match_datasets({'shots':self.result,'analysis':{}},self.plan,self.known,'2026-09-15T12:00:00+00:00')
        self.assertEqual(self.conn.execute('SELECT COUNT(*) FROM fixture_opta_shotmaps').fetchone()[0],0)
        self.assertEqual(self.conn.execute('SELECT COUNT(*) FROM fixture_external_ids').fetchone()[0],0)
        self.assertEqual(self.known,empty_ids())


if __name__=='__main__': unittest.main()
