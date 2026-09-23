import json
import unittest
from copy import deepcopy
from pathlib import Path
from unittest.mock import Mock, call

from one_touch_loader.core.sportmonks import SportmonksClient


class SportmonksClientTest(unittest.TestCase):
    def test_statistics_batch_restores_requested_order_and_uses_single_request(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(return_value={'data': [{'id': 2, 'statistics': []}, {'id': 1, 'statistics': []}]})
        result = client.get_fixture_statistics_batch([1, 2])
        self.assertEqual([r['id'] for r in result], [1, 2])
        client._get.assert_called_once_with('fixtures/multi/1,2', params={'include': 'participants;statistics.type'})

    def test_statistics_batch_rejects_missing_duplicate_or_unrequested_fixtures(self):
        for ids in ([1], [1, 1], [1, 3]):
            with self.subTest(ids=ids):
                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(return_value={'data': [{'id': fid} for fid in ids]})
                with self.assertRaisesRegex(ValueError, 'response IDs differ'):
                    client.get_fixture_statistics_batch([1, 2])

    def test_statistics_batch_applies_same_team_corrections_as_single_fixture(self):
        from one_touch_loader.core.sportmonks import SPORTMONKS_FIXTURE_TEAM_ID_OVERRIDES
        fixture_id, mapping = next(iter(SPORTMONKS_FIXTURE_TEAM_ID_OVERRIDES.items()))
        original_id, corrected_id = next(iter(mapping.items()))
        payload = dict(id=fixture_id, participants=[{'id': original_id}],
                       statistics=[{'participant_id': original_id}])
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(side_effect=[{'data': deepcopy(payload)}, {'data': [deepcopy(payload)]}])
        single = client.get_fixture_with_statistics(fixture_id)
        batch = client.get_fixture_statistics_batch([fixture_id])[0]
        self.assertEqual(single, batch)
        self.assertEqual(batch['statistics'][0]['participant_id'], corrected_id)

    def test_bracket_endpoint_preserves_empty_provider_graph(self):
        client = SportmonksClient.__new__(SportmonksClient)
        graph = {'stages': [], 'edges': []}
        client._get = Mock(return_value={'data': graph})
        self.assertIs(client.get_season_bracket(25580), graph)
        client._get.assert_called_once_with('seasons/25580/brackets')

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
            ("sportmonks_2025_sant_andreu_actor_errors.json", {14671673456: 37655317, 14671673464: 37640778, 14671673466: 448466}),
            ("sportmonks_2025_quintanar_actor_errors.json", {14671668439: 37761933, 14671668424: 37786133}),
            ("sportmonks_2025_navalcarnero_lineup_errors.json", {14671658430: 37550527, 14671658425: 37717976}),
            ("sportmonks_2025_cano_tapiador_lineup_errors.json", {14671673528: 37297130, 14671656186: 37718920}),
            ("sportmonks_2025_birch_lineup_error.json", {14671853180: 37772590}),
            ("sportmonks_2025_paks_substitution_error.json", {}),
            ("sportmonks_2025_tre_fiori_first_lineup_errors.json", {
                14670288809: 37595507, 14670288810: 37773408, 14670288745: 5640808,
            }),
            ("sportmonks_2025_tre_fiori_return_lineup_errors.json", {
                14670316085: 5640808, 14670316269: 37773408, 14670316267: 22889283, 14670316268: 37595507,
            }),
            ("sportmonks_lineup_player_id_errors.json", {6955752879: 148658, 4321876: 148658}),
            ("sportmonks_2025_warlow_bench_red.json", {14670316645: 17576}),
            ("sportmonks_2025_kolgeci_lineup_errors.json", {14670343768: 37761577, 14670390670: 37761577}),
            ("sportmonks_2025_egnatia_jefferson_lineup_errors.json", {
                14670350172: 37630540, 14670390902: 37630540,
                14670436561: 37630540, 14670496246: 37630540,
            }),
            ("sportmonks_2025_sarajevo_owen_lineup_errors.json", {
                14670350259: 37287261, 14670381003: 37767760,
            }),
            ("sportmonks_2024_european_four_lineup_errors.json", {
                11196959425: 37308565, 11637798320: 6974918, 13619614185: 37659450,
            }),
            ("sportmonks_2024_cup_three_lineup_errors.json", {
                14001590773: 3876895, 14001590783: 31648559, 14001590785: 31648625,
                14001590768: 37786365, 14001590767: 37786370, 14001590781: 37786362,
                14001590774: 31625697, 14001590776: 37297119, 14001590764: 380522,
                14001590761: 37713992, 14001590777: 31648563, 14001590760: 37786368,
                13586488680: 380432, 13586488689: 9308210, 13586488674: 22859313,
                13586488682: 37586257, 13586488696: 37728288, 13586488677: 37788449,
                13586488679: 37549740, 14001303483: 445349, 14001303485: 32810211,
                14001303494: 32810345, 14001303498: 37262642, 14001303487: 37543063,
                14001303496: 37565149, 14001303475: 37786924, 14001303497: 37786927,
                14001303493: 37786928, 14001303489: 37263972, 14001303500: 37786931,
            }),
            ("sportmonks_lineup_izquierdo_error.json", {143428: 62408}),
            ("sportmonks_lineup_martinez_error.json", {142293: 31686}),
            ("sportmonks_lineup_event_player_mismatch.json", {14674391794: 37655935}),
            ("sportmonks_2026_hughes_lineup_error.json", {14674158335: 38219298}),
            ("sportmonks_2024_nixon_lineup_errors.json", {11934480093: 37259186, 14668918453: 37259186}),
            ("sportmonks_2024_ejea_lineup_errors.json", {
                14176285946: 37263060, 14176285941: 3510306,
                14176285953: 27440263, 14176285937: 37296890, 14176285951: 37262581,
            }),
            ("sportmonks_2024_velez_alassan_lineup_errors.json", {
                10951508407: 37287261, 11067586803: 37287261,
                10951567640: 37457529, 11067586823: 37457529, 14613111437: 37602913,
            }),
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
                        expected.update(sample.get("expected_lineup_fields", {}).get(str(before["id"]), {}))
                        stats = sample.get("stat_overrides", {}).get(str(before["id"]), {})
                        for detail in expected["details"]:
                            if str(detail["type_id"]) in stats:
                                detail["data"]["value"] = stats[str(detail["type_id"])]
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
            ("sportmonks_basaksehir_coach_error.json", {"player_id": None, "player_name": "Çagdas Atan", "coach_id": 30462}),
            ("sportmonks_tns_coach_error.json", {"player_id": None, "player_name": "Craig Harrison", "coach_id": 455867}),
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
                "sportmonks_2026_audited_event_actor_errors.json",
                "sportmonks_2024_audited_event_actor_errors.json",
                "sportmonks_2024_velez_event_errors.json",
                "sportmonks_2024_cup_three_event_errors.json",
                "sportmonks_2024_extremadura_event_errors.json",
            "sportmonks_2024_logrones_event_errors.json",
            "sportmonks_2024_cacereno_event_errors.json",
            "sportmonks_2024_ceuta_event_errors.json",
            "sportmonks_2024_sant_andreu_event_errors.json",
            "sportmonks_2024_conquense_event_errors.json",
            "sportmonks_2024_orihuela_event_errors.json",
                "sportmonks_2024_european_six_event_errors.json",
                "sportmonks_2024_sliema_own_goal_error.json",
                "sportmonks_2025_five_coach_duplicate_errors.json",
                "sportmonks_2025_three_coach_duplicate_errors.json",
                "sportmonks_2025_roma_fiorentina_brighton_event_errors.json",
                "sportmonks_2025_arteta_duplicate_error.json",
                "sportmonks_2025_yuri_duplicate_error.json",
                "sportmonks_2025_weiss_two_cards.json",
                "sportmonks_2025_newcastle_coach_duplicate.json",
                "sportmonks_2025_pafos_card_errors.json",
                "sportmonks_2023_weiss_var_error.json",
                "sportmonks_2018_completion_events.json",
                "sportmonks_2019_completion_events.json",
                "sportmonks_2019-semantic_completion_events.json",
                "sportmonks_negative_completion_events.json",
                "sportmonks_2020_completion_events.json", "sportmonks_2021_completion_events.json", "sportmonks_2022_completion_events.json", "sportmonks_2023_completion_events.json", "sportmonks_2024_completion_events.json", "sportmonks_2025_completion_events.json", "sportmonks_2025-semantic_completion_events.json", "sportmonks_2017_completion_events.json",
            )
        ]
        for case in (case for sample in samples for case in sample["cases"]):
            with self.subTest(fixture_id=case["fixture"]["id"]):
                original = deepcopy(case["fixture"])
                expected = {**deepcopy(original), "events": deepcopy(case["expected_events"])}
                retained = {e["id"]: e for e in expected["events"]}
                affected = next(e for e in original["events"] if e != retained.get(e["id"]))
                # 같은 팀 감독으로 확인된 카드는 공통 규칙으로 보정해요.
                # 다른 팀에 붙은 미검증 이벤트까지 선수 ID만 보고 바꾸지는 않아요.
                other_event = {**affected, "id": 900, "participant_id": -1}
                original["events"].append(deepcopy(other_event))
                expected["events"].append(deepcopy(other_event))
                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(return_value={"data": deepcopy(original)})
                self.assertEqual(client.get_fixture_details(original["id"]), expected)
                self.assertEqual(client._get.call_count, 1)


if __name__ == "__main__":
    unittest.main()
