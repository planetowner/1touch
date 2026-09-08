import unittest
from datetime import date
from pathlib import Path
from unittest.mock import Mock, patch

from selenium.common.exceptions import TimeoutException

from one_touch_loader.loaders.capology_common import (
    _capology_salary_page_is_ready,
    _capology_salary_url,
    _normalize_identity_text,
    _parse_capology_salary_page,
)
from one_touch_loader.loaders.capology_player_ids_loader import (
    _build_source_complete_matches,
    _collect_source_groups_from_saved_team_slugs,
    _collect_capology_player_ids,
)


class CapologyPlayerIdsLoaderTest(unittest.TestCase):
    def test_salary_page_waits_through_missing_title_and_captcha(self):
        driver = Mock(title=None, page_source="var data = [")
        self.assertFalse(_capology_salary_page_is_ready(driver))
        driver.execute_script.assert_not_called()
        driver.title = "Just a moment..."
        self.assertFalse(_capology_salary_page_is_ready(driver))
        driver.execute_script.assert_not_called()
        driver.title = "2026-2027 Real Sociedad Salaries and Contracts"
        driver.execute_script.return_value = "loading"
        self.assertFalse(_capology_salary_page_is_ready(driver))
        driver.execute_script.return_value = "complete"
        driver.page_source = "<html></html>"
        self.assertFalse(_capology_salary_page_is_ready(driver))
        driver.page_source = "var data = ["
        self.assertTrue(_capology_salary_page_is_ready(driver))

    def test_source_complete_match_accepts_verified_balde_alias(self):
        observation = {
            "competition_id": 564,
            "season_name": "2024/2025",
            "team_id": 83,
            "player_id": 37316480,
            "display_name": "Alejandro Balde",
            "full_name": "Alejandro Balde Martínez",
            "date_of_birth": date(2003, 10, 18),
            "country": "Spain",
            "position_group_id": 25,
        }
        source_player = {
            "external_player_id": "alex-balde-37912",
            "name": "Álex Balde",
            "normalized_name": _normalize_identity_text("Álex Balde"),
            "age": 21,
            "country": "Dominican Republic",
            "position_group_id": 26,
            "source_url": "https://example.com/barcelona",
        }

        matches, unresolved = _build_source_complete_matches(
            [observation],
            [observation],
            {(564, "2024/2025"): {"barcelona": [source_player]}},
            {},
            {},
            {83: "barcelona"},
        )

        self.assertEqual(unresolved, [])
        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0]["player_id"], 37316480)
        self.assertEqual(
            matches[0]["method"],
            "same_team_verified_name_alias_age",
        )

    def test_source_complete_match_finds_global_exact_name_age_candidate(self):
        profile = {
            "player_id": 101,
            "display_name": "Global Player",
            "full_name": "Global Player",
            "date_of_birth": date(2000, 1, 1),
            "team_ids": {10},
        }
        source_player = {
            "external_player_id": "global-player-101",
            "name": "Global Player",
            "normalized_name": "global player",
            "age": 24,
            "country": None,
            "position_group_id": None,
            "source_url": "https://example.com/test-fc",
        }

        matches, unresolved = _build_source_complete_matches(
            [],
            [profile],
            {(8, "2024/2025"): {"test-fc": [source_player]}},
            {},
            {},
            {10: "test-fc"},
        )

        self.assertEqual(unresolved, [])
        self.assertEqual(matches[0]["player_id"], 101)
        self.assertEqual(matches[0]["method"], "known_team_exact_name_age")

    def test_source_complete_match_accepts_same_team_name_phrase(self):
        observation = {
            "competition_id": 564,
            "season_name": "2018/2019",
            "team_id": 83,
            "player_id": 3779,
            "display_name": "Gerard Piqué Bernabéu",
            "full_name": "Gerard Piqué Bernabéu",
            "date_of_birth": date(1987, 2, 2),
            "country": "Spain",
            "position_group_id": 25,
        }
        source_player = {
            "external_player_id": "gerard-pique-31810",
            "name": "Gerard Piqué",
            "normalized_name": "gerard pique",
            "age": 31,
            "country": "Spain",
            "position_group_id": 25,
            "source_url": "https://example.com/barcelona",
        }

        matches, unresolved = _build_source_complete_matches(
            [observation],
            [observation],
            {(564, "2018/2019"): {"barcelona": [source_player]}},
            {},
            {},
            {83: "barcelona"},
        )

        self.assertEqual(unresolved, [])
        self.assertEqual(matches[0]["player_id"], 3779)
        self.assertEqual(
            matches[0]["method"],
            "same_team_name_phrase_complete_identity",
        )

    def test_source_complete_match_accepts_same_team_name_token_subset(self):
        observation = {
            "competition_id": 301,
            "season_name": "2018/2019",
            "team_id": 450,
            "player_id": 1382,
            "display_name": "M. Balotelli",
            "full_name": "Mario Barwuah Balotelli",
            "date_of_birth": date(1990, 8, 12),
            "country": "Italy",
            "position_group_id": 27,
        }
        source_player = {
            "external_player_id": "mario-balotelli-33097",
            "name": "Mario Balotelli",
            "normalized_name": "mario balotelli",
            "age": 28,
            "country": "Italy",
            "position_group_id": 27,
            "source_url": "https://example.com/nice",
        }

        matches, unresolved = _build_source_complete_matches(
            [observation],
            [observation],
            {(301, "2018/2019"): {"nice": [source_player]}},
            {},
            {},
            {450: "nice"},
        )

        self.assertEqual(unresolved, [])
        self.assertEqual(matches[0]["player_id"], 1382)
        self.assertEqual(
            matches[0]["method"],
            "same_team_name_token_subset_complete_identity",
        )

    def test_global_name_age_candidate_requires_verified_team_history(self):
        profile = {
            "player_id": 101,
            "display_name": "Rafael",
            "full_name": "Rafael",
            "date_of_birth": date(1990, 5, 20),
            "team_ids": {20},
        }
        source_player = {
            "external_player_id": "rafael-33013",
            "name": "Rafael",
            "normalized_name": "rafael",
            "age": 28,
            "country": "Brazil",
            "position_group_id": 24,
            "source_url": "https://example.com/sampdoria",
        }

        matches, unresolved = _build_source_complete_matches(
            [],
            [profile],
            {(384, "2018/2019"): {"sampdoria": [source_player]}},
            {},
            {},
            {10: "sampdoria", 20: "different-team"},
        )

        self.assertEqual(matches, [])
        self.assertEqual(unresolved[0]["reason"], "no_name_age_candidate")

    def test_source_complete_match_keeps_source_player_without_db_match(self):
        source_player = {
            "external_player_id": "unknown-player-404",
            "name": "Unknown Player",
            "normalized_name": "unknown player",
            "age": 24,
            "country": "England",
            "position_group_id": 26,
            "source_url": "https://example.com/test-fc",
        }

        matches, unresolved = _build_source_complete_matches(
            [],
            [],
            {(8, "2024/2025"): {"test-fc": [source_player]}},
            {},
            {},
            {},
        )

        self.assertEqual(matches, [])
        self.assertEqual(len(unresolved), 1)
        self.assertEqual(unresolved[0]["reason"], "no_name_age_candidate")

    def test_source_complete_match_accepts_verified_player_id_override(self):
        profile = {
            "player_id": 186591,
            "display_name": "Yassine Bounou",
            "full_name": "Yassine Bounou",
            "date_of_birth": date(1991, 4, 5),
            "team_ids": {231},
        }
        source_player = {
            "external_player_id": "bono-33333",
            "name": "Bono",
            "normalized_name": "bono",
            "age": 28,
            "country": "Morocco",
            "position_group_id": 24,
            "source_url": "https://example.com/sevilla",
        }

        matches, unresolved = _build_source_complete_matches(
            [],
            [profile],
            {(564, "2019/2020"): {"sevilla": [source_player]}},
            {},
            {},
            {231: "sevilla"},
        )

        self.assertEqual(unresolved, [])
        self.assertEqual(matches[0]["player_id"], 186591)
        self.assertEqual(matches[0]["method"], "verified_player_id_override")

    def test_verified_player_id_override_is_ignored_when_player_is_not_loaded(
        self,
    ):
        source_player = {
            "external_player_id": "bono-33333",
            "name": "Bono",
            "normalized_name": "bono",
            "age": 28,
            "country": "Morocco",
            "position_group_id": 24,
            "source_url": "https://example.com/sevilla",
        }

        matches, unresolved = _build_source_complete_matches(
            [],
            [],
            {(564, "2019/2020"): {"sevilla": [source_player]}},
            {},
            {},
            {231: "sevilla"},
        )

        self.assertEqual(matches, [])
        self.assertEqual(unresolved[0]["reason"], "verified_player_not_loaded")

    def test_verified_source_slug_alias_uses_existing_canonical_slug(self):
        cases = (
            (
                37685630,
                "el-hadji-malick-diouf-38350",
                "el-hadji-malick-diouf-38349",
                "El Hadji Malick Diouf",
            ),
            (
                65651,
                "adama-traore-34855",
                "adama-traore-34878",
                "Adama Traoré",
            ),
            (
                37590606,
                "noel-aseko-nkili-38678",
                "noel-aseko-38678",
                "Noël Aséko Nkili",
            ),
        )
        for player_id, source_slug, canonical_slug, player_name in cases:
            with self.subTest(source_slug=source_slug):
                source_player = {
                    "external_player_id": source_slug,
                    "name": player_name,
                    "normalized_name": _normalize_identity_text(player_name),
                    "age": 25,
                    "country": None,
                    "position_group_id": None,
                    "source_url": "https://example.com/team",
                }
                canonical_source_player = {
                    **source_player,
                    "external_player_id": canonical_slug,
                }

                matches, unresolved = _build_source_complete_matches(
                    [],
                    [],
                    {
                        (301, "2020/2021"): {"team": [source_player]},
                        (301, "2021/2022"): {
                            "team": [canonical_source_player]
                        },
                    },
                    {player_id: canonical_slug},
                    {canonical_slug: player_id},
                    {},
                )

                self.assertEqual(unresolved, [])
                self.assertEqual(matches[0]["method"], "existing_mapping")
                self.assertEqual(
                    matches[0]["capology_player_id"],
                    canonical_slug,
                )
                self.assertEqual(
                    {
                        appearance["source_player"]["external_player_id"]
                        for appearance in matches[0]["appearances"]
                    },
                    {source_slug, canonical_slug},
                )

    def test_verified_source_slug_alias_inserts_canonical_slug(self):
        cases = (
            (
                65651,
                "adama-traore-34855",
                "adama-traore-34878",
                "Adama Traoré",
            ),
            (
                37590606,
                "noel-aseko-nkili-38678",
                "noel-aseko-38678",
                "Noël Aséko Nkili",
            ),
        )
        for player_id, source_slug, canonical_slug, player_name in cases:
            with self.subTest(source_slug=source_slug):
                profile = {
                    "player_id": player_id,
                    "display_name": player_name,
                    "full_name": player_name,
                    "date_of_birth": date(2000, 1, 1),
                    "team_ids": set(),
                }
                source_player = {
                    "external_player_id": source_slug,
                    "name": player_name,
                    "normalized_name": _normalize_identity_text(player_name),
                    "age": 25,
                    "country": None,
                    "position_group_id": None,
                    "source_url": "https://example.com/team",
                }

                matches, unresolved = _build_source_complete_matches(
                    [],
                    [profile],
                    {(301, "2020/2021"): {"team": [source_player]}},
                    {},
                    {},
                    {},
                )

                self.assertEqual(unresolved, [])
                self.assertEqual(
                    matches[0]["method"],
                    "verified_player_id_override",
                )
                self.assertEqual(
                    matches[0]["capology_player_id"],
                    canonical_slug,
                )

    @patch(
        "one_touch_loader.loaders.capology_player_ids_loader."
        "_parse_capology_salary_page",
        return_value=[
            {
                "external_player_id": "player-1001",
                "name": "Player One",
                "normalized_name": "player one",
            }
        ],
    )
    def test_source_collection_records_timeout_and_continues(
        self,
        _parse_salary_page,
    ):
        observations = [
            {
                "competition_id": 8,
                "season_name": "2024/2025",
                "is_current": False,
                "team_id": 10,
                "team_name": "Team A",
            },
            {
                "competition_id": 8,
                "season_name": "2024/2025",
                "is_current": False,
                "team_id": 20,
                "team_name": "Team B",
            },
        ]
        session = Mock()
        session.fetch.side_effect = [
            TimeoutException("page did not become ready"),
            ("<html></html>", "https://example.com/team-b"),
        ]

        source_groups, failures, fetched_pages = (
            _collect_source_groups_from_saved_team_slugs(
                observations,
                {10: "team-a", 20: "team-b"},
                session,
            )
        )

        self.assertEqual(fetched_pages, 1)
        self.assertEqual(len(failures), 1)
        self.assertEqual(failures[0]["error_type"], "TimeoutException")
        self.assertEqual(
            list(source_groups[(8, "2024/2025")]),
            ["team-b"],
        )

    def test_all_mapped_scope_still_collects_full_capology_source(self):
        observation = {
            "competition_id": 8,
            "season_name": "2024/2025",
            "team_id": 10,
            "player_id": 1,
            "display_name": "Mapped Player",
            "full_name": "Mapped Player",
            "date_of_birth": date(2000, 1, 1),
        }
        target = {
            "competition_id": 8,
            "season_name": "2024/2025",
            "is_current": False,
            "team_id": 10,
            "team_name": "Team A",
        }
        source_player = {
            "external_player_id": "mapped-player-1001",
            "name": "Mapped Player",
            "normalized_name": "mapped player",
            "age": 24,
            "source_url": "https://example.com/team-a",
        }

        with (
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_load_target_observations",
                return_value=[observation],
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_load_target_team_seasons",
                return_value=[target],
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_load_player_profiles",
                return_value=[observation],
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader.fetch_all",
                side_effect=[[(1, "mapped-player-1001")], [(10, "team-a")]],
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_CapologyBrowserSession"
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_collect_source_groups_from_saved_team_slugs",
                return_value=(
                    {(8, "2024/2025"): {"team-a": [source_player]}},
                    [],
                    1,
                ),
            ) as collect_source_groups,
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_insert_capology_player_ids",
                return_value=0,
            ) as insert_capology_player_ids,
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_write_capology_player_ids_report",
                return_value=Path("report.json"),
            ),
        ):
            result = _collect_capology_player_ids("2024/2025", 8)

        self.assertEqual(collect_source_groups.call_args.args[0], [target])
        insert_capology_player_ids.assert_called_once_with([])
        self.assertEqual(result["fetched_capology_pages"], 1)
        self.assertEqual(result["existing_capology_mappings"], 1)

    def test_source_player_without_loaded_db_match_is_ignored(self):
        observation = {
            "competition_id": 8,
            "season_name": "2024/2025",
            "team_id": 10,
            "player_id": 1,
            "display_name": "DB Player",
            "full_name": "DB Player",
            "date_of_birth": date(2000, 1, 1),
        }
        target = {
            "competition_id": 8,
            "season_name": "2024/2025",
            "is_current": False,
            "team_id": 10,
            "team_name": "Team A",
        }
        source_player = {
            "external_player_id": "unknown-player-1001",
            "name": "Unknown Player",
            "normalized_name": "unknown player",
            "age": 24,
            "source_url": "https://example.com/team-a",
        }

        with (
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_load_target_observations",
                return_value=[observation],
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_load_target_team_seasons",
                return_value=[target],
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_load_player_profiles",
                return_value=[observation],
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader.fetch_all",
                side_effect=[[], [(10, "team-a")]],
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_CapologyBrowserSession"
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_collect_source_groups_from_saved_team_slugs",
                return_value=(
                    {(8, "2024/2025"): {"team-a": [source_player]}},
                    [],
                    1,
                ),
            ),
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_insert_capology_player_ids",
                return_value=0,
            ) as insert_capology_player_ids,
            patch(
                "one_touch_loader.loaders.capology_player_ids_loader."
                "_write_capology_player_ids_report",
                return_value=Path("report.json"),
            ),
        ):
            result = _collect_capology_player_ids("2024/2025", 8)

        insert_capology_player_ids.assert_called_once_with([])
        self.assertEqual(
            result["ignored_source_players_without_loaded_db_match"],
            1,
        )
        self.assertEqual(result["unresolved_capology_players"], 0)

    def test_current_season_salary_url_has_no_season_suffix(self):
        self.assertEqual(
            _capology_salary_url("barcelona", "2026/2027", True),
            "https://www.capology.com/club/barcelona/salaries/",
        )
        self.assertEqual(
            _capology_salary_url("barcelona", "2025/2026", False),
            "https://www.capology.com/club/barcelona/salaries/2025-2026/",
        )

    def test_name_normalization_keeps_exact_identity_comparable(self):
        self.assertEqual(
            _normalize_identity_text("  Marc-André  ter Stegen "),
            "marc andre ter stegen",
        )
        self.assertEqual(
            _normalize_identity_text("Abdallah N'Dour"),
            "abdallah ndour",
        )
        self.assertEqual(
            _normalize_identity_text("Filip Đorđević"),
            "filip djordjevic",
        )
        self.assertEqual(
            _normalize_identity_text("Guðmunds­son"),
            "gudmundsson",
        )

    def test_salary_page_parser_keeps_players_without_wages(self):
        html = """
        <html>
          <head><title>2024-2025 Test FC Salaries and Contracts</title></head>
          <body>
            <a href='/club/test-fc/salaries/'>Test FC</a>
            <a href='/club/other-fc/salaries/'>Other FC</a>
            <script>
              var data = [
                {
                  'name': "<a href='/player/jose-player-123/'>José Player</a>",
                  'position': "M",
                  'position_detail': "CM",
                  'age': Math.round("24"),
                  'country': "Spain",
                  'weekly_gross_eur': '-',
                  'annual_gross_eur': '-',
                },
              ];
              var data_payroll = [];
            </script>
          </body>
        </html>
        """

        players = _parse_capology_salary_page(
            html,
            "2024/2025",
        )

        self.assertEqual(len(players), 1)
        self.assertEqual(players[0]["external_player_id"], "jose-player-123")
        self.assertEqual(players[0]["name"], "José Player")
        self.assertEqual(players[0]["position_group_id"], 26)
        self.assertEqual(players[0]["age"], 24)
        self.assertIsNone(players[0]["estimated_weekly_gross_eur"])

    def test_salary_page_parser_uses_capology_eur_fixed_weekly_wage(self):
        html = """
        <html>
          <head><title>2026-2027 Test FC Salaries and Contracts</title></head>
          <body>
            <script>
              var data = [
                {
                  'name': "<a href='/player/test-player-123/'>Test Player</a>",
                  'weekly_gross_eur': accounting.formatMoney("31250000"/52, eur),
                  'weekly_gross_usd': accounting.formatMoney("25000000"/52, usd),
                },
              ];
              var data_payroll = [];
            </script>
          </body>
        </html>
        """

        players = _parse_capology_salary_page(html, "2026/2027")

        self.assertEqual(players[0]["estimated_weekly_gross_eur"], 600962)

    def test_historical_salary_page_parser_accepts_document_ready_delimiter(self):
        html = """
        <html>
          <head><title>2017-2018 Test FC Salaries and Contracts</title></head>
          <body>
            <script>
              var data = [
                {
                  'name': "<a href='/player/historical-player-456/'>Historical Player</a>",
                  'position': "D",
                  'position_detail': "CB",
                  'age': Math.round("25"),
                  'country': "England",
                },
              ]
              $(document).ready(function() {});
            </script>
          </body>
        </html>
        """

        players = _parse_capology_salary_page(
            html,
            "2017/2018",
        )

        self.assertEqual(len(players), 1)
        self.assertEqual(players[0]["external_player_id"], "historical-player-456")
        self.assertEqual(players[0]["name"], "Historical Player")
        self.assertEqual(players[0]["position_group_id"], 25)

    def test_salary_page_parser_keeps_distinct_full_ids_with_same_numeric_suffix(self):
        html = """
        <html>
          <head><title>2026-2027 Test FC Salaries and Contracts</title></head>
          <body>
            <script>
              var data = [
                {
                  'name': "<a href='/player/federico-valverde-35998/'>Federico Valverde</a>",
                },
                {
                  'name': "<a href='/player/marc-cucurella-35998/'>Marc Cucurella</a>",
                },
              ];
              var data_payroll = [];
            </script>
          </body>
        </html>
        """

        players = _parse_capology_salary_page(
            html,
            "2026/2027",
        )

        self.assertEqual(
            {
                player["external_player_id"]: player["name"]
                for player in players
            },
            {
                "federico-valverde-35998": "Federico Valverde",
                "marc-cucurella-35998": "Marc Cucurella",
            },
        )

if __name__ == "__main__":
    unittest.main()
