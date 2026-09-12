import unittest
from pathlib import Path
from unittest.mock import Mock, call, patch

from selenium.common.exceptions import TimeoutException

from one_touch_loader.loaders.player_wage_loader import (
    _build_wage_rows,
    collect_all_wages,
    collect_wages_for_competition_season,
)


class PlayerWageLoaderTest(unittest.TestCase):
    def test_build_wage_rows_uses_canonical_slug_and_eur_wage(self):
        target = {
            "team_id": 10,
            "season_id": 20,
        }
        source_players = [
            {
                "external_player_id": "adama-traore-34855",
                "name": "Adama Traoré",
                "estimated_weekly_gross_eur": 100000,
            },
            {
                "external_player_id": "not-loaded-1",
                "name": "Not Loaded",
                "estimated_weekly_gross_eur": 200000,
            },
            {
                "external_player_id": "noel-aseko-38678",
                "name": "Noel Aseko",
                "estimated_weekly_gross_eur": None,
            },
            {
                "external_player_id": "el-hadji-malick-diouf-38350",
                "name": "El Hadji Malick Diouf",
                "estimated_weekly_gross_eur": None,
            },
        ]

        rows, ignored, unavailable = _build_wage_rows(
            target,
            source_players,
            {
                "adama-traore-34878": 65651,
                "noel-aseko-38678": 37590606,
                "el-hadji-malick-diouf-38349": 37685630,
            },
        )

        self.assertEqual(rows, [(10, 20, 65651, 100000)])
        self.assertEqual(ignored[0]["capology_player_id"], "not-loaded-1")
        self.assertEqual(unavailable[0]["player_id"], 37590606)
        # 링크 ID 보정 후에도 Brentford에서 미제공한 Diouf 급여는 그대로 구분해요.
        self.assertEqual(unavailable[1]["player_id"], 37685630)

    @patch(
        "one_touch_loader.loaders.player_wage_loader._write_wage_report",
        return_value=Path("report.json"),
    )
    @patch("one_touch_loader.loaders.player_wage_loader.transaction")
    @patch("one_touch_loader.loaders.player_wage_loader.fetch_all")
    @patch(
        "one_touch_loader.loaders.player_wage_loader."
        "_parse_capology_salary_page",
        return_value=[],
    )
    @patch(
        "one_touch_loader.loaders.player_wage_loader._capology_salary_url"
    )
    @patch(
        "one_touch_loader.loaders.player_wage_loader."
        "_load_target_team_seasons"
    )
    @patch(
        "one_touch_loader.loaders.player_wage_loader."
        "_CapologyBrowserSession"
    )
    def test_all_uses_each_target_team_seasons_own_source_url(
        self,
        browser_session_class,
        load_targets,
        salary_url,
        parse_salary_page,
        fetch_all,
        transaction,
        _write_report,
    ):
        load_targets.return_value = [
            {
                "team_id": 10,
                "team_name": "Old FC",
                "season_id": 20,
                "season_name": "2018/2019",
                "competition_id": 8,
                "is_current": False,
            },
            {
                "team_id": 11,
                "team_name": "Current FC",
                "season_id": 21,
                "season_name": "2026/2027",
                "competition_id": 82,
                "is_current": True,
            },
        ]
        fetch_all.side_effect = [
            [(10, "old-fc"), (11, "current-fc")],
            [],
        ]
        salary_url.side_effect = ["old-url", "current-url"]
        session = Mock()
        session.fetch.side_effect = [
            ("old-html", "old-response-url"),
            ("current-html", "current-response-url"),
        ]
        browser_session_class.return_value = session
        cursor = (
            transaction.return_value.__enter__.return_value.cursor
            .return_value.__enter__.return_value
        )
        cursor.rowcount = 0

        result = collect_all_wages()

        load_targets.assert_called_once_with(None, None)
        self.assertEqual(
            salary_url.call_args_list,
            [
                call("old-fc", "2018/2019", False),
                call("current-fc", "2026/2027", True),
            ],
        )
        self.assertEqual(
            parse_salary_page.call_args_list,
            [
                call("old-html", "2018/2019"),
                call("current-html", "2026/2027"),
            ],
        )
        self.assertEqual(result["season_name"], "all")
        self.assertEqual(result["target_team_seasons"], 2)

    @patch(
        "one_touch_loader.loaders.player_wage_loader._write_wage_report",
        return_value=Path("report.json"),
    )
    @patch("one_touch_loader.loaders.player_wage_loader.transaction")
    @patch("one_touch_loader.loaders.player_wage_loader.fetch_all")
    @patch(
        "one_touch_loader.loaders.player_wage_loader."
        "_load_target_team_seasons"
    )
    @patch(
        "one_touch_loader.loaders.player_wage_loader."
        "_CapologyBrowserSession"
    )
    def test_source_failure_does_not_start_database_write(
        self,
        browser_session_class,
        load_targets,
        fetch_all,
        transaction,
        _write_report,
    ):
        load_targets.return_value = [
            {
                "team_id": 10,
                "team_name": "Test FC",
                "season_id": 20,
                "season_name": "2026/2027",
                "competition_id": 8,
                "is_current": True,
            }
        ]
        fetch_all.side_effect = [[(10, "test-fc")], []]
        session = Mock()
        session.fetch.side_effect = TimeoutException("page did not become ready")
        browser_session_class.return_value = session

        with self.assertRaisesRegex(RuntimeError, "no wages were written"):
            collect_wages_for_competition_season("2026/2027", 8)

        transaction.assert_not_called()
        session.close.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
