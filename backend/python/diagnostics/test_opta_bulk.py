from __future__ import annotations

import copy
import json
import re
import sqlite3
import unittest
from contextlib import nullcontext
from datetime import date, datetime
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import patch

from one_touch_loader.core.opta_chalkboard import normalize_chalkboard
from one_touch_loader.core.opta_ids import plan_match_ids, player_name_matches, match_roster, supplement_roster
from one_touch_loader.core.opta_schedule import normalize_schedule
from one_touch_loader.loaders.opta_shots_store import bind_shots, replace_match


ROOT = Path(__file__).parent / "fixtures"
CASES = json.loads((ROOT / "opta-bulk-mapping.json").read_text(encoding="utf-8"))


def empty_ids():
    return {kind: {} for kind in ("team", "fixture", "player")}


def plan_for(case, known=None):
    return plan_match_ids(case["raw"], case["match"], case["fixtures"], case["lineups"], known or empty_ids())


class MappingTests(unittest.TestCase):
    def test_real_analysis_mapping_repairs_preserve_identity_and_fixture_scope(self):
        cases = json.loads((ROOT / "opta-analysis-mapping-repair.json").read_text(encoding="utf-8"))
        for case in cases:
            with self.subTest(match=case["raw"]["match_id"]):
                case["lineups"] = supplement_roster(case["lineups"], case["substitutions"])
                self.assertEqual(plan_for(case)["mappings"]["player"], case["expected_players"])
        row = dict(fixture_id=19788654, player_id=12830709, jersey_number=16,
                   display_name="Justin Roth", full_name="Justin Roth")
        other = {**row, "player_id": 37342610, "full_name": "Tom Strannegard", "display_name": "T. Strannegård"}
        player = dict(external_player_id="roth", name="J. Roth", jersey_number=16)
        self.assertEqual(match_roster([player], [row, other]), {"roth": 12830709})
        self.assertEqual(match_roster([player], [row, {**row, "player_id": 999}]), {})
        self.assertEqual(match_roster([{**player, "jersey_number": 17}], [row, other]), {})
        self.assertFalse(player_name_matches("Roth", {**row, "display_name": "Rothwell", "full_name": "Justin Rothwell"}))
        self.assertFalse(player_name_matches("J.", row))
        nayir = dict(fixture_id=19788666, player_id=201712, jersey_number=18,
                     display_name="Umut Nayir", full_name="Mehmet Umut Nayir")
        source = [dict(external_player_id="nayir", name="U. Nayir", jersey_number=14)]
        self.assertEqual(match_roster(source, [nayir]), {"nayir": 201712})
        self.assertEqual(match_roster(source, [{**nayir, "fixture_id": 1}]), {})

    def test_last_three_real_matches_resolve_after_verified_corrections(self):
        from one_touch_loader.core.sportmonks import SportmonksClient
        from one_touch_loader.loaders.fixture_details_loader import normalize_fixture_lineups

        cases = json.loads((ROOT / "opta-final-mapping.json").read_text(encoding="utf-8"))
        sample = json.loads((ROOT / "sportmonks-gent-vergara.json").read_text(encoding="utf-8"))
        event = dict(event_id=157460319, event_type_id=18, fixture_id=19766394, team_id=8119,
                     player_id=226852, display_name="Anderson Silva", full_name="Anderson Oliveira Silva")
        for case in cases[1:]:
            with self.assertRaisesRegex(ValueError, "슈팅 선수를"):
                bind_shots(normalize_chalkboard(case["raw"]), plan_for(case))
        cases[1]["lineups"] = supplement_roster(cases[1]["lineups"], [event])
        client = SportmonksClient.__new__(SportmonksClient)
        with patch.object(client, "_get", return_value={"data": sample["profile"]}):
            corrected = client.correct_fixture_details(sample["fixture"])
        row = normalize_fixture_lineups(corrected, 19788586)["lineups"][0]
        cases[2]["lineups"] = [p for p in cases[2]["lineups"] if p["player_id"] != 37737079]
        cases[2]["lineups"].append(dict(fixture_id=row[0], team_id=row[1], player_id=row[2],
            jersey_number=row[5], display_name=sample["profile"]["display_name"], full_name=sample["profile"]["name"]))
        for case, expected in zip(cases, [9, 15, 11]):
            with self.subTest(fixture=case["fixtures"][0]["fixture_id"]):
                self.assertEqual(len(bind_shots(normalize_chalkboard(case["raw"]), plan_for(case))), expected)
        self.assertEqual(plan_for(cases[0])["mappings"]["player"]["505oa888m5vi62ez2tsmod6ju"], 9939098)
        self.assertEqual(plan_for(cases[1])["mappings"]["player"]["evwzikhqpwulci3y20ckeoc15"], 226852)
        self.assertEqual(plan_for(cases[2])["mappings"]["player"]["wfnh772q3r95omx4rbkret5g"], 37765373)

    def test_missing_roster_requires_verified_substitution_and_preserves_lineups(self):
        event = dict(event_id=157460319, event_type_id=18, fixture_id=19766394, team_id=8119,
                     player_id=226852, display_name="Anderson Silva", full_name="Anderson Oliveira Silva")
        rows = supplement_roster([], [event, event])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["jersey_number"], 33)
        for field in ("event_id", "event_type_id", "fixture_id", "team_id", "player_id"):
            with self.subTest(field=field):
                self.assertEqual(supplement_roster([], [{**event, field: 999}]), [])
        existing = [{**rows[0], "jersey_number": 99}]
        self.assertEqual(supplement_roster(existing, [event]), existing)
        self.assertEqual(match_roster([dict(external_player_id="anderson", name="Anderson Silva", jersey_number=18)], rows), {})
        self.assertEqual(match_roster([dict(external_player_id="wrong", name="Lelê", jersey_number=33)], rows), {})
        self.assertFalse(player_name_matches("J. Vergara", dict(player_id=37737079,
            display_name="José Mendieta", full_name="José Mendieta")))

    def test_actual_extra_time_shots_are_kept_with_full_match_counts(self):
        raw = json.loads((ROOT / "opta-extra-time-chalkboard.json").read_text(encoding="utf-8"))
        self.assertTrue(raw["finished"])
        result = normalize_chalkboard(raw)
        self.assertEqual(result["counts"], {"home": 6, "away": 3})
        self.assertEqual([(s["minute"], s["result"]) for s in result["shots"] if s["minute"] > 90],
                         [(111, "on_target"), (112, "goal")])

    def test_observed_name_order_initials_and_nicknames(self):
        cases = [
            (29735915, "Oh Hyeon-Gyu", "Hyeon-gyu Oh", "Hyun-Gyu Oh"),
            (31626482, "Cho Gue-Sung", "Gue-sung Cho", "Kyu-Sung Cho"),
            (38200259, "H. Djibirin", "Djibirin Harouna", "Djibirin Harouna"),
            (37397253, "M. El Moubarik", "Mehdi Moubarik", "El Mehdi Moubarik"),
            (37551656, "Kialonda Gaspar", "Gaspar", "K. Gaspar"),
            (531967, "Þ. Helgason", "Thórir Jóhann Helgason", "Thórir Jóhann Helgason"),
            (177794, "Đ. Crnomarković", "Djordje Crnomarkovic", "Đorđe Crnomarković"),
            (3188026, "T. Douvikas", "Anastasios Douvikas", "Anastasios Douvikas"),
            (37544761, "Cala", "Álex Calatrava", "Alex Calatrava Torrado"),
            (159402, "Rafa", "Rafa Silva", "Rafael Alexandre Fernandes Ferreira da Silva"),
        ]
        for pid, source, display, full in cases:
            row = dict(fixture_id=0, player_id=pid, display_name=display, full_name=full, jersey_number=9)
            with self.subTest(source=source):
                self.assertTrue(player_name_matches(source, row))
                self.assertEqual(match_roster([dict(name=source, jersey_number=8, external_player_id="test")], [row]), {})
        self.assertFalse(player_name_matches("Cho Gue-Sung", dict(player_id=1, display_name="Cho Gue-Jun", full_name="Cho Gue-Jun")))
        self.assertFalse(player_name_matches("J. Smith", dict(player_id=1, display_name="John Jones", full_name="John Jones")))
        self.assertFalse(player_name_matches("Cala", dict(player_id=1, display_name="Álex Calatrava", full_name="Alex Calatrava Torrado")))
        row=dict(fixture_id=19788662,player_id=177988,jersey_number=24,display_name="Dušan Vlahović",full_name="Dušan Vlahović")
        source=[dict(name="D. Vlahović",jersey_number=28,external_player_id="vlahovic")]
        self.assertEqual(match_roster(source,[row]),{"vlahovic":177988})
        self.assertEqual(match_roster(source,[{**row,"fixture_id":1}]),{})

    def test_full_public_season_schedule_has_380_unique_match_links(self):
        page = json.loads((ROOT / "opta-laliga-schedule.json").read_text(encoding="utf-8"))
        schedule = normalize_schedule(page["attributes"], page["schedule"], 564)
        self.assertEqual(schedule["season_name"], "2026/2027")
        self.assertEqual(len(schedule["matches"]), 380)
        self.assertEqual(len({m["external_fixture_id"] for m in schedule["matches"]}), 380)
        match = next(m for m in schedule["matches"] if m["external_fixture_id"] == CASES[1]["raw"]["match_id"])
        self.assertIn("matchId=" + match["external_fixture_id"], match["url"])

    def test_wrong_competition_and_season_are_not_relabelled(self):
        page = json.loads((ROOT / "opta-laliga-schedule.json").read_text(encoding="utf-8"))
        with self.assertRaises(ValueError):
            normalize_schedule(page["attributes"], page["schedule"], 8)
        page["attributes"]["tmcl"] = "wrong"
        with self.assertRaises(ValueError):
            normalize_schedule(page["attributes"], page["schedule"], 564)

    def test_real_spanish_and_german_rosters_map_all_shooters(self):
        expected = [19732712, 19732704, 19735188]
        known = empty_ids()
        for case, fixture_id in zip(CASES[:3], expected):
            plan = plan_for(case, known)
            result = normalize_chalkboard(case["raw"])
            rows = bind_shots(result, plan)
            self.assertEqual(plan["fixture"]["fixture_id"], fixture_id)
            self.assertEqual(len(rows), sum(result["counts"].values()))
            self.assertTrue(all(row[1] == fixture_id for row in rows))
            for kind, mapping in plan["mappings"].items():
                known[kind].update(mapping)
        self.assertEqual(plan_for(CASES[1])["mappings"]["player"]["4rktv6j9sioe0gmu7jt77fsh5"], 26491)

    def test_same_date_wrong_sides_or_ambiguous_fixtures_cannot_map(self):
        for change in ("sides", "duplicate", "date"):
            case = copy.deepcopy(CASES[2])
            if change == "sides":
                f = case["fixtures"][0]
                f["home_team_id"], f["away_team_id"] = f["away_team_id"], f["home_team_id"]
            elif change == "duplicate":
                f = {**case["fixtures"][0], "fixture_id": 123}
                case["fixtures"].append(f)
                case["lineups"] += [{**p, "fixture_id": 123} for p in case["lineups"]]
            else:
                case["match"]["date"] = "2026-09-05"
            with self.subTest(change=change), self.assertRaises(ValueError):
                plan_for(case)

    def test_real_ligue1_omitted_middle_names_still_require_the_same_number(self):
        case = copy.deepcopy(CASES[4])
        plan = plan_for(case)
        self.assertEqual(plan["mappings"]["player"]["6vjoq2kgaq2igxoh8cvq0ieax"], 466425)
        self.assertTrue(bind_shots(normalize_chalkboard(case["raw"]), plan))
        for team in case["raw"]["teams"].values():
            for p in team["players"]:
                if p["external_player_id"] == "6vjoq2kgaq2igxoh8cvq0ieax":
                    p["jersey_number"] = 999
        with self.assertRaisesRegex(ValueError, "슈팅 선수를"):
            bind_shots(normalize_chalkboard(case["raw"]), plan_for(case))

    def test_existing_id_conflict_and_unknown_shooter_are_rejected(self):
        case = copy.deepcopy(CASES[1])
        known = empty_ids()
        known["fixture"][case["raw"]["match_id"]] = 123
        with self.assertRaisesRegex(ValueError, "기존 fixture"):
            plan_for(case, known)
        case["lineups"] = [p for p in case["lineups"] if p["player_id"] != 26491]
        plan = plan_for(case)
        with self.assertRaisesRegex(ValueError, "슈팅 선수를"):
            bind_shots(normalize_chalkboard(case["raw"]), plan)

    def test_actual_champions_league_goal_on_target_overlap_is_one_goal(self):
        result = normalize_chalkboard(CASES[3]["raw"])
        self.assertEqual(result["counts"], {"home": 4, "away": 3})
        self.assertEqual(len(result["shots"]), 7)
        self.assertEqual(sum(s["result"] == "goal" for s in result["shots"]), 1)
        with self.assertRaisesRegex(ValueError, "DB 출전 명단"):
            plan_for(CASES[3])

    def test_zero_on_target_differs_from_incomplete_capture(self):
        raw = copy.deepcopy(CASES[1]["raw"])
        raw["events"] = []
        with self.assertRaisesRegex(ValueError, "유효슈팅 수"):
            normalize_chalkboard(raw)
        raw["summary"]["Shots on target"] = {"home": 0, "away": 0}
        self.assertEqual(normalize_chalkboard(raw)["shots"], [])


class SqliteCursor:
    """실제 저장 SQL의 자리표시자·UPSERT 문법만 로컬 테스트 DB에 맞춰요."""
    def __init__(self, conn):
        self.cursor = conn.cursor()

    def sql(self, value):
        value = value.replace("%s", "?").replace(" FOR UPDATE", "")
        value = value.replace("ON DUPLICATE KEY UPDATE", "ON CONFLICT(fixture_id) DO UPDATE SET")
        return re.sub(r"VALUES\((\w+)\)", r"excluded.\1", value)

    def execute(self, sql, params=()):
        self.cursor.execute(self.sql(sql), params)

    def executemany(self, sql, rows):
        self.cursor.executemany(self.sql(sql), rows)

    def fetchone(self):
        return self.cursor.fetchone()


class StorageTests(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("PRAGMA foreign_keys=ON")
        self.conn.executescript("""
            CREATE TABLE fixtures(fixture_id INTEGER PRIMARY KEY,home_team_id INTEGER,away_team_id INTEGER);
            CREATE TABLE teams(team_id INTEGER PRIMARY KEY);
            CREATE TABLE players(player_id INTEGER PRIMARY KEY,display_name TEXT);
            CREATE TABLE fixture_opta_shotmaps(fixture_id INTEGER PRIMARY KEY REFERENCES fixtures,
              collected_at TEXT);
            CREATE TABLE fixture_opta_sources(fixture_id INTEGER PRIMARY KEY REFERENCES fixtures,source_url TEXT);
            CREATE TABLE fixture_opta_shots(external_event_id TEXT PRIMARY KEY,
              fixture_id INTEGER REFERENCES fixture_opta_shotmaps,team_id INTEGER REFERENCES teams,
              player_id INTEGER REFERENCES players,minute INTEGER,extra_minute INTEGER,result TEXT,
              start_x REAL,start_y REAL,end_x REAL,end_y REAL);
        """)
        for kind in ("fixture", "team", "player"):
            self.conn.execute(f"CREATE TABLE {kind}_external_ids({kind}_id INTEGER,provider TEXT,external_{kind}_id TEXT,"
                              f"PRIMARY KEY(provider,external_{kind}_id),UNIQUE(provider,{kind}_id))")
        self.case = CASES[1]
        self.plan = plan_for(self.case)
        self.result = normalize_chalkboard(self.case["raw"])
        self.fixture_id = self.plan["fixture"]["fixture_id"]
        self.conn.execute("INSERT INTO fixtures VALUES (?,?,?)", (self.fixture_id,self.plan['fixture']['home_team_id'],self.plan['fixture']['away_team_id']))
        for kind in ("team", "player"):
            for internal in set(self.plan["mappings"][kind].values()):
                sql = "INSERT INTO teams VALUES (?)" if kind == "team" else "INSERT INTO players(player_id) VALUES (?)"
                self.conn.execute(sql, (internal,))
        self.conn.commit()
        self.known = empty_ids()

    def tearDown(self):
        self.conn.close()

    def save(self, result=None, sampled="2026-09-13T14:40:00+00:00"):
        with self.conn:
            replace_match(SqliteCursor(self.conn), result or self.result, self.plan, self.known, sampled)
        self.known = self.plan["mappings"]

    def test_idempotent_refresh_and_empty_match_replace(self):
        self.save()
        self.save()
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM fixture_opta_shots").fetchone()[0], 12)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM fixture_external_ids").fetchone()[0], 1)
        result = {**self.result, "shots": [], "counts": {"home": 0, "away": 0}}
        self.save(result)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM fixture_opta_shots").fetchone()[0], 0)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM fixture_opta_shotmaps").fetchone()[0], 1)

    def test_failed_replacement_rolls_back_summary_and_existing_shots(self):
        self.save()
        before = self.conn.execute("SELECT * FROM fixture_opta_shots ORDER BY external_event_id").fetchall()
        self.conn.execute("""CREATE TRIGGER simulated_write_failure BEFORE INSERT ON fixture_opta_shots
            BEGIN SELECT RAISE(FAIL,'simulated storage failure'); END""")
        with self.assertRaises(sqlite3.IntegrityError):
            self.save(sampled="2026-09-13T15:00:00+00:00")
        self.assertEqual(self.conn.execute("SELECT * FROM fixture_opta_shots ORDER BY external_event_id").fetchall(), before)
        self.assertEqual(self.conn.execute("SELECT collected_at FROM fixture_opta_shotmaps").fetchone()[0], "2026-09-13 14:40:00")

    def test_api_reads_same_snapshot_and_preserves_zero_vs_uncollected(self):
        from one_touch_loader.api.repos import opta_shots_repo as repo

        def query(sql, params):
            cursor = self.conn.execute(sql.replace("%s", "?"), params)
            rows = [dict(zip([d[0] for d in cursor.description], row)) for row in cursor.fetchall()]
            for row in rows:
                row["collected_at"] = datetime.fromisoformat(row["collected_at"])
            return rows

        with patch.object(repo, "fetch_all_dict", side_effect=query):
            self.assertFalse(repo.get_shotmap(self.fixture_id)["available"])
            self.save()
            result = repo.get_shotmap(self.fixture_id)
            self.assertTrue(result["available"])
            self.assertEqual(result["counts"], {"home": 2, "away": 10})
            self.assertEqual(len(result["shots"]), 12)
            self.assertIn("+00:00", result["collected_at"])
            self.assertIn("end", result["shots"][0])
            self.assertNotIn("xg", result["shots"][0])
            self.save({**self.result, "shots": [], "counts": {"home": 0, "away": 0}})
            result = repo.get_shotmap(self.fixture_id)
            self.assertTrue(result["available"])
            self.assertEqual(result["shots"], [])


class BatchTests(unittest.TestCase):
    def test_retry_status_filter_leaves_confirmed_unavailable_matches_alone(self):
        from one_touch_loader.core import db
        from one_touch_loader.loaders import opta_shots_loader as loader
        first, second = CASES[:2]
        with TemporaryDirectory() as folder:
            root = Path(folder)
            report_path = root / "old.json"
            report_path.write_text(json.dumps({"matches": [
                {"external_fixture_id": first["raw"]["match_id"], "status": "unavailable"},
                {"external_fixture_id": second["raw"]["match_id"], "status": "failed"}]}), encoding="utf-8")
            (root / (second["raw"]["match_id"] + ".raw.json")).write_text(json.dumps(second["raw"]), encoding="utf-8")
            args = SimpleNamespace(apply=False, output_dir=root / "retry", competition_ids=[564],
                season="2026/2027", from_date=None, to_date=date(2026, 9, 6), refresh=False, limit=None,
                retry_report=report_path, retry_statuses=["failed", "not_finished"])
            with patch.object(db, "fetch_all", return_value=[(0,)]), \
                 patch.object(loader, "load_known_ids", return_value=empty_ids()), \
                 patch.object(loader, "fetch_schedule", return_value={"season_name": "2026/2027", "matches": [first["match"], second["match"]]}), \
                 patch.object(loader, "load_scope", return_value=(second["fixtures"], second["lineups"])), \
                 patch.object(loader, "open_browser", return_value=nullcontext(object())), \
                 patch.object(loader, "collect_snapshot") as collect, patch.object(loader, "save_match") as save:
                report = loader.sync_matches(args)
            self.assertEqual((report["ready"], report["unavailable"], report["failed"]), (1, 0, 0))
            self.assertEqual([m["external_fixture_id"] for m in report["matches"]], [second["raw"]["match_id"]])
            collect.assert_not_called()
            save.assert_not_called()

    def test_retry_uses_failed_cached_match_only_and_unavailable_is_not_zero(self):
        from one_touch_loader.core import db
        from one_touch_loader.loaders import opta_shots_loader as loader
        with TemporaryDirectory() as folder:
            root = Path(folder)
            first, second = CASES[:2]
            eid = second["raw"]["match_id"]
            (root / "old.json").write_text(json.dumps({"matches": [
                {"external_fixture_id": first["raw"]["match_id"], "status": "stored"},
                {"external_fixture_id": eid, "status": "failed"}]}), encoding="utf-8")
            (root / f"{eid}.raw.json").write_text(json.dumps(second["raw"]), encoding="utf-8")
            args = SimpleNamespace(apply=False, output_dir=root / "retry", competition_ids=[564],
                season="2026/2027", from_date=None, to_date=date(2026,9,6), refresh=False, limit=None,
                retry_report=root / "old.json")
            with patch.object(db,"fetch_all",return_value=[(0,)]), \
                 patch.object(loader,"load_known_ids",return_value=empty_ids()), \
                 patch.object(loader,"fetch_schedule",return_value={"season_name":"2026/2027","matches":[c["match"] for c in CASES[:2]]}), \
                 patch.object(loader,"load_scope",return_value=(second["fixtures"],second["lineups"])), \
                 patch.object(loader,"open_browser",return_value=nullcontext(object())), \
                 patch.object(loader,"collect_snapshot") as collect, patch.object(loader,"save_match") as save:
                report=loader.sync_matches(args)
                self.assertEqual((report["ready"],len(report["matches"])),(1,1))
                collect.assert_not_called()
                (root / f"{eid}.raw.json").unlink()
                collect.return_value={"finished":True,"available":False,"evidence":{"commentary_message":"There is no data available for this fixture."}}
                report=loader.sync_matches(args)
                self.assertEqual((report["unavailable"],report["ready"],report["failed"]),(1,0,0))
                save.assert_not_called()

    def test_check_continues_after_one_failure_and_never_writes_db(self):
        from one_touch_loader.core import db
        from one_touch_loader.loaders import opta_shots_loader as loader

        with TemporaryDirectory() as folder:
            args = SimpleNamespace(apply=False, output_dir=Path(folder), competition_ids=[564],
                                   season="2026/2027", from_date=None, to_date=date(2026, 9, 6),
                                   refresh=False, limit=None)
            scope = {"season_name": "2026/2027", "matches": [c["match"] for c in CASES[:2]]}
            with patch.object(db, "fetch_all", return_value=[(0,)]), \
                 patch.object(loader, "load_known_ids", return_value=empty_ids()), \
                 patch.object(loader, "fetch_schedule", return_value=scope), \
                 patch.object(loader, "load_scope", return_value=(CASES[1]["fixtures"], CASES[1]["lineups"])), \
                 patch.object(loader, "open_browser", return_value=nullcontext(object())), \
                 patch.object(loader, "collect_snapshot", side_effect=[ValueError("incomplete provider data"), CASES[1]["raw"]]), \
                 patch.object(loader, "save_match") as save:
                report = loader.sync_matches(args)
            save.assert_not_called()
            self.assertEqual((report["ready"], report["failed"], report["stored"]), (1, 1, 0))
            self.assertTrue((Path(folder) / "report.json").is_file())

    def test_saved_matches_are_skipped_and_unfinished_match_is_not_loaded(self):
        from one_touch_loader.core import db
        from one_touch_loader.loaders import opta_shots_loader as loader

        with TemporaryDirectory() as folder:
            args = SimpleNamespace(apply=True, output_dir=Path(folder), competition_ids=[564],
                                   season="2026/2027", from_date=None, to_date=date(2026, 9, 6),
                                   refresh=False, limit=None)
            scope = {"season_name": "2026/2027", "matches": [c["match"] for c in CASES[:2]]}
            with patch.object(db, "fetch_all", side_effect=[[(1,)], [(CASES[0]["raw"]["match_id"], CASES[0]["fixtures"][0]["fixture_id"])]]), \
                 patch.object(loader, "load_known_ids", return_value=empty_ids()), \
                 patch.object(loader, "fetch_schedule", return_value=scope), \
                 patch.object(loader, "load_scope", return_value=(CASES[1]["fixtures"], CASES[1]["lineups"])), \
                 patch.object(loader, "open_browser", return_value=nullcontext(object())), \
                 patch.object(loader, "collect_snapshot", return_value={"finished": False}) as collect, \
                 patch.object(loader, "save_match") as save:
                report = loader.sync_matches(args)
            save.assert_not_called()
            self.assertEqual(collect.call_count, 1)
            self.assertEqual((report["skipped"], report["not_finished"], report["failed"]), (1, 1, 0))

    def test_shotmap_route_requires_member_and_checks_fixture(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        from one_touch_loader.api.deps import get_user_id
        from one_touch_loader.api.routes import fixtures

        app = FastAPI()
        app.include_router(fixtures.router, prefix="/v1")
        with TestClient(app) as client:
            self.assertIn(client.get("/v1/fixtures/19732704/shotmap").status_code, (401, 403))
            app.dependency_overrides[get_user_id] = lambda: 1
            with patch.object(fixtures, "get_fixture", return_value={"fixture_id": 19732704}), \
                 patch.object(fixtures, "get_shotmap", return_value={"provider": "opta", "available": False}):
                response = client.get("/v1/fixtures/19732704/shotmap")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()["provider"], "opta")
            with patch.object(fixtures, "get_fixture", return_value=None):
                self.assertEqual(client.get("/v1/fixtures/123/shotmap").status_code, 404)


if __name__ == "__main__":
    unittest.main()
