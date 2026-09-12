from __future__ import annotations

import copy
import io
import json
import re
import sqlite3
import unittest
from contextlib import ExitStack, redirect_stdout
from datetime import date
from pathlib import Path
from unittest.mock import MagicMock, patch

# 이 테스트는 SQLite와 보관한 원문만 사용해요. 모듈을 읽을 때 운영 DB 풀을 열지 않아요.
with patch("mysql.connector.pooling.MySQLConnectionPool") as pool_factory:
    pool_factory.return_value.get_connection.side_effect = AssertionError("Operational DB access in isolated tests")
    from one_touch_loader.core import db

from one_touch_loader import cli
from one_touch_loader.core import transfer_windows
from one_touch_loader.core.sportmonks import SportmonksClient
from one_touch_loader.core.transfer_team_levels import VERIFIED_NON_SENIOR_TEAM_IDS, VERIFIED_SENIOR_TEAM_IDS
from one_touch_loader.loaders import transfers_loader as transfers
from one_touch_loader.loaders import player_contracts_loader as contracts
from one_touch_loader.loaders import team_squad_members_loader as squads
from one_touch_loader.api.repos import transfers_repo, contracts_repo
from one_touch_loader.api.routes import teams as routes
from one_touch_loader.api.schemas.common import TeamContractsResponse

CASES = json.loads((Path(__file__).parent / "fixtures/sportmonks_transfers_contracts_verified.json").read_text(encoding="utf-8"))
SENIOR = {6, 14, 18, 33, 42, 83, 109, 113, 503, 594, 794, 459, 1079, 2708, 3319, 3321, 3543, 7980} | VERIFIED_SENIOR_TEAM_IDS


def sqlite_ddl(text):
    text = re.sub(r"^  KEY \w+ \([^\n]+\),\n", "", text, flags=re.MULTILINE)
    text = text.replace("ENUM('summer','winter')", "TEXT")
    return re.sub(r"\) ENGINE=[^;]+;", ");", text)


class TransfersContractsTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(redirect_stdout(io.StringIO()))
        self.sql = sqlite3.connect(":memory:", detect_types=sqlite3.PARSE_DECLTYPES)
        self.addCleanup(self.sql.close)
        self.sql.execute("PRAGMA foreign_keys=ON")
        self.sql.executescript("""
            CREATE TABLE teams (team_id BIGINT PRIMARY KEY, name TEXT, short_code TEXT, image_path TEXT);
            CREATE TABLE players (player_id BIGINT PRIMARY KEY, display_name TEXT, image_path TEXT);
            CREATE TABLE seasons (season_id BIGINT PRIMARY KEY, competition_id BIGINT, name TEXT, is_current INT);
            CREATE TABLE team_squad_members (team_id BIGINT, season_id BIGINT, player_id BIGINT, jersey_number INT);
            CREATE TABLE team_transfers (id INT);
            CREATE TABLE transfer_windows (id INT);
            INSERT INTO seasons VALUES (28083,8,'2026/2027',1),(25000,8,'2025/2026',0);
        """)
        folder = Path(__file__).parents[1] / "one_touch_loader/sql"
        for name in ("migrate_transfers_contracts_minimal.sql", "create_transfers.sql", "create_player_contracts.sql"):
            self.sql.executescript(sqlite_ddl((folder / name).read_text(encoding="utf-8")))
        for pid in (832, 997, 4313, 163152, 185658, 25162, 11353231):
            self.sql.execute("INSERT INTO players VALUES (?, ?, NULL)", (pid, f"Existing {pid}"))
        self.sql.commit()
        self.stack.enter_context(patch.object(db, "get_conn", side_effect=self.connection))
        for repo in (transfers_repo, contracts_repo):
            self.stack.enter_context(patch.object(repo, "fetch_all_dict", side_effect=self.fetch_dicts))
        self.stack.enter_context(patch.object(transfers_repo, "load_senior_team_ids", return_value=SENIOR))

    def connection(self):
        conn, cur = MagicMock(), MagicMock()
        raw = self.sql.cursor()
        cur.__enter__.return_value = cur
        def translated(sql):
            sql = sql.replace("%s", "?").replace("ON DUPLICATE KEY UPDATE", "ON CONFLICT DO UPDATE SET")
            return re.sub(r"VALUES\((\w+)\)", r"excluded.\1", sql)
        cur.execute.side_effect = lambda sql, args=(): raw.execute(translated(sql), args)
        cur.executemany.side_effect = lambda sql, rows: raw.executemany(translated(sql), rows)
        cur.fetchall.side_effect = raw.fetchall
        cur.fetchone.side_effect = raw.fetchone
        conn.cursor.return_value = cur
        conn.commit.side_effect = self.sql.commit
        conn.rollback.side_effect = self.sql.rollback
        return conn

    def fetch_dicts(self, sql, args=()):
        cur = self.sql.execute(sql.replace("%s", "?"), args)
        return [dict(zip([c[0] for c in cur.description], row)) for row in cur.fetchall()]

    def store(self, player_id):
        rows = transfers.build_transfer_rows(player_id, CASES["players"][str(player_id)], SENIOR)
        transfers.replace_player_transfers(player_id, rows)
        return rows

    def test_son_history_excludes_youth_and_reserve_without_cutting_2010(self):
        rows = self.store(4313)
        self.assertEqual(len(rows["rows"]), 5)
        clubs = transfers_repo.get_player_club_history(4313, date(2026,9,9))["clubs"]
        self.assertEqual([x["team_id"] for x in clubs], [147671,6,3321,2708])
        self.assertEqual(clubs[-1]["start_date"], date(2010,7,1))
        self.assertEqual(clubs[1]["end_date"], date(2025,8,6))
        self.assertEqual(self.sql.execute("SELECT display_name FROM players WHERE player_id=4313").fetchone()[0], "Existing 4313")
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM teams WHERE team_id=264161").fetchone()[0], 1)
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM teams WHERE team_id=260131").fetchone()[0], 0)
        self.assertEqual(self.sql.execute("SELECT from_team_id FROM transfers WHERE transfer_id=319138").fetchone()[0],3504)

    def test_kane_loan_teams_and_distinct_returns_are_preserved(self):
        self.store(997)
        clubs = transfers_repo.get_player_club_history(997,date(2026,9,9))["clubs"]
        self.assertTrue({294,64,33,42}.issubset({x["team_id"] for x in clubs}))
        self.assertEqual(sum(x["team_id"] == 6 for x in clubs), 5)
        self.assertEqual(clubs[0]["team_id"],503)

    def test_conversion_without_return_does_not_invent_second_parent_spell(self):
        rows = transfers.build_transfer_rows(25162, CASES["becker_conversion"], SENIOR)
        self.assertEqual(rows["repeated_movements"], [])
        transfers.replace_player_transfers(25162,rows)
        clubs = transfers_repo.get_player_club_history(25162,date(2026,9,9))["clubs"]
        self.assertEqual(len(clubs),2)
        self.assertEqual(clubs[0]["start_date"],date(2026,2,2))
        self.assertIsNone(clubs[1]["start_date"])

    def test_actual_free_agent_gap_is_not_filled_with_next_arrival_or_contract_end(self):
        self.store(832)
        current=contracts.build_contract_rows(109,CASES["de_gea_contract"],{832})
        self.sql.executemany("INSERT INTO player_contracts VALUES (?,?,?,?,?)",current["rows"])
        clubs=transfers_repo.get_player_club_history(832,date(2026,9,9))["clubs"]
        self.assertEqual([x["team_id"] for x in clubs],[109,14,7980])
        self.assertEqual(clubs[1]["end_date"],date(2023,7,1))
        self.assertEqual(clubs[0]["start_date"],date(2024,8,9))
        self.assertIsNone(clubs[0]["end_date"])
        window={"start_date":date(2023,6,1),"end_date":date(2023,9,1)}
        departure=transfers_repo.get_team_transfers_by_window(14,28083,window,date(2026,9,9))[0]
        self.assertIsNone(departure["to_team_id"])
        # 이탈일을 옛 계약 종료일로 쓰거나 새 팀의 현재 계약을 출발팀에 붙이지 않아요.
        self.assertIsNone(departure["contract_end_date"])

    def test_unprovided_departure_date_is_not_replaced_by_later_arrival(self):
        payload=[x for x in CASES["players"]["832"] if x["id"]!=226221]
        transfers.replace_player_transfers(832,transfers.build_transfer_rows(832,payload,SENIOR))
        clubs=transfers_repo.get_player_club_history(832,date(2026,9,9))["clubs"]
        self.assertIsNone(next(x for x in clubs if x["team_id"]==14)["end_date"])
        self.assertEqual(clubs[0]["start_date"],date(2024,8,9))

    def test_actual_repeated_griezmann_movement_is_reviewed_before_write(self):
        rows = transfers.build_transfer_rows(185658,CASES["players"]["185658"],SENIOR)
        self.assertEqual(rows["repeated_movements"],[[560549,579015]])
        with self.assertRaisesRegex(ValueError,"Review transfer source"):
            transfers.replace_player_transfers(185658,rows)
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM transfers").fetchone()[0],0)

    def test_user_selected_griezmann_date_is_shared_by_all_transfer_queries(self):
        client = SportmonksClient.__new__(SportmonksClient)
        payload = CASES["players"]["185658"]
        queries = (
            lambda: client.iter_transfers_by_player(185658),
            lambda: client.iter_transfers_by_team(7980),
            lambda: client.iter_transfers_between_dates(date(2026,7,1),date(2026,7,31)),
        )
        with patch.object(client,"_iter_paginated_data",side_effect=lambda *args,**kwargs: iter(payload)):
            for query in queries:
                selected = list(query())
                self.assertNotIn(560549,[x["id"] for x in selected])
                self.assertIn(579015,[x["id"] for x in selected])
                rows = transfers.build_transfer_rows(185658,selected,SENIOR)
                self.assertEqual(rows["repeated_movements"],[])
                transfers.replace_player_transfers(185658,rows)
                clubs = transfers_repo.get_player_club_history(185658,date(2026,9,9))["clubs"]
                self.assertEqual(clubs[0]["team_id"],204)
                self.assertEqual(clubs[0]["start_date"],date(2026,7,13))
                self.assertEqual(clubs[1]["end_date"],date(2026,7,13))

    def test_unknown_team_is_preserved_and_hidden_after_history_dates_are_built(self):
        rows = transfers.build_transfer_rows(4313,CASES["players"]["4313"],SENIOR-{147671})
        self.assertEqual(rows["unclassified_teams"],{147671:"Los Angeles FC"})
        transfers.replace_player_transfers(4313,rows)
        with patch.object(transfers_repo,"load_senior_team_ids",return_value=SENIOR-{147671}):
            clubs=transfers_repo.get_player_club_history(4313,date(2026,9,9))["clubs"]
        self.assertEqual([x["team_id"] for x in clubs],[6,3321,2708])
        self.assertEqual(clubs[0]["end_date"],date(2025,8,6))
        self.assertEqual(self.sql.execute("SELECT to_team_id FROM transfers WHERE transfer_id=496239").fetchone()[0],147671)

    def test_verified_duplicate_selection_preserves_source_contract_reference(self):
        client=SportmonksClient.__new__(SportmonksClient)
        for case in CASES["verified_duplicate_transfers"]:
            contract=case["contract"]
            with patch.object(client,"_iter_paginated_data",return_value=iter(case["transfers"])):
                selected=list(client.iter_transfers_by_player(contract["player_id"]))
            self.assertEqual(len(selected),len(case["transfers"])-1)
            self.assertIn(contract["transfer_id"],{x["id"] for x in selected})
            rows=transfers.build_transfer_rows(contract["player_id"],selected,SENIOR)
            self.assertEqual(rows["repeated_movements"],[])

    def test_web_verified_players_keep_only_the_supported_transfer(self):
        client=SportmonksClient.__new__(SportmonksClient)
        for case in CASES["web_verified_transfer_choices"]:
            with self.subTest(player_id=case["player_id"]):
                original=copy.deepcopy(case["transfers"])
                with patch.object(client,"_iter_paginated_data",side_effect=lambda *a,**kw:iter(case["transfers"])):
                    queries=(client.iter_transfers_by_player(case["player_id"]),client.iter_transfers_by_team(6),
                             client.iter_transfers_between_dates(date(2023,1,1),date(2026,9,9)))
                    for query in queries:
                        selected=list(query)
                        self.assertNotIn(case["excluded_id"],{x["id"] for x in selected})
                        retained=next(x for x in selected if x["id"]==case["retained_id"])
                        self.assertEqual(retained["date"],case["date"])
                self.assertEqual(case["transfers"],original)
                rows=transfers.build_transfer_rows(case["player_id"],selected,SENIOR)
                self.assertEqual(rows["repeated_movements"],[])

    def test_current_market_corrections_preserve_contract_dates_and_foreign_keys(self):
        client=SportmonksClient.__new__(SportmonksClient)
        payloads={str(c["player_id"]):c["transfers"] for c in CASES["web_verified_transfer_choices"]}
        payloads.update(CASES["web_unresolved_transfers"])
        for key,records in CASES["refresh_current_contracts"].items():
            pid=int(key)
            with self.subTest(player_id=pid):
                self.sql.execute("INSERT INTO players VALUES (?, ?, NULL)",(pid,f"Player {pid}"))
                with patch.object(client,"_iter_paginated_data",return_value=iter(payloads[key])):
                    selected=list(client.iter_transfers_by_player(pid))
                rows=transfers.build_transfer_rows(pid,selected,SENIOR)
                transfers.replace_player_transfers(pid,rows)
                for member in records:
                    team=member["team"]
                    if team["type"]=="national" or team["placeholder"] or team["id"] in VERIFIED_NON_SENIOR_TEAM_IDS:
                        continue
                    self.sql.execute("INSERT OR IGNORE INTO teams VALUES (?, ?, NULL, NULL)",(team["id"],team["name"]))
                    contract_rows=contracts.build_contract_rows(team["id"],[member],{pid})["rows"]
                    self.sql.executemany("INSERT INTO player_contracts VALUES (?,?,?,?,?)",contract_rows)
                    for _,_,start,end,transfer_id in contract_rows:
                        self.assertEqual(start.isoformat() if start else None,member["start"])
                        self.assertEqual(end.isoformat() if end else None,member["end"])
                        if transfer_id is not None:
                            relation=self.sql.execute("SELECT player_id,to_team_id FROM transfers WHERE transfer_id=?",(transfer_id,)).fetchone()
                            self.assertEqual(relation,(pid,team["id"]))
                # 계약이 연결된 뒤 재적재해도 확인한 원문 ID를 보존해야 해요.
                self.sql.commit()
                transfers.replace_player_transfers(pid,rows)
        self.assertEqual(self.sql.execute("PRAGMA foreign_key_check").fetchall(),[])
        for pid,transfer_id in ((98868,578073),(37564744,578112)):
            self.assertEqual(self.sql.execute("SELECT transfer_date FROM transfers WHERE transfer_id=?",(transfer_id,)).fetchone()[0],date(2026,7,9))
            self.assertEqual(self.sql.execute("SELECT start_date FROM player_contracts WHERE player_id=?",(pid,)).fetchone()[0],date(2026,7,22))

    def test_verified_mata_termination_keeps_the_gap_before_racing_arrival(self):
        case=next(c for c in CASES["web_verified_transfer_choices"] if c["player_id"]==188713)
        client=SportmonksClient.__new__(SportmonksClient)
        self.sql.execute("INSERT INTO players VALUES (188713,'Jaime Mata',NULL)")
        with patch.object(client,"_iter_paginated_data",return_value=iter(case["transfers"])):
            selected=list(client.iter_transfers_by_player(188713))
        transfers.replace_player_transfers(188713,transfers.build_transfer_rows(188713,selected,SENIOR))
        with patch.object(transfers_repo,"load_senior_team_ids",return_value=SENIOR|{2921,9818}):
            clubs=transfers_repo.get_player_club_history(188713,date(2026,9,10))["clubs"]
        self.assertEqual(next(c for c in clubs if c["team_id"]==2921)["end_date"],date(2025,12,21))
        self.assertEqual(next(c for c in clubs if c["team_id"]==9818)["start_date"],date(2026,2,9))

    def test_web_unresolved_source_can_be_stored_without_fabricating_dates(self):
        for pid,payload in CASES["web_unresolved_transfers"].items():
            pid=int(pid)
            self.sql.execute("INSERT INTO players VALUES (?, ?, NULL)",(pid,f"Player {pid}"))
            rows=transfers.build_transfer_rows(pid,payload,SENIOR)
            transfers.replace_player_transfers(pid,rows)
            stored=self.sql.execute("SELECT transfer_id FROM transfers WHERE player_id=?",(pid,)).fetchall()
            self.assertEqual({x[0] for x in stored},{x["id"] for x in payload if x["completed"]})
            self.assertEqual(transfers_repo.get_player_club_history(pid,date(2026,9,9))["clubs"],[])
        member=CASES["web_unresolved_contract"]
        contract_rows=contracts.build_contract_rows(member["team_id"],[member],{member["player_id"]})["rows"]
        self.sql.executemany("INSERT INTO player_contracts VALUES (?,?,?,?,?)",contract_rows)
        self.sql.execute("INSERT INTO team_squad_members VALUES (?,28083,?,NULL)",(member["team_id"],member["player_id"]))
        visible=contracts_repo.get_team_contracts(member["team_id"],28083)["players"]
        self.assertEqual(visible[0]["end_date"],date.fromisoformat(member["end"]))
        window={"start_date":date(2026,1,1),"end_date":date(2026,9,1)}
        self.assertEqual(transfers_repo.get_team_transfers_by_window(member["team_id"],28083,window,date(2026,9,9)),[])

    def test_approved_source_pair_does_not_hide_a_new_conflict(self):
        pid=32387131
        source=copy.deepcopy(CASES["web_unresolved_transfers"][str(pid)])
        source.append(dict(next(x for x in source if x["id"]==592402),id=99999999,date="2026-08-25"))
        rows=transfers.build_transfer_rows(pid,source,SENIOR)
        self.assertTrue(rows["repeated_movements"])
        with self.assertRaisesRegex(ValueError,"Review transfer source"):
            transfers.replace_player_transfers(pid,rows)

    def test_check_reports_approved_withheld_player_without_writing(self):
        pid=32387131
        with patch.object(transfers,"load_senior_team_ids",return_value=SENIOR),patch.object(transfers,"SportmonksClient") as client,patch.object(transfers,"replace_player_transfers") as writer:
            client.return_value.iter_transfers_by_player.return_value=CASES["web_unresolved_transfers"][str(pid)]
            result=transfers.collect_player_transfers([pid],check=True)
            self.assertEqual(result["review_players"],[])
            self.assertEqual(result["withheld_players"],[pid])
            writer.assert_not_called()

    def test_hidden_loan_club_does_not_merge_parent_club_spells(self):
        self.store(997)
        with patch.object(transfers_repo,"load_senior_team_ids",return_value=SENIOR-{294,64,33,42}):
            clubs=transfers_repo.get_player_club_history(997,date(2026,9,9))["clubs"]
        self.assertEqual(sum(x["team_id"]==6 for x in clubs),5)
        self.assertFalse({294,64,33,42} & {x["team_id"] for x in clubs})

    def test_actual_pending_transfer_is_not_completed_history(self):
        item = CASES["pending"]
        self.assertEqual(transfers.build_transfer_rows(item["player_id"],[item],SENIOR)["rows"],[])

    def test_missing_fee_and_provided_zero_remain_different(self):
        payload = copy.deepcopy(CASES["players"]["4313"])
        payload[0]["amount"] = 0
        rows = transfers.build_transfer_rows(4313,payload,SENIOR)["rows"]
        self.assertIn(0,[x[5] for x in rows])
        self.assertIn(None,[x[5] for x in rows])

    def test_failed_replace_rolls_back_deleted_history(self):
        rows = self.store(4313)
        broken = copy.deepcopy(rows)
        row=list(broken["rows"][0]);row[2]=999999;broken["rows"][0]=tuple(row)
        with self.assertRaises(sqlite3.IntegrityError):
            transfers.replace_player_transfers(4313,broken)
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM transfers").fetchone()[0],5)

    def test_empty_verified_history_replaces_only_selected_player(self):
        self.store(4313);self.store(997)
        transfers.replace_player_transfers(4313,transfers.build_transfer_rows(4313,[],SENIOR))
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM transfers WHERE player_id=4313").fetchone()[0],0)
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM transfers WHERE player_id=997").fetchone()[0],10)

    def test_current_contracts_preserve_partial_dates_and_reject_actual_bad_intervals(self):
        for tid in (6,18,794,1079):
            source=CASES["contracts"][str(tid)]
            result=contracts.build_contract_rows(tid,source,{x["player_id"] for x in source})
            self.assertEqual(len(result["invalid_intervals"]),int(tid in (794,1079)))
            self.assertTrue(all(x[2] is None or x[3] is None or x[2]<=x[3] for x in result["rows"]))
        source=CASES["contracts"]["6"]
        partial=next(x for x in source if x["end"] is None)
        result=contracts.build_contract_rows(6,[partial],{partial["player_id"],999})
        self.assertIsNone(result["rows"][0][3]);self.assertEqual(result["missing_players"],[999])
        self.assertEqual(contracts.build_contract_rows(6,source,set())["rows"],[])

    def test_contract_sort_keeps_db_squad_players_with_missing_dates_last(self):
        self.sql.execute("INSERT INTO teams VALUES (6,'Spurs',NULL,NULL)")
        for pid in (997,4313,163152):
            self.sql.execute("INSERT INTO team_squad_members VALUES (6,28083,?,NULL)",(pid,))
        self.sql.execute("INSERT INTO player_contracts VALUES (6,997,'2023-08-12','2027-06-30',NULL),(6,4313,NULL,'2029-06-30',NULL)")
        for descending, expected in ((False,[997,4313,163152]),(True,[4313,997,163152])):
            result=contracts_repo.get_team_contracts(6,28083,descending=descending)
            self.assertEqual([x["player_id"] for x in result["players"]],expected)
            TeamContractsResponse.model_validate(result)

    def test_latest_window_changes_on_opening_day_and_keeps_closed_window(self):
        self.sql.execute("INSERT INTO transfer_windows VALUES (28083,'summer','2026-06-15','2026-09-01'),(28083,'winter','2027-01-01','2027-02-01')")
        self.assertEqual(transfer_windows.get_latest_transfer_window(8,date(2026,12,31))["window_name"],"summer")
        self.assertEqual(transfer_windows.get_latest_transfer_window(8,date(2027,1,1))["window_name"],"winter")
        self.assertIsNone(transfer_windows.get_latest_transfer_window(82,date(2026,9,9)))

    def test_transfer_api_joins_profile_counterparty_and_only_same_arrival_contract(self):
        self.store(4313)
        self.sql.execute("INSERT INTO player_contracts VALUES (147671,4313,'2025-08-06','2027-12-31',496239)")
        window={"season_id":25000,"start_date":date(2025,6,1),"end_date":date(2025,9,1)}
        row=transfers_repo.get_team_transfers_by_window(6,28083,window,date(2026,9,9))[0]
        dto=routes._build_transfer_out(row,6)
        self.assertEqual(dto.other_team_id,147671);self.assertEqual(dto.direction,"out")
        self.assertEqual(dto.contract_end_date,date(2027,12,31));self.assertIsNone(dto.currency)
        self.assertEqual(dto.display_type,"Transfer")
        self.sql.execute("UPDATE player_contracts SET transfer_id=NULL")
        row=transfers_repo.get_team_transfers_by_window(6,28083,window,date(2026,9,9))[0]
        self.assertIsNone(row["contract_end_date"])

    def test_transfers_check_never_calls_writer(self):
        with patch.object(transfers,"load_senior_team_ids",return_value=SENIOR), patch.object(transfers,"SportmonksClient") as client, patch.object(transfers,"replace_player_transfers") as writer:
            client.return_value.iter_transfers_by_player.return_value=CASES["players"]["4313"]
            result=transfers.collect_player_transfers([4313],check=True)
            self.assertEqual(result["transfers"],5);writer.assert_not_called()

    def test_contracts_check_never_calls_transaction(self):
        source=CASES["contracts"]["6"]
        with patch.object(contracts,"load_squad_scope",return_value=[{"team_id":6,"season_id":28083}]), patch.object(contracts,"fetch_all",return_value=[(x["player_id"],) for x in source]), patch.object(contracts,"SportmonksClient") as client, patch.object(contracts,"transaction") as writer:
            client.return_value.get_team_squad.return_value=source
            result=contracts.refresh_current_contracts(check=True)
            self.assertEqual(result["contracts"],len(source));writer.assert_not_called()

    def test_cli_exact_window_arguments_and_check_propagation(self):
        with patch("sys.argv",["cli","transfer-windows","2026/2027","8","summer","2026-06-15","2026-09-01"]),patch.object(cli,"set_transfer_window") as run:
            cli.main();run.assert_called_once_with("2026/2027",8,"summer",date(2026,6,15),date(2026,9,1))
        with patch("sys.argv",["cli","transfers","2026/2027","8","--check"]),patch.object(cli,"collect_transfers_for_season",return_value={"review_players":[]}) as run:
            cli.main();run.assert_called_once_with("2026/2027",[8],check=True)
        with patch("sys.argv",["cli","contracts","refresh-current","6,18","--check"]),patch.object(cli,"refresh_current_contracts",return_value={}) as run:
            cli.main();run.assert_called_once_with([6,18],check=True)

    def test_recent_transfers_share_league_window_and_load_full_selected_history(self):
        scope=[{"team_id":6,"competition_id":8},{"team_id":18,"competition_id":8}]
        window={"season_id":25000,"start_date":date(2025,8,1),"end_date":date(2025,8,31)}
        item=next(x for x in CASES["players"]["4313"] if x["id"]==496239)
        with patch.object(transfers,"load_squad_scope",return_value=scope),patch.object(transfers,"get_latest_transfer_window",return_value=window) as read_window,patch.object(transfers,"SportmonksClient") as client,patch.object(transfers,"collect_player_transfers",return_value={}) as collect:
            client.return_value.iter_transfers_between_dates.return_value=[item]
            transfers.refresh_current_transfers(check=True)
            self.assertEqual(read_window.call_count,1)
            client.return_value.iter_transfers_between_dates.assert_called_once_with(date(2025,8,1),date(2025,8,31))
            collect.assert_called_once_with([4313],check=True)

    def test_shared_team_scope_selects_current_teams_and_rejects_others(self):
        source=[(8,28083,"2026/2027",1,6,"Spurs"),(8,28083,"2026/2027",1,18,"Chelsea"),
                (8,25000,"2025/2026",0,6,"Spurs")]
        with patch.object(squads,"fetch_all",return_value=source):
            selected=squads.load_squad_scope(current_only=True,team_ids=[6])
            self.assertEqual([(x["team_id"],x["season_id"]) for x in selected],[(6,28083)])
            with self.assertRaisesRegex(ValueError,"outside the selected squad scope"):
                squads.load_squad_scope(current_only=True,team_ids=[147671])

    def test_current_contract_replace_rolls_back_on_storage_failure(self):
        self.sql.execute("INSERT INTO teams VALUES (6,'Spurs',NULL,NULL)")
        self.sql.execute("INSERT INTO player_contracts VALUES (6,997,'2020-01-01','2030-01-01',NULL)")
        source=CASES["contracts"]["6"]
        self.sql.executemany("INSERT INTO team_squad_members VALUES (6,28083,?,NULL)",[(x["player_id"],) for x in source])
        self.sql.commit()
        with patch.object(contracts,"load_squad_scope",return_value=[{"team_id":6,"season_id":28083}]),patch.object(contracts,"SportmonksClient") as client:
            client.return_value.get_team_squad.return_value=source
            # 새 선수의 부모 FK가 없으면 DELETE까지 함께 롤백되어야 해요.
            with self.assertRaises(sqlite3.IntegrityError):
                contracts.refresh_current_contracts()
        self.assertEqual(self.sql.execute("SELECT player_id FROM player_contracts").fetchall(),[(997,)])

    def test_player_contracts_ignore_national_team_and_check_does_not_write(self):
        records=[{"id":1,"team_id":503,"player_id":997,"start":"2023-08-12","end":"2027-06-30","transfer_id":None,
                  "team":{"id":503,"name":"Bayern","type":"domestic","placeholder":False}},
                 {"team":{"id":18645,"type":"national","placeholder":False}}]
        with patch.object(contracts,"SportmonksClient") as client,patch.object(contracts,"transaction") as writer:
            client.return_value.get_player_current_teams.return_value=records
            result=contracts.collect_player_contracts([997],check=True)
            self.assertEqual(result["contracts"],1);writer.assert_not_called()

    def test_departure_contracts_skip_players_still_in_current_big5_squads(self):
        scope=[{"team_id":6,"competition_id":8}]
        window={"start_date":date(2025,8,1),"end_date":date(2025,8,31)}
        with patch.object(contracts,"load_squad_scope",return_value=scope),patch.object(contracts,"get_latest_transfer_window",return_value=window),patch.object(contracts,"fetch_all",side_effect=[[(997,)],[(997,),(4313,)]]),patch.object(contracts,"collect_player_contracts",return_value={}) as collect:
            contracts.refresh_departure_contracts(check=True)
            collect.assert_called_once_with([4313],check=True)

    def test_unavailable_contract_source_preserves_existing_rows_and_continues(self):
        self.sql.execute("INSERT INTO teams VALUES (6,'Spurs',NULL,NULL)")
        self.sql.executemany("INSERT INTO players VALUES (?, 'Player', NULL)",[(43393,),(47439,)])
        self.sql.executemany("INSERT INTO player_contracts VALUES (6,?,'2025-07-01','2027-06-30',NULL)",[(43393,),(47439,)])
        self.sql.commit()
        with patch.object(contracts,"SportmonksClient") as client:
            client.return_value.get_player_current_teams.side_effect=[None,[]]
            result=contracts.collect_player_contracts([43393,47439])
        self.assertEqual(result["players"],2)
        self.assertEqual(result["unavailable_players"],[43393])
        # 조회 불가는 기존 값을 보존하고, 정상 조회로 확인한 빈 소속만 교체해요.
        self.assertEqual(self.sql.execute("SELECT player_id,start_date,end_date FROM player_contracts").fetchall(),[(43393,date(2025,7,1),date(2027,6,30))])

    def test_unavailable_contract_check_reports_id_without_writing(self):
        with patch.object(contracts,"SportmonksClient") as client,patch.object(contracts,"transaction") as writer:
            client.return_value.get_player_current_teams.return_value=None
            result=contracts.collect_player_contracts([43393],check=True)
        self.assertEqual(result["players"],1)
        self.assertEqual(result["unavailable_players"],[43393])
        writer.assert_not_called()

    def test_actual_contract_date_difference_and_transfer_reload_preserve_id_link(self):
        source=CASES["contract_after_loan_return"]
        member=source["contract"]
        pid,tid=member["player_id"],member["team_id"]
        self.sql.execute("INSERT INTO players VALUES (?, 'Franz Stolz', NULL)",(pid,))
        rows=transfers.build_transfer_rows(pid,source["transfers"],SENIOR|{tid})
        transfers.replace_player_transfers(pid,rows)
        contracts_rows=contracts.build_contract_rows(tid,[member],{pid})["rows"]
        self.sql.executemany("INSERT INTO player_contracts VALUES (?,?,?,?,?)",contracts_rows)
        self.sql.commit()
        transfers.replace_player_transfers(pid,rows)
        window={"start_date":date(2026,6,1),"end_date":date(2026,7,1)}
        result=transfers_repo.get_team_transfers_by_window(tid,28083,window,date(2026,9,9))
        linked=next(row for row in result if row["transfer_id"]==440547)
        self.assertEqual(linked["transfer_date"],date(2026,6,30))
        self.assertEqual(linked["contract_start_date"],date(2024,1,27))
        self.assertEqual(linked["contract_end_date"],date(2027,6,30))
        # 공급자가 계약에서 참조 중인 이적을 제거하려 하면 전체 교체를 롤백해요.
        rows["rows"]=[row for row in rows["rows"] if row[0]!=440547]
        with self.assertRaises(sqlite3.IntegrityError):
            transfers.replace_player_transfers(pid,rows)
        self.assertEqual(self.sql.execute("SELECT transfer_id FROM player_contracts WHERE player_id=?",(pid,)).fetchone()[0],440547)


if __name__ == "__main__":
    unittest.main()
