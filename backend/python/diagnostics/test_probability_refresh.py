from __future__ import annotations

import copy
from datetime import date, datetime, timezone
import io
import unittest
from unittest.mock import patch

from diagnostics.test_probability_pipeline import league_input
from one_touch_loader.loaders import probability_loader as loader


class ProbabilityRefreshTests(unittest.TestCase):
    def setUp(self):
        self.args = league_input()
        self.args.pop("as_of")
        self.args.pop("include_what_if")
        self.args["observed_at"] = datetime(2026, 9, 10, 17, tzinfo=timezone.utc)
        self.args["fixtures"][0].update(starting_at="2026-09-09 14:00:00", state_id=5, home_score=1, away_score=0)
        for team in self.args["teams"]:
            team.update(season_id=1, competition_id=82)
        self.previous = loader.prepare_run(**self.args, as_of=date(2026, 9, 10))
        self.args.update(previous=self.previous, stored_days={date(2026, 9, 9), date(2026, 9, 10)})

    def test_unchanged_does_not_simulate_again(self):
        with patch.object(loader, "forecast_day") as simulate:
            runs, result = loader.refresh_league(**self.args)
        self.assertEqual(runs, [])
        self.assertEqual(result["status"], "unchanged")
        simulate.assert_not_called()

    def test_finished_result_and_elo_each_trigger_current_refresh(self):
        for source in ("fixture", "elo"):
            args = copy.deepcopy(self.args)
            if source == "fixture":
                args["fixtures"][1].update(starting_at="2026-09-10 14:00:00", state_id=5, home_score=1, away_score=0)
            else:
                args["histories"][1][-1]["elo"] += 20
            runs, result = loader.refresh_league(**args)
            self.assertEqual(result["status"], "updated")
            self.assertEqual(len(runs), 1)
            self.assertEqual(runs[0]["cutoff"], "observed_state")
            self.assertNotEqual(runs[0]["input_sha256"], self.previous["input_sha256"])

    def test_new_day_adds_daily_baseline_and_keeps_current_what_if(self):
        self.args["observed_at"] = datetime(2026, 9, 11, 1, tzinfo=timezone.utc)
        runs, result = loader.refresh_league(**self.args)
        self.assertEqual(result["daily_snapshots"], 1)
        self.assertEqual([r["cutoff"] for r in runs], ["utc_day_start", "observed_state"])
        self.assertEqual(runs[0]["as_of"], "2026-09-11T00:00:00Z")
        self.assertIsNotNone(runs[-1]["teams"]["1"]["what_if"])

    def test_missing_days_are_filled_without_overwriting_stored_days(self):
        self.args["stored_days"] = {date(2026, 9, 10)}
        runs, _ = loader.refresh_league(**self.args)
        self.assertEqual([r["as_of"][:10] for r in runs], ["2026-09-09", "2026-09-10"])
        self.assertEqual(runs[-1]["cutoff"], "observed_state")

    def test_live_league_preserves_all_published_snapshots(self):
        self.args["fixtures"][1]["state_id"] = 2
        with patch.object(loader, "forecast_day") as simulate:
            runs, result = loader.refresh_league(**self.args)
        self.assertEqual(runs, [])
        self.assertEqual(result, {"season_id": 1, "status": "live", "fixture_ids": [2]})
        simulate.assert_not_called()

    def test_unresolved_result_is_an_error_not_silently_treated_as_live(self):
        self.args["fixtures"][0]["state_id"] = 15
        with self.assertRaisesRegex(ValueError, "unresolved"):
            loader.refresh_league(**self.args)

    def test_new_model_or_sampling_settings_recompute(self):
        for change in ("model", "simulations", "seed"):
            args = copy.deepcopy(self.args)
            if change == "model":
                args["model_report"]["model_id"] = "c" * 64
            else:
                args[change] += 1
            runs, result = loader.refresh_league(**args)
            self.assertEqual(result["status"], "updated")
            self.assertEqual(len(runs), 1)

    def test_refresh_uses_stored_model_and_mapping_and_check_never_writes(self):
        for apply in (False, True):
            with self.subTest(apply=apply):
                self.check_refresh(apply)

    def check_refresh(self, apply):
        mappings = [{"external_team_id": f"Team{t['team_id']}", "team_id": t["team_id"]} for t in self.args["teams"]]
        rows = [(1, "2026-09-10", 3020, 0, "https://clubelo.com/Team1", "d" * 64, datetime(2026, 9, 10))]
        with patch.object(loader, "latest_model", return_value=self.args["model_report"]), \
             patch.object(loader, "read_teams", return_value=self.args["teams"]), \
             patch.object(loader, "read_histories", return_value=self.args["histories"]), \
             patch.object(loader, "read_fixtures", return_value=self.args["fixtures"]), \
             patch.object(loader, "_fetch", side_effect=[mappings, [{"day": d} for d in self.args["stored_days"]]]), \
             patch.object(loader, "latest_run", return_value=self.previous), \
             patch.object(loader, "collect_elo", return_value=rows), \
             patch.object(loader, "save_elo") as save, patch.object(loader, "store_runs") as store, \
             patch.object(loader, "train_and_validate") as train, \
             patch.object(loader, "datetime") as clock, patch("sys.stdout", new=io.StringIO()):
            clock.now.return_value = self.args["observed_at"]
            result = loader.refresh(apply=apply, simulations=100, seed=23)
            self.assertEqual(result["leagues"][0]["status"], "updated")
            train.assert_not_called()
            self.assertEqual(save.call_count, int(apply))
            self.assertEqual(store.call_count, int(apply))
            if apply:
                self.assertEqual(store.call_args.args[0][-1]["teams"]["1"]["elo"], 3020)

    def test_cli_defaults_to_read_only(self):
        with patch.object(loader, "refresh", return_value={}) as refresh, patch("sys.stdout", new=io.StringIO()):
            loader.main(["refresh"])
        self.assertFalse(refresh.call_args.kwargs["apply"])

    def test_live_league_does_not_stop_another_league(self):
        teams = self.args["teams"] + [{"team_id": 90, "season_id": 2, "competition_id": 8}]
        mappings = [{"external_team_id": f"Team{t['team_id']}", "team_id": t["team_id"]} for t in teams]
        current_run = {"season_id": 2}
        with patch.object(loader, "latest_model", return_value=self.args["model_report"]), \
             patch.object(loader, "read_teams", return_value=teams), \
             patch.object(loader, "read_histories", return_value={}), \
             patch.object(loader, "read_fixtures", return_value=[]), \
             patch.object(loader, "_fetch", side_effect=[mappings, [], []]), \
             patch.object(loader, "latest_run", return_value=None), \
             patch.object(loader, "collect_elo", return_value=[]), \
             patch.object(loader, "save_elo"), patch.object(loader, "store_runs") as store, \
             patch.object(loader, "refresh_league", side_effect=[
                 ([], {"season_id": 1, "status": "live"}),
                 ([current_run], {"season_id": 2, "status": "updated"}),
             ]), patch("sys.stdout", new=io.StringIO()):
            result = loader.refresh(apply=True)
        self.assertEqual([r["status"] for r in result["leagues"]], ["live", "updated"])
        store.assert_called_once_with([current_run])


if __name__ == "__main__":
    unittest.main()
