import json
import unittest
from copy import deepcopy
from pathlib import Path
from unittest.mock import Mock, call

from one_touch_loader.core.sportmonks import SportmonksClient


class SportmonksClientTest(unittest.TestCase):
    def test_get_makes_one_request(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client.base = "https://api.sportmonks.com/v3/football"
        client.token = "test-token"
        client.timeout = 60
        client._wait_before_request = Mock()
        response = Mock()
        response.json.return_value = {"data": {"id": 8}}
        client._session = Mock()
        client._session.get.return_value = response

        result = client._get("leagues/8")

        self.assertEqual(result, {"data": {"id": 8}})
        client._session.get.assert_called_once_with(
            "https://api.sportmonks.com/v3/football/leagues/8",
            headers={
                "Accept": "application/json",
                "Authorization": "test-token",
            },
            params={},
            timeout=60,
        )
        response.raise_for_status.assert_called_once_with()

    def test_paginated_data_uses_observed_next_cursor_params(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(
            side_effect=[
                {
                    "data": [{"id": 1}],
                    "pagination": {
                        "has_more": True,
                        "next_cursor": (
                            "https://api.sportmonks.com/v3/football/fixtures"
                            "?cursor=next-token&filters=fixtureSeasons%3A28083"
                        ),
                    },
                },
                {
                    "data": [{"id": 2}],
                    "pagination": {
                        "has_more": False,
                        "next_cursor": None,
                    },
                },
            ]
        )

        rows = list(
            client._iter_paginated_data(
                "fixtures",
                params={
                    "filters": "fixtureSeasons:28083",
                    "per_page": 2,
                },
            )
        )

        self.assertEqual(rows, [{"id": 1}, {"id": 2}])
        self.assertEqual(
            client._get.call_args_list,
            [
                call(
                    "fixtures",
                    params={
                        "filters": "fixtureSeasons:28083",
                        "per_page": 2,
                    },
                    base_url=None,
                ),
                call(
                    "fixtures",
                    params={
                        "cursor": "next-token",
                        "filters": "fixtureSeasons:28083",
                    },
                    base_url=None,
                ),
            ],
        )

    def test_empty_fixture_result_without_pagination_stops_after_one_request(self):
        # 실제 시즌 28138 응답에서 페이지 순회와 무관한 구독·요청 잔량만 생략했어요.
        response = json.loads(
            (Path(__file__).parent / "fixtures" / "sportmonks_empty_cup_fixtures.json")
            .read_text(encoding="utf-8")
        )
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(return_value=response)

        self.assertEqual(list(client.iter_fixtures_by_season(28138, include="participants")), [])
        client._get.assert_called_once_with(
            "fixtures",
            params={"filters": "fixtureSeasons:28138", "per_page": 100, "include": "participants"},
            base_url=None,
        )

    def test_verified_single_page_methods_read_data_directly(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(return_value={"data": [{"id": 1}]})

        self.assertEqual(list(client.iter_teams_by_season(28083)), [{"id": 1}])
        self.assertEqual(client.get_team_squad(3), [{"id": 1}])
        self.assertEqual(
            client.get_team_season_squad(3, 28083),
            [{"id": 1}],
        )
        self.assertEqual(client.get_standings_for_season(28083), [{"id": 1}])
        self.assertEqual(client.get_rounds_for_season(28083), [{"id": 1}])

    def test_player_without_single_profile_returns_none(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(return_value={"rate_limit": {}})

        self.assertIsNone(client.get_player_or_none(73643))

    def test_observed_unavailable_player_is_distinct_from_empty_current_teams(self):
        source=json.loads((Path(__file__).parent / "fixtures/sportmonks_unavailable_player.json").read_text(encoding="utf-8"))
        client=SportmonksClient.__new__(SportmonksClient)
        client._get=Mock(side_effect=[source["profile_response"],source["teams_response"],{"data":{"id":94761,"teams":[]}}])
        self.assertIsNone(client.get_player_or_none(source["player_id"]))
        self.assertIsNone(client.get_player_current_teams(source["player_id"]))
        self.assertEqual(client.get_player_current_teams(94761),[])
        self.assertEqual(client._get.call_args_list,[
            call("players/43393",params=None),
            call("players/43393",params={"include":"teams.team"}),
            call("players/94761",params={"include":"teams.team"}),
        ])

    def test_standings_requests_only_used_relation(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(return_value={"data": [{"id": 1}]})

        self.assertEqual(client.get_standings_for_season(28083), [{"id": 1}])
        client._get.assert_called_once_with(
            "standings/seasons/28083",
            params={"include": "details.type"},
        )

    def test_fixture_details_requests_only_verified_relations(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(return_value={"data": {"id": 19439612, "lineups": [], "events": []}})

        self.assertEqual(
            client.get_fixture_details(19439612),
            {"id": 19439612, "lineups": [], "events": []},
        )
        client._get.assert_called_once_with(
            "fixtures/19439612",
            params={
                "include": (
                    "events.type;statistics.type;lineups.details;"
                    "lineups.player;formations;coaches;pressure"
                )
            },
        )

    def test_verified_player_corrections_preserve_both_lineup_slots(self):
        cases = (
            ("sportmonks_lineup_player_id_errors.json", {6955752879: 148658, 4321876: 148658}),
            ("sportmonks_lineup_izquierdo_error.json", {143428: 62408}),
            ("sportmonks_lineup_martinez_error.json", {142293: 31686}),
            ("sportmonks_lineup_event_player_mismatch.json", {14674391794: 37655935}),
            ("sportmonks_2026_strassen_actor_errors.json", {
                14674130745: 21404660, 14674145259: 21404660,
                14674130710: 435952, 14674145202: 435952,
            }),
            ("sportmonks_lineup_2022_spanish_errors.json", {
                79284464: 37608061, 7250503808: 37614327,
                6685486486: 37592616, 6685486116: 37308357, 6685486219: 37543847,
                1011309558: 37590132, 7250492567: 37598694,
            }),
        )
        for filename, corrected_lineup_ids in cases:
            sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            players = {player["id"]: player for player in sample["correct_players"]}
            for original in sample["fixtures"]:
                with self.subTest(fixture_id=original["id"]):
                    original = {**original, "events": []}
                    client = SportmonksClient.__new__(SportmonksClient)
                    player_ids = [corrected_lineup_ids[row["id"]] for row in original["lineups"] if row["id"] in corrected_lineup_ids]
                    client._get = Mock(side_effect=[
                        {"data": deepcopy(original)},
                        *({"data": players[player_id]} for player_id in player_ids),
                    ])
                    result = client.get_fixture_details(original["id"])
                    self.assertEqual(len(result["lineups"]), len(original["lineups"]))
                    for before, after in zip(original["lineups"], result["lineups"]):
                        expected = deepcopy(before)
                        if before["id"] in corrected_lineup_ids:
                            player_id = corrected_lineup_ids[before["id"]]
                            expected["player_id"] = player_id
                            expected["player"] = players[player_id]
                        self.assertEqual(after, expected)
                    self.assertEqual(client._get.call_args_list[1:], [call(f"players/{player_id}") for player_id in player_ids])
                    self.assertEqual(client._get.call_count, 1 + len(player_ids))

    def test_verified_event_correction_does_not_rewrite_other_events_or_profiles(self):
        cases = (
            ("sportmonks_event_related_player_error.json", {"related_player_id": 185640, "related_player_name": "Javi López"}),
            ("sportmonks_event_minute_error.json", {"minute": 90, "extra_minute": 6}),
            ("sportmonks_sampaoli_event_minute_error.json", {"minute": 59}),
            ("sportmonks_coach_event_player_error.json", {"player_id": None, "player_name": "Cristian Stellini", "coach_id": 128374, "on_bench": True}),
        )
        for filename, correction in cases:
            with self.subTest(filename=filename):
                sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
                original = deepcopy(sample["fixture"])
                # 같은 값이라도 검증한 이벤트 밖에서는 자동으로 치환하지 않아요.
                original["events"].append({**original["events"][0], "id": 900})
                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(return_value={"data": deepcopy(original)})

                result = client.get_fixture_details(original["id"])

                expected = deepcopy(original)
                expected["events"][0].update(correction)
                self.assertEqual(result, expected)
                self.assertEqual(client._get.call_count, 1)


    def test_verified_duplicate_cards_preserve_other_events_and_bench_red_card(self):
        cases = (
            ("sportmonks_duplicate_cards.json", {67695288, 29992873}, {67695281: {"minute": 50}}, [(78696510, 85, True)]),
            ("sportmonks_salernitana_duplicate_cards.json", {67945179, 67945141}, {}, [(78866603, 69, True), (78866604, 69, True)]),
            ("sportmonks_duplicate_coach_cards.json", {149481174, 149481175}, {}, [(120554621, 84, False), (120573201, 84, False)]),
        )
        for filename, excluded_ids, corrections, retained_cards in cases:
            with self.subTest(filename=filename):
                sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
                original = deepcopy(sample["fixture"])
                # 다른 이벤트의 음수·같은 선수 카드는 확인한 중복 ID로 취급하지 않아요.
                for other_id, source_id in enumerate(sorted(excluded_ids | corrections.keys()), start=900):
                    original["events"].append({**next(e for e in original["events"] if e["id"] == source_id), "id": other_id})
                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(return_value={"data": deepcopy(original)})

                result = client.get_fixture_details(original["id"])

                expected = deepcopy(original)
                expected["events"] = [e for e in expected["events"] if e["id"] not in excluded_ids]
                for event_id, correction in corrections.items():
                    next(e for e in expected["events"] if e["id"] == event_id).update(correction)
                self.assertEqual(result, expected)
                for event_id, minute, on_bench in retained_cards:
                    retained = next(e for e in result["events"] if e["id"] == event_id)
                    self.assertEqual((retained["minute"], retained["on_bench"]), (minute, on_bench))
                self.assertEqual(client._get.call_count, 1)

    def test_event_actors_match_verified_match_records(self):
        samples = [
            json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            for filename in (
                "sportmonks_2024_event_actor_errors.json",
                "sportmonks_2025_event_actor_errors.json",
                "sportmonks_2026_event_actor_errors.json",
                "sportmonks_2026_ki_event_actor_errors.json",
                "sportmonks_2026_sutjeska_event_actor_errors.json",
                "sportmonks_2026_qualifying_event_actor_errors.json",
            )
        ]
        for case in (case for sample in samples for case in sample["cases"]):
            with self.subTest(fixture_id=case["fixture"]["id"]):
                original = deepcopy(case["fixture"])
                expected = {**deepcopy(original), "events": deepcopy(case["expected_events"])}
                retained = {e["id"]: e for e in expected["events"]}
                affected = next(e for e in original["events"] if e != retained.get(e["id"]))
                # 선수·감독 ID와 이름이 같아도 확인하지 않은 이벤트에는 보정하지 않아요.
                other_event = {**affected, "id": 900}
                original["events"].append(deepcopy(other_event))
                expected["events"].append(deepcopy(other_event))
                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(return_value={"data": deepcopy(original)})
                self.assertEqual(client.get_fixture_details(original["id"]), expected)
                self.assertEqual(client._get.call_count, 1)


if __name__ == "__main__":
    unittest.main()
