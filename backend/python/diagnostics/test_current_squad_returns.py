"""현재 소속이 확인된 선수의 누락과 이후 실제 이적을 함께 검증해요."""
from copy import deepcopy
from datetime import date
import json
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch

from diagnostics.test_current_player_sync import SyncDatabaseCase, profile, sync, squads
from one_touch_loader.api.repos import player_detail_repo
from one_touch_loader.core.sportmonks import SportmonksClient


EVIDENCE = json.loads((Path(__file__).parent / "fixtures/sportmonks_current_squad_returns_verified.json")
                      .read_text(encoding="utf-8"))
CASES = EVIDENCE["cases"]
VERIFIED_ON = date.fromisoformat(EVIDENCE["verified_on"])
SEASON_START = date(2026, 7, 1)


def corrected_transfers(case):
    return [row for raw in case["transfers"]
            if (row := SportmonksClient._correct_transfer(raw)) is not None]


class CurrentSquadReturnTests(unittest.TestCase):
    def test_all_twelve_verified_players_keep_their_squad_data(self):
        for case in CASES:
            with self.subTest(player=case["name"]):
                raw_squad = [deepcopy(case["squad"])]
                transfers = corrected_transfers(case)
                before = deepcopy(transfers)
                kept, removed = squads._filter_current_squad_items(
                    raw_squad, transfers, case["team_id"], SEASON_START, VERIFIED_ON)
                self.assertEqual(kept, [case["squad"]])
                self.assertEqual(removed, set())
                self.assertEqual(transfers, before)
                if case["player_id"] != 129261:
                    # 현재 소속 보정 때문에 실제 계약 만료·매입 이력을 지우면 안 돼요.
                    self.assertEqual(transfers, case["transfers"])

    def test_later_completed_departure_still_removes_each_player(self):
        for case in CASES:
            with self.subTest(player=case["name"]):
                departure = dict(id=999999, player_id=case["player_id"],
                                 from_team_id=case["team_id"], to_team_id=999,
                                 date="2026-10-08", completed=True)
                transfers = corrected_transfers(case) + [departure]
                kept, removed = squads._filter_current_squad_items(
                    [case["squad"]], transfers, case["team_id"], SEASON_START, date(2026, 10, 8))
                self.assertEqual(kept, [])
                self.assertEqual(removed, {case["player_id"]})

    def test_verification_does_not_rewrite_earlier_membership_or_historical_squads(self):
        for case in CASES:
            if case["player_id"] == 129261:
                continue
            with self.subTest(player=case["name"]):
                transfers = corrected_transfers(case)
                kept, removed = squads._filter_current_squad_items(
                    [case["squad"]], transfers, case["team_id"], SEASON_START, date(2026, 7, 1))
                self.assertEqual(kept, [])
                self.assertEqual(removed, {case["player_id"]})
                kept, removed = squads._filter_historical_squad_items(
                    [case["squad"]], transfers, case["team_id"], SEASON_START, VERIFIED_ON, {})
                self.assertEqual(kept, [])
                self.assertIn(case["player_id"], removed)

    def test_current_source_membership_is_required_and_other_players_are_not_exempt(self):
        for case in CASES:
            with self.subTest(player=case["name"]):
                transfers = corrected_transfers(case)
                kept, removed = squads._filter_current_squad_items(
                    [], transfers, case["team_id"], SEASON_START, VERIFIED_ON)
                self.assertEqual((kept, removed), ([], set()))
                # 같은 팀·이적 ID라도 검증한 선수가 아니면 기존 OUT 판정을 따라요.
                transfers = [{**row, "player_id": 999} for row in case["transfers"]]
                kept, removed = squads._filter_current_squad_items(
                    [{"player_id": 999}], transfers, case["team_id"], SEASON_START, VERIFIED_ON)
                self.assertEqual((kept, removed), ([], {999}))


class CurrentSquadReturnSyncTests(SyncDatabaseCase):
    def test_sync_restores_all_twelve_players_to_squads_and_search_without_deleting_history(self):
        scope, raw_squads, raw_transfers = {}, {}, []
        for case in CASES:
            tid, pid, sid = case["team_id"], case["player_id"], case["season_id"]
            self.sql.execute("INSERT OR IGNORE INTO competitions VALUES(?)", (case["competition_id"],))
            self.sql.execute("INSERT OR IGNORE INTO teams(team_id,name) VALUES(?,?)", (tid, case["team_name"]))
            self.sql.execute("INSERT OR IGNORE INTO seasons VALUES(?,?,'2026/2027',1)", (sid, case["competition_id"]))
            self.sql.execute("INSERT OR IGNORE INTO team_seasons VALUES(?,?)", (tid, sid))
            self.sql.execute("INSERT INTO players(player_id,display_name,full_name) VALUES(?,?,?)",
                             (pid, case["name"], case["name"]))
            scope[tid] = dict(team_id=tid, team_name=case["team_name"], season_id=sid, competition_id=case["competition_id"],
                              season_name="2026/2027", is_current=True)
            raw_squads.setdefault(tid, []).append({**case["squad"], "player": profile(pid)})
            raw_transfers.extend(corrected_transfers(case))
        for row in raw_transfers:
            for tid in (row["from_team_id"], row["to_team_id"]):
                self.sql.execute("INSERT OR IGNORE INTO teams(team_id) VALUES(?)", (tid,))
            self.sql.execute("INSERT OR IGNORE INTO transfer_types(type_id) VALUES(?)", (row["type_id"],))
            self.sql.execute("INSERT INTO transfers VALUES(?,?,?,?,?,NULL,?)",
                             tuple(row[key] for key in ("id", "player_id", "from_team_id", "to_team_id", "type_id", "date")))
        self.sql.commit()
        before = self.sql.execute("SELECT * FROM transfers ORDER BY transfer_id").fetchall()

        self.client.get_team_squad.side_effect = lambda team: self.api(raw_squads[team])
        self.client.get_team_season_squad.side_effect = lambda team, season: self.api(raw_squads[team])
        self.client.iter_transfers_between_dates.side_effect = lambda start, end: self.api(raw_transfers)

        # 검색도 운영 코드의 현재 시즌 JOIN을 실행해 명단 복구 전후를 비교해요.
        search_cursor = self.sql.cursor()
        connection = MagicMock()
        cursor = connection.cursor.return_value.__enter__.return_value
        cursor.execute.side_effect = lambda sql, args: search_cursor.execute(sql.replace("%s", "?"), args)
        cursor.fetchall.side_effect = lambda: [dict(zip([c[0] for c in search_cursor.description], row))
                                               for row in search_cursor.fetchall()]
        with patch.object(squads, "load_squad_scope", return_value=list(scope.values())), \
                patch.object(sync, "date") as clock, \
                patch.object(player_detail_repo, "get_conn", return_value=connection), \
                patch.object(player_detail_repo, "korean_name_ids", return_value=()):
            clock.today.return_value = VERIFIED_ON
            for case in CASES:
                self.assertEqual(player_detail_repo.list_player_comparison_candidates(case["name"]), [])
            result = sync.sync_current_squads(apply=True)
            self.assertEqual(result["stored_squad_members"], 12)
            for case in CASES:
                with self.subTest(player=case["name"]):
                    found = player_detail_repo.list_player_comparison_candidates(case["name"])
                    self.assertEqual([row["player_id"] for row in found], [case["player_id"]])
                    member = self.sql.execute("SELECT jersey_number FROM team_squad_members WHERE team_id=? AND season_id=? AND player_id=?",
                                              (case["team_id"], case["season_id"], case["player_id"])).fetchone()
                    self.assertEqual(member, (case["squad"]["jersey_number"],))
        self.assertEqual(self.sql.execute("SELECT * FROM transfers ORDER BY transfer_id").fetchall(), before)


if __name__ == "__main__":
    unittest.main()
