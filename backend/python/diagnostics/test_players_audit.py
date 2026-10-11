import json
from pathlib import Path
import unittest

from one_touch_loader.loaders.players_loader import (
    _audit_direct_player_profile,
    _audit_squad_observation,
    _build_player_row,
    _merge_embedded_player_profiles,
)
from one_touch_loader.loaders.team_squad_members_loader import (
    _exclude_sportmonks_duplicate_players,
)


class PlayersAuditTest(unittest.TestCase):
    def setUp(self):
        self.scope = {
            "competition_id": 8,
            "season_id": 19734,
            "season_name": "2017/2018",
            "is_current": False,
            "team_id": 19,
            "team_name": "West Ham United",
        }

    def test_empty_full_name_uses_complete_parts_in_each_profile_path(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks_player_empty_full_name.json").read_text())
        player = sample["player"]
        for missing_name in ("", " \t ", None):
            raw = {**player, "name": missing_name}
            direct = _audit_direct_player_profile(raw, raw["id"])
            squad = _audit_squad_observation(
                {"player_id": raw["id"], "player": raw}, self.scope, 0,
            )
            profiles = {
                "player_endpoint": direct,
                "squad_profile": _merge_embedded_player_profiles(raw["id"], [squad]),
            }
            for source, profile in profiles.items():
                with self.subTest(missing_name=missing_name, source=source):
                    row, _ = _build_player_row(profile, [squad], {153}, source)
                    self.assertEqual(row[:3], (raw["id"], raw["display_name"], sample["expected_full_name"]))
                    self.assertEqual(row[5], raw["date_of_birth"])
            self.assertEqual(direct["full_name"], missing_name)

    def test_valid_full_name_takes_priority_over_name_parts(self):
        profile = {"player_id": 1, "full_name": "  Existing Name  ",
                   "display_name": "Display Name", "firstname": "Other", "lastname": "Parts"}
        row, _ = _build_player_row(profile, [], set(), "player_endpoint")
        self.assertEqual(row[1:3], ("Display Name", "Existing Name"))

    def test_incomplete_name_parts_still_fail_with_player_id(self):
        for field in ("firstname", "lastname"):
            for value in (None, "", " \t "):
                with self.subTest(field=field, value=value):
                    profile = {"player_id": 37605593, "full_name": "", "display_name": "Jesús Martínez",
                               "firstname": "Jesús", "lastname": "Martínez Girón", field: value}
                    with self.assertRaisesRegex(ValueError, "player_id=37605593.*full_name"):
                        _build_player_row(profile, [], set(), "player_endpoint")

    def test_name_parts_do_not_hide_invalid_field_types(self):
        with self.assertRaisesRegex(ValueError, "Invalid string: player.name"):
            _audit_direct_player_profile(
                {"name": 123, "firstname": "Jesús", "lastname": "Martínez Girón"}, 37605593,
            )

    def test_name_parts_are_not_combined_across_profiles(self):
        base = {"player_id": 37605593, "full_name": "", "display_name": "Jesús Martínez"}
        profiles = [{**base, "firstname": "Jesús", "lastname": None},
                    {**base, "firstname": None, "lastname": "Martínez Girón"}]
        merged = _merge_embedded_player_profiles(37605593, profiles)
        with self.assertRaisesRegex(ValueError, "player_id=37605593.*full_name"):
            _build_player_row(merged, profiles, set(), "squad_profile")

    def test_missing_detailed_position_is_recorded_without_failing(self):
        observation = _audit_squad_observation(
            {
                "player_id": 237,
                "team_id": 19,
                "season_id": 19734,
                "position_id": 25,
                "detailed_position_id": None,
                "player": {
                    "id": 237,
                    "common_name": "Pablo Zabaleta",
                    "firstname": "Pablo Javier",
                    "lastname": "Zabaleta Girod",
                    "name": "Pablo Zabaleta",
                    "display_name": "Pablo Zabaleta",
                    "detailed_position_id": None,
                    "nationality_id": 32,
                    "date_of_birth": "1985-01-16",
                    "height": 176,
                    "weight": 74,
                    "image_path": "https://example.com/player.png",
                },
            },
            self.scope,
            0,
        )

        self.assertEqual(observation["player_id"], 237)
        self.assertIsNone(observation["position_id"])
        self.assertEqual(observation["position_group_id"], 25)

    def test_direct_player_profile_uses_player_endpoint_fields(self):
        profile = _audit_direct_player_profile(
            {
                "id": 237,
                "common_name": "P. Zabaleta",
                "firstname": "Pablo Javier",
                "lastname": "Zabaleta Girod",
                "name": "Pablo Javier Zabaleta Girod",
                "display_name": "Pablo Zabaleta",
                "position_id": 25,
                "detailed_position_id": 154,
                "nationality_id": 32,
                "date_of_birth": "1985-01-16",
                "height": 176,
                "weight": 74,
                "image_path": "https://example.com/player.png",
            },
            237,
        )

        self.assertEqual(profile["player_id"], 237)
        self.assertEqual(profile["position_id"], 154)
        self.assertEqual(profile["position_group_id"], 25)

    def test_squad_position_is_used_when_direct_position_is_missing(self):
        direct_profile = {
            "player_id": 27393,
            "display_name": "Ragnar Ache",
            "full_name": "Ragnar Ache",
            "position_id": None,
            "nationality_id": 11,
            "date_of_birth": "1998-07-28",
            "height_cm": 183,
            "weight_kg": 80,
            "image_path": "https://example.com/player.png",
        }
        embedded_profiles = [{**direct_profile, "position_id": 151}]

        row, resolution = _build_player_row(
            direct_profile,
            embedded_profiles,
            {24, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 163},
            "player_endpoint",
        )

        self.assertEqual(row[3], 151)
        self.assertEqual(resolution["position_source"], "squad_profile")

    def test_unverified_detailed_position_is_stored_as_null(self):
        profile = {
            "player_id": 237,
            "display_name": "Pablo Zabaleta",
            "full_name": "Pablo Javier Zabaleta Girod",
            "position_id": None,
            "nationality_id": 44,
            "date_of_birth": "1985-01-16",
            "height_cm": 176,
            "weight_kg": 74,
            "image_path": "https://example.com/player.png",
        }

        row, resolution = _build_player_row(
            profile,
            [profile],
            {24, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 163},
            "player_endpoint",
        )

        self.assertIsNone(row[3])
        self.assertEqual(resolution["position_source"], "unavailable")

    def test_non_playing_position_uses_full_name_for_display(self):
        profile = {
            "player_id": 3817,
            "display_name": "Nurgazy Khayrulin",
            "full_name": "Shkodran Mustafi",
            "position_id": 227,
            "nationality_id": 11,
            "date_of_birth": "1992-04-17",
            "height_cm": 184,
            "weight_kg": 82,
            "image_path": "https://example.com/player.png",
        }

        row, resolution = _build_player_row(
            profile,
            [profile],
            {24, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 163},
            "player_endpoint",
        )

        self.assertEqual(row[1], "Shkodran Mustafi")
        self.assertIsNone(row[3])
        self.assertTrue(resolution["corrected_display_name"])

    def test_german_pezzella_name_overrides_use_confirmed_names(self):
        profile = {
            "player_id": 186733,
            "display_name": "Rasmus Jansson",
            "full_name": "Germán Alejandro Pezzella",
            "position_id": 148,
            "nationality_id": None,
            "date_of_birth": None,
            "height_cm": None,
            "weight_kg": None,
            "image_path": None,
        }

        row, resolution = _build_player_row(
            profile,
            [profile],
            {24, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 163},
            "player_endpoint",
        )

        self.assertEqual(row[1], "Germán Pezzella")
        self.assertEqual(row[2], "Germán Alejo Pezzella")
        self.assertTrue(resolution["corrected_display_name"])

    def test_roberto_pereyra_display_name_override_uses_confirmed_name(self):
        profile = {
            "player_id": 4764,
            "display_name": "Brian Gartland",
            "full_name": "Roberto Maximiliano Pereyra",
            "position_id": 153,
            "nationality_id": None,
            "date_of_birth": None,
            "height_cm": None,
            "weight_kg": None,
            "image_path": None,
        }

        row, resolution = _build_player_row(
            profile,
            [profile],
            {24, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 163},
            "player_endpoint",
        )

        self.assertEqual(row[1], "Roberto Pereyra")
        self.assertEqual(row[2], "Roberto Maximiliano Pereyra")
        self.assertTrue(resolution["corrected_display_name"])

    def test_confirmed_display_name_overrides(self):
        confirmed_names = {
            1101: "Robbie Brady",
            1384: "Billy Sharp",
            33587: "Jeremy Dudziak",
            34777: "Saulo Decarli",
            95661: "Gaëtan Charbonnier",
            129225: "Simone Verdi",
            169484: "Aleksandr Kokorin",
            186345: "Yoel Rodríguez",
            3526289: "Brice Tutu",
            37612429: "Matteo Fiorenza",
        }

        for player_id, confirmed_name in confirmed_names.items():
            with self.subTest(player_id=player_id):
                profile = {
                    "player_id": player_id,
                    "display_name": "Wrong display name",
                    "full_name": confirmed_name,
                    "position_id": 148,
                    "nationality_id": None,
                    "date_of_birth": None,
                    "height_cm": None,
                    "weight_kg": None,
                    "image_path": None,
                }

                row, resolution = _build_player_row(
                    profile,
                    [profile],
                    {148},
                    "player_endpoint",
                )

                self.assertEqual(row[1], confirmed_name)
                self.assertEqual(row[2], confirmed_name)
                self.assertTrue(resolution["corrected_display_name"])

    def test_confirmed_full_name_overrides(self):
        confirmed_names = {
            6974589: "Nazim Babaï",
            7745874: "Iker Álvarez de Eulate Molné",
            29720457: "Hugo Burcio García",
            37316544: "Pedro Alemañ Serna",
            37607269: "Jacopo Grossi",
            37615677: "Amine Salama",
            37676379: "Vicent Abril Sanz",
        }

        for player_id, confirmed_name in confirmed_names.items():
            with self.subTest(player_id=player_id):
                profile = {
                    "player_id": player_id,
                    "display_name": confirmed_name,
                    "full_name": "Wrong full name",
                    "position_id": 148,
                    "nationality_id": None,
                    "date_of_birth": None,
                    "height_cm": None,
                    "weight_kg": None,
                    "image_path": None,
                }

                row, resolution = _build_player_row(
                    profile,
                    [profile],
                    {148},
                    "player_endpoint",
                )

                self.assertEqual(row[1], confirmed_name)
                self.assertEqual(row[2], confirmed_name)
                self.assertFalse(resolution["corrected_display_name"])

    def test_mixed_toma_basic_duplicate_is_excluded(self):
        canonical_item = {"player_id": 74062}

        filtered, excluded = _exclude_sportmonks_duplicate_players(
            [
                {"player_id": 73643},
                canonical_item,
            ]
        )

        self.assertEqual(filtered, [canonical_item])
        self.assertEqual(excluded, {73643: 74062})

    def test_missing_endpoint_data_can_use_embedded_profile(self):
        embedded_profiles = [
            {
                "player_id": 36653,
                "display_name": "Tom Baack",
                "full_name": "Tom Baack",
                "position_id": 149,
                "nationality_id": 11,
                "date_of_birth": "1999-03-13",
                "height_cm": 188,
                "weight_kg": 75,
                "image_path": "https://example.com/player.png",
            }
        ]

        merged = _merge_embedded_player_profiles(36653, embedded_profiles)
        row, resolution = _build_player_row(
            merged,
            embedded_profiles,
            {24, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 163},
            "squad_profile",
        )

        self.assertEqual(row[0], 36653)
        self.assertEqual(row[3], 149)
        self.assertEqual(resolution["profile_source"], "squad_profile")


if __name__ == "__main__":
    unittest.main()
