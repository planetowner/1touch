from __future__ import annotations

import json
from collections import defaultdict
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

from selenium.common.exceptions import TimeoutException

from ..core.db import fetch_all, transaction
from ..core.identity import validate_external_id_uniqueness
from .capology_common import (
    _CapologyBrowserSession,
    _canonical_capology_player_id,
    _capology_salary_url,
    _load_target_observations,
    _normalize_identity_text,
    _observation_name_keys,
    _parse_capology_salary_page,
    _season_to_capology,
)
from .capology_team_slugs_loader import _load_target_team_seasons


CAPOLOGY_PLAYER_IDS_DIAGNOSTICS_DIRECTORY = (
    Path(__file__).resolve().parents[3] / "logs" / "diagnostics"
)
SQL_SELECT_EXISTING_CAPOLOGY_PLAYER_IDS = """
SELECT player_id, external_player_id
FROM player_external_ids
WHERE provider = 'capology'
ORDER BY player_id
"""

SQL_SELECT_CAPOLOGY_TEAM_SLUGS = """
SELECT team_id, external_team_id
FROM team_external_ids
WHERE provider = 'capology'
ORDER BY team_id
"""

SQL_SELECT_PLAYER_PROFILES = """
SELECT
  player_id,
  display_name,
  full_name,
  date_of_birth
FROM players
ORDER BY player_id
"""

SQL_SELECT_PLAYER_TEAM_IDS = """
SELECT DISTINCT player_id, team_id
FROM team_squad_members
ORDER BY player_id, team_id
"""

SQL_INSERT_CAPOLOGY_ID = """
INSERT INTO player_external_ids (
  player_id,
  provider,
  external_player_id
)
VALUES (%s,'capology',%s)
"""

# Capology와 DB가 같은 선수를 서로 다른 이름으로 제공하는 확인된 경우예요.
VERIFIED_CAPOLOGY_NAME_EQUIVALENTS = (
    frozenset(
        {
            _normalize_identity_text("Alejandro Balde"),
            _normalize_identity_text("Álex Balde"),
        }
    ),
)

# 현재 DB 선수와 Sportmonks 원본 프로필을 Capology의 이름, 팀, 시즌과 대조한 매핑이에요.
VERIFIED_CAPOLOGY_PLAYER_ID_OVERRIDES = {
    "adama-traore-34878": 65651,
    "aday-benitez-32127": 188714,
    "adil-bourabaa-38420": 37713829,
    "ahmed-elmohamady-32029": 628,
    "akin-famewo-36108": 12562,
    "alejandro-rodriguez-33449": 129479,
    "alex-petxa-35467": 8456322,
    "amine-moussaoui-39079": 37737424,
    "andrej-galabinov-32460": 132129,
    "andrii-yarmolenko-32804": 204697,
    "andy-irving-36659": 378629,
    "ange-caumenan-n-guessan-37865": 37532696,
    "ashley-phillips-38529": 37582649,
    "ben-karamoko-34836": 96654,
    "berkay-yilmaz-38408": 37615861,
    "bono-33333": 186591,
    "brandon-34734": 186765,
    "brayann-pereira-37762": 37342613,
    "brian-madjo-39825": 37921359,
    "burak-yilmaz-31243": 199811,
    "calum-scanlon-38397": 37565676,
    "cem-turkmen-37344": 37266028,
    "chaka-traore-38344": 37553578,
    "chicharito-32295": 736,
    "chory-castro-30939": 185108,
    "cristo-35727": 188896,
    "dan-potts-34437": 4229,
    "danny-loader-36766": 580971,
    "darline-yongwa-36791": 35271244,
    "david-costa-36896": 37332072,
    "demeaco-duhaney-36081": 537207,
    "dennis-eckert-35439": 418401,
    "dermane-karim-37981": 37576587,
    "derrick-luckassen-34883": 25332,
    "elhadji-pape-diaw-34699": 66845,
    "enis-destan-37422": 37375216,
    "eugeni-valderrama-34534": 187272,
    "fedor-smolov-32913": 24011,
    "firmin-mubele-34441": 97738,
    "flavio-bianchi-36549": 37527138,
    "flavio-russo-38230": 37589769,
    "francesco-pio-russo-36220": 8417255,
    "franck-djoulou-36161": 765724,
    "giacomo-faticanti-38199": 37590700,
    "giovanni-sio-32598": 31574,
    "hakim-el-mokeddem-36206": 529848,
    "harrison-manzala-34399": 98481,
    "harry-clarke-36952": 7026563,
    "ibai-gomez-32823": 185855,
    "ismail-koybasi-32699": 200541,
    "iwo-kaczmarski-38093": 37332705,
    "javi-castro-36782": 37296898,
    "javi-eraso-32954": 186701,
    "javi-jimenez-35500": 380738,
    "jimmy-jay-morgan-38738": 37589606,
    "joao-victor-34420": 54164,
    "joe-whitworth-38046": 37391506,
    "jonathan-viera-32802": 63168,
    "jorge-cestero-38800": 37726288,
    "joshua-da-silva-36091": 339093,
    "juanjo-camacho-29435": 187496,
    "juanpi-anor-34358": 186524,
    "kamari-doyle-38565": 37558443,
    "kayembe-34554": 160173,
    "kyliane-dong-38257": 37590907,
    "lago-junior-33238": 186191,
    "lino-sousa-38371": 37536817,
    "louie-marsh-38170": 37559763,
    "luca-barrington-38333": 37581762,
    "luca-sangalli-34740": 446926,
    "luis-rojas-37321": 37306819,
    "luisinho-31172": 159020,
    "luka-duric-37790": 37538099,
    "maissa-ndiaye-37284": 37600568,
    "mamadou-kone-33597": 186107,
    "mamadou-mbow-36593": 29336632,
    "mame-diouf-32127": 410,
    "markel-susaeta-32125": 185269,
    "mason-burstow-37837": 37563931,
    "matheus-pereira-35851": 130024,
    "matt-dibley-dias-37923": 37537754,
    "mattia-compagnon-37201": 37526529,
    "mert-cetin-35431": 437210,
    "metehan-guclu-36252": 432914,
    "michael-scarf-36290": 4545326,
    "miguelon-35082": 187072,
    "mika-baur-38177": 37582048,
    "munas-dabbur-33738": 52792,
    "mustapha-diallo-31546": 96169,
    "naime-said-mchindra-38500": 37602496,
    "niall-huggins-36878": 37391787,
    "niccolo-cabras-36933": 6642454,
    "nicolas-gaitan-32196": 158926,
    "noel-aseko-38678": 37590606,
    "omari-kellyman-38610": 37583510,
    "onel-hernandez-34001": 34706,
    "pantelis-chatzidiakos-35448": 26719,
    "pape-diop-31490": 185563,
    "patrick-zabi-38984": 37912348,
    "rafinha-31297": 29830,
    "rob-green-29238": 143,
    "robert-ibanez-34050": 186523,
    "rodri-36572": 35281052,
    "romaine-sawyers-33544": 3306,
    "saliou-diop-38484": 37773773,
    "salomon-kalou-31264": 72,
    "samu-garcia-33067": 170673,
    "samy-morsy-33491": 3189,
    "santy-ngom-34035": 432698,
    "sergi-gonzalez-34845": 381887,
    "silas-katompa-mvumpa-36074": 14350739,
    "suleman-sani-38961": 37635455,
    "sung-yong-ki-32532": 813,
    "tommaso-milanese-37468": 37545668,
    "trezeguet-34608": 62879,
    "val-adedokun-37666": 37539850,
    "vasilios-lampropoulos-32963": 107871,
    "vasilios-torosidis-31208": 106963,
    "viktor-tsyhankov-35749": 205635,
    "wayne-rooney-31344": 579,
    "yahya-soumare-36700": 10948425,
    "yevhen-shakhov-33207": 109416,
    "yunus-emre-konak-38727": 37709434,
}


def _collect_source_groups_from_saved_team_slugs(
    observations: List[Dict[str, object]],
    team_slugs_by_id: Dict[int, str],
    session: _CapologyBrowserSession,
) -> Tuple[
    Dict[Tuple[int, str], Dict[str, List[Dict[str, object]]]],
    List[Dict[str, object]],
    int,
]:
    observations_by_group: Dict[
        Tuple[int, str, bool], List[Dict[str, object]]
    ] = defaultdict(list)
    for observation in observations:
        observations_by_group[
            (
                int(observation["competition_id"]),
                str(observation["season_name"]),
                bool(observation["is_current"]),
            )
        ].append(observation)

    group_keys = sorted(observations_by_group)
    source_groups: Dict[
        Tuple[int, str], Dict[str, List[Dict[str, object]]]
    ] = {}
    failures: List[Dict[str, object]] = []
    fetched_pages = 0
    for group_index, group_key in enumerate(group_keys, start=1):
        competition_id, season_name, is_current = group_key
        group_observations = observations_by_group[group_key]
        target_teams = sorted(
            {
                (int(item["team_id"]), str(item["team_name"]))
                for item in group_observations
            }
        )
        source_teams: Dict[str, List[Dict[str, object]]] = {}

        for team_index, (team_id, team_name) in enumerate(
            target_teams,
            start=1,
        ):
            team_slug = team_slugs_by_id.get(team_id)
            if team_slug is None:
                failures.append(
                    {
                        "competition_id": competition_id,
                        "season_name": season_name,
                        "team_id": team_id,
                        "team_name": team_name,
                        "team_slug": None,
                        "source_url": None,
                        "error_type": "MissingCapologyTeamSlug",
                        "error": "team_external_ids has no Capology slug",
                    }
                )
                print(
                    f"[capology-player-ids sources {group_index}/{len(group_keys)} "
                    f"team {team_index}/{len(target_teams)}] "
                    f"season={season_name} competition={competition_id} "
                    f"team_id={team_id}: ERROR MissingCapologyTeamSlug"
                )
            else:
                source_url = _capology_salary_url(
                    team_slug,
                    season_name,
                    is_current,
                )
                try:
                    html, response_url = session.fetch(source_url)
                    source_players = _parse_capology_salary_page(
                        html,
                        season_name,
                    )
                    for source_player in source_players:
                        source_player["team_slug"] = team_slug
                        source_player["source_url"] = response_url
                    source_teams[team_slug] = source_players
                    fetched_pages += 1
                    print(
                        f"[capology-player-ids sources {group_index}/{len(group_keys)} "
                        f"team {team_index}/{len(target_teams)}] "
                        f"season={season_name} competition={competition_id} "
                        f"team={team_slug} players={len(source_players)}"
                    )
                except (ValueError, TimeoutException) as exc:
                    console_error = str(exc).encode(
                        "ascii",
                        errors="backslashreplace",
                    ).decode("ascii")
                    failures.append(
                        {
                            "competition_id": competition_id,
                            "season_name": season_name,
                            "team_id": team_id,
                            "team_name": team_name,
                            "team_slug": team_slug,
                            "source_url": source_url,
                            "error_type": type(exc).__name__,
                            "error": str(exc),
                        }
                    )
                    print(
                        f"[capology-player-ids sources {group_index}/{len(group_keys)} "
                        f"team {team_index}/{len(target_teams)}] "
                        f"season={season_name} competition={competition_id} "
                        f"team={team_slug}: ERROR {type(exc).__name__}: "
                        f"{console_error}"
                    )

        if source_teams:
            source_groups[(competition_id, season_name)] = source_teams

    return source_groups, failures, fetched_pages


def _age_on(day: date, birth_date: date) -> int:
    return day.year - birth_date.year - (
        (day.month, day.day) < (birth_date.month, birth_date.day)
    )


def _age_matches(
    observation: Dict[str, object],
    source_player: Dict[str, object],
) -> Optional[bool]:
    raw_birth_date = observation.get("date_of_birth")
    source_age = source_player.get("age")
    if raw_birth_date is None or source_age is None:
        return None
    if isinstance(raw_birth_date, datetime):
        birth_date = raw_birth_date.date()
    elif isinstance(raw_birth_date, date):
        birth_date = raw_birth_date
    else:
        birth_date = date.fromisoformat(str(raw_birth_date)[:10])
    season_path = _season_to_capology(str(observation["season_name"]))
    start_year = int(season_path[:4])
    season_start = date(start_year, 7, 1)
    season_end = date(start_year + 1, 6, 30)
    expected_ages = {
        _age_on(season_start, birth_date),
        _age_on(season_end, birth_date),
    }
    return int(source_age) in expected_ages


def _country_matches(
    observation: Dict[str, object],
    source_player: Dict[str, object],
) -> Optional[bool]:
    country = observation.get("country")
    source_country = source_player.get("country")
    if country is None or source_country is None:
        return None
    return _normalize_identity_text(str(country)) == _normalize_identity_text(
        str(source_country)
    )


def _position_matches(
    observation: Dict[str, object],
    source_player: Dict[str, object],
) -> Optional[bool]:
    position_group_id = observation.get("position_group_id")
    source_position_group_id = source_player.get("position_group_id")
    if position_group_id is None or source_position_group_id is None:
        return None
    return int(position_group_id) == int(source_position_group_id)


def _identity_checks(
    observation: Dict[str, object],
    source_player: Dict[str, object],
) -> Dict[str, Optional[bool]]:
    return {
        "age": _age_matches(observation, source_player),
        "country": _country_matches(observation, source_player),
        "position_group": _position_matches(observation, source_player),
    }


def _has_complete_identity_support(
    checks: Dict[str, Optional[bool]],
) -> bool:
    return all(value is True for value in checks.values())


def _load_player_profiles() -> List[Dict[str, object]]:
    team_ids_by_player: Dict[int, Set[int]] = defaultdict(set)
    for player_id, team_id in fetch_all(SQL_SELECT_PLAYER_TEAM_IDS):
        team_ids_by_player[int(player_id)].add(int(team_id))
    return [
        {
            "player_id": int(player_id),
            "display_name": str(display_name),
            "full_name": str(full_name),
            "date_of_birth": date_of_birth,
            "team_ids": team_ids_by_player[int(player_id)],
        }
        for player_id, display_name, full_name, date_of_birth in fetch_all(
            SQL_SELECT_PLAYER_PROFILES
        )
    ]


def _contains_normalized_name_phrase(
    observation: Dict[str, object],
    source_player: Dict[str, object],
) -> bool:
    source_tokens = str(source_player["normalized_name"]).split()

    def contains(shorter: List[str], longer: List[str]) -> bool:
        width = len(shorter)
        return bool(shorter) and any(
            longer[index : index + width] == shorter
            for index in range(len(longer) - width + 1)
        )

    for observation_name in _observation_name_keys(observation):
        observation_tokens = observation_name.split()
        if contains(source_tokens, observation_tokens) or contains(
            observation_tokens,
            source_tokens,
        ):
            return True
    return False


def _has_normalized_name_token_subset(
    observation: Dict[str, object],
    source_player: Dict[str, object],
) -> bool:
    source_tokens = str(source_player["normalized_name"]).split()
    for observation_name in _observation_name_keys(observation):
        observation_tokens = observation_name.split()
        if all(token in observation_tokens for token in source_tokens) or all(
            token in source_tokens for token in observation_tokens
        ):
            return True
    return False


def _name_match_kind(
    observation: Dict[str, object],
    source_player: Dict[str, object],
) -> Optional[str]:
    source_name = str(source_player["normalized_name"])
    observation_names = _observation_name_keys(observation)
    if source_name in observation_names:
        return "exact_name"
    for equivalent_names in VERIFIED_CAPOLOGY_NAME_EQUIVALENTS:
        if source_name in equivalent_names and observation_names & equivalent_names:
            return "verified_name_alias"
    return None


def _source_appearances_by_external_id(
    source_groups: Dict[Tuple[int, str], Dict[str, List[Dict[str, object]]]],
) -> Dict[str, List[Dict[str, object]]]:
    appearances: Dict[str, List[Dict[str, object]]] = defaultdict(list)
    for (competition_id, season_name), source_teams in source_groups.items():
        for team_slug, source_players in source_teams.items():
            for source_player in source_players:
                external_player_id = str(source_player["external_player_id"])
                canonical_player_id = _canonical_capology_player_id(
                    external_player_id
                )
                appearances[canonical_player_id].append(
                    {
                        "competition_id": competition_id,
                        "season_name": season_name,
                        "team_slug": team_slug,
                        "source_player": source_player,
                    }
                )
    return appearances


def _build_source_complete_matches(
    observations: List[Dict[str, object]],
    player_profiles: List[Dict[str, object]],
    source_groups: Dict[Tuple[int, str], Dict[str, List[Dict[str, object]]]],
    existing_by_player: Dict[int, str],
    existing_by_external_id: Dict[str, int],
    team_slugs_by_id: Dict[int, str],
) -> Tuple[List[Dict[str, object]], List[Dict[str, object]]]:
    observations_by_source_team: Dict[
        Tuple[int, str, str], List[Dict[str, object]]
    ] = defaultdict(list)
    for observation in observations:
        team_slug = team_slugs_by_id.get(int(observation["team_id"]))
        if team_slug is None:
            continue
        observations_by_source_team[
            (
                int(observation["competition_id"]),
                str(observation["season_name"]),
                team_slug,
            )
        ].append(observation)

    profiles_by_player_id = {
        int(profile["player_id"]): profile for profile in player_profiles
    }
    profiles_by_name: Dict[str, Dict[int, Dict[str, object]]] = defaultdict(dict)
    for profile in player_profiles:
        for name_key in _observation_name_keys(profile):
            profiles_by_name[name_key][int(profile["player_id"])] = profile

    team_ids_by_slug: Dict[str, Set[int]] = defaultdict(set)
    for team_id, team_slug in team_slugs_by_id.items():
        team_ids_by_slug[team_slug].add(team_id)

    appearances_by_external_id = _source_appearances_by_external_id(source_groups)
    provisional_matches: List[Dict[str, object]] = []
    unresolved: List[Dict[str, object]] = []

    for external_player_id, appearances in sorted(
        appearances_by_external_id.items()
    ):
        representative = appearances[0]["source_player"]
        existing_player_id = existing_by_external_id.get(external_player_id)
        if existing_player_id is not None:
            provisional_matches.append(
                {
                    "player_id": existing_player_id,
                    "capology_player_id": external_player_id,
                    "capology_player_name": representative["name"],
                    "method": "existing_mapping",
                    "evidence": [],
                    "appearances": appearances,
                }
            )
            continue

        verified_player_id = VERIFIED_CAPOLOGY_PLAYER_ID_OVERRIDES.get(
            external_player_id
        )
        if verified_player_id is not None:
            if verified_player_id not in profiles_by_player_id:
                unresolved.append(
                    {
                        "capology_player_id": external_player_id,
                        "capology_player_name": representative["name"],
                        "reason": "verified_player_not_loaded",
                        "candidate_player_ids": [],
                        "appearances": appearances,
                    }
                )
                continue
            provisional_matches.append(
                {
                    "player_id": verified_player_id,
                    "capology_player_id": external_player_id,
                    "capology_player_name": representative["name"],
                    "method": "verified_player_id_override",
                    "evidence": [],
                    "appearances": appearances,
                }
            )
            continue

        same_team_evidence: Dict[int, List[Dict[str, object]]] = defaultdict(list)
        for appearance in appearances:
            source_player = appearance["source_player"]
            team_observations = observations_by_source_team.get(
                (
                    int(appearance["competition_id"]),
                    str(appearance["season_name"]),
                    str(appearance["team_slug"]),
                ),
                [],
            )
            for observation in team_observations:
                match_kind = _name_match_kind(observation, source_player)
                if match_kind is None or _age_matches(
                    observation,
                    source_player,
                ) is not True:
                    continue
                same_team_evidence[int(observation["player_id"])].append(
                    {
                        "method": f"same_team_{match_kind}_age",
                        "competition_id": appearance["competition_id"],
                        "season_name": appearance["season_name"],
                        "team_slug": appearance["team_slug"],
                    }
                )

        if len(same_team_evidence) == 1:
            player_id = next(iter(same_team_evidence))
            provisional_matches.append(
                {
                    "player_id": player_id,
                    "capology_player_id": external_player_id,
                    "capology_player_name": representative["name"],
                    "method": same_team_evidence[player_id][0]["method"],
                    "evidence": same_team_evidence[player_id],
                    "appearances": appearances,
                }
            )
            continue
        if len(same_team_evidence) > 1:
            unresolved.append(
                {
                    "capology_player_id": external_player_id,
                    "capology_player_name": representative["name"],
                    "reason": "multiple_same_team_name_age_candidates",
                    "candidate_player_ids": sorted(same_team_evidence),
                    "appearances": appearances,
                }
            )
            continue

        phrase_evidence: Dict[int, List[Dict[str, object]]] = defaultdict(list)
        for appearance in appearances:
            source_player = appearance["source_player"]
            team_observations = observations_by_source_team.get(
                (
                    int(appearance["competition_id"]),
                    str(appearance["season_name"]),
                    str(appearance["team_slug"]),
                ),
                [],
            )
            for observation in team_observations:
                if not _contains_normalized_name_phrase(
                    observation,
                    source_player,
                ):
                    continue
                if not _has_complete_identity_support(
                    _identity_checks(observation, source_player)
                ):
                    continue
                phrase_evidence[int(observation["player_id"])].append(
                    {
                        "method": "same_team_name_phrase_complete_identity",
                        "competition_id": appearance["competition_id"],
                        "season_name": appearance["season_name"],
                        "team_slug": appearance["team_slug"],
                    }
                )

        if len(phrase_evidence) == 1:
            player_id = next(iter(phrase_evidence))
            provisional_matches.append(
                {
                    "player_id": player_id,
                    "capology_player_id": external_player_id,
                    "capology_player_name": representative["name"],
                    "method": "same_team_name_phrase_complete_identity",
                    "evidence": phrase_evidence[player_id],
                    "appearances": appearances,
                }
            )
            continue
        if len(phrase_evidence) > 1:
            unresolved.append(
                {
                    "capology_player_id": external_player_id,
                    "capology_player_name": representative["name"],
                    "reason": "multiple_same_team_name_phrase_candidates",
                    "candidate_player_ids": sorted(phrase_evidence),
                    "appearances": appearances,
                }
            )
            continue

        token_subset_evidence: Dict[
            int, List[Dict[str, object]]
        ] = defaultdict(list)
        for appearance in appearances:
            source_player = appearance["source_player"]
            team_observations = observations_by_source_team.get(
                (
                    int(appearance["competition_id"]),
                    str(appearance["season_name"]),
                    str(appearance["team_slug"]),
                ),
                [],
            )
            for observation in team_observations:
                if not _has_normalized_name_token_subset(
                    observation,
                    source_player,
                ):
                    continue
                if not _has_complete_identity_support(
                    _identity_checks(observation, source_player)
                ):
                    continue
                token_subset_evidence[int(observation["player_id"])].append(
                    {
                        "method": "same_team_name_token_subset_complete_identity",
                        "competition_id": appearance["competition_id"],
                        "season_name": appearance["season_name"],
                        "team_slug": appearance["team_slug"],
                    }
                )

        if len(token_subset_evidence) == 1:
            player_id = next(iter(token_subset_evidence))
            provisional_matches.append(
                {
                    "player_id": player_id,
                    "capology_player_id": external_player_id,
                    "capology_player_name": representative["name"],
                    "method": (
                        "same_team_name_token_subset_complete_identity"
                    ),
                    "evidence": token_subset_evidence[player_id],
                    "appearances": appearances,
                }
            )
            continue
        if len(token_subset_evidence) > 1:
            unresolved.append(
                {
                    "capology_player_id": external_player_id,
                    "capology_player_name": representative["name"],
                    "reason": "multiple_same_team_name_token_subset_candidates",
                    "candidate_player_ids": sorted(token_subset_evidence),
                    "appearances": appearances,
                }
            )
            continue

        global_evidence: Dict[int, List[Dict[str, object]]] = defaultdict(list)
        for appearance in appearances:
            source_player = appearance["source_player"]
            source_name = str(source_player["normalized_name"])
            candidate_profiles: Dict[int, Dict[str, object]] = dict(
                profiles_by_name.get(source_name, {})
            )
            for equivalent_names in VERIFIED_CAPOLOGY_NAME_EQUIVALENTS:
                if source_name not in equivalent_names:
                    continue
                for equivalent_name in equivalent_names:
                    candidate_profiles.update(
                        profiles_by_name.get(equivalent_name, {})
                    )
            for player_id, profile in candidate_profiles.items():
                source_team_ids = team_ids_by_slug.get(
                    str(appearance["team_slug"]),
                    set(),
                )
                if not source_team_ids & set(profile.get("team_ids", set())):
                    continue
                profile_for_season = {
                    **profile,
                    "season_name": appearance["season_name"],
                }
                if _age_matches(profile_for_season, source_player) is not True:
                    continue
                match_kind = _name_match_kind(profile, source_player)
                global_evidence[player_id].append(
                    {
                        "method": f"known_team_{match_kind}_age",
                        "competition_id": appearance["competition_id"],
                        "season_name": appearance["season_name"],
                        "team_slug": appearance["team_slug"],
                    }
                )

        if len(global_evidence) == 1:
            player_id = next(iter(global_evidence))
            provisional_matches.append(
                {
                    "player_id": player_id,
                    "capology_player_id": external_player_id,
                    "capology_player_name": representative["name"],
                    "method": global_evidence[player_id][0]["method"],
                    "evidence": global_evidence[player_id],
                    "appearances": appearances,
                }
            )
            continue

        unresolved.append(
            {
                "capology_player_id": external_player_id,
                "capology_player_name": representative["name"],
                "reason": (
                    "multiple_global_name_age_candidates"
                    if global_evidence
                    else "no_name_age_candidate"
                ),
                "candidate_player_ids": sorted(global_evidence),
                "appearances": appearances,
            }
        )

    matches = []
    for match in provisional_matches:
        if match["method"] == "existing_mapping":
            matches.append(match)
            continue
        player_id = int(match["player_id"])
        existing_external_player_id = existing_by_player.get(player_id)
        if existing_external_player_id is not None:
            unresolved.append(
                {
                    **match,
                    "reason": "db_player_already_has_capology_id",
                    "existing_capology_player_id": existing_external_player_id,
                }
            )
            continue
        matches.append(match)

    # DB 인덱스가 Understat 별칭을 허용해도 Capology의 기존 일대일 규칙은 유지해요.
    # 같은 실행에서 새 ID 두 개가 한 선수에 연결돼도 하나를 임의로 고르지 않고 중단해요.
    validate_external_id_uniqueness("Capology player", {
        **existing_by_external_id,
        **{m["capology_player_id"]: int(m["player_id"]) for m in matches},
    })
    return matches, unresolved


def _write_capology_player_ids_report(payload: Dict[str, object]) -> Path:
    CAPOLOGY_PLAYER_IDS_DIAGNOSTICS_DIRECTORY.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = (
        CAPOLOGY_PLAYER_IDS_DIAGNOSTICS_DIRECTORY
        / f"capology_player_ids_{stamp}.json"
    )
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, default=str),
        encoding="utf-8",
    )
    return path


def _insert_capology_player_ids(matches: List[Dict[str, object]]) -> int:
    rows = [
        (int(item["player_id"]), str(item["capology_player_id"]))
        for item in matches
    ]
    if not rows:
        return 0
    with transaction() as connection:
        with connection.cursor() as cursor:
            cursor.executemany(SQL_INSERT_CAPOLOGY_ID, rows)
    return len(rows)


def _collect_capology_player_ids(
    season_name: Optional[str] = None,
    competition_id: Optional[int] = None,
) -> Dict[str, object]:
    observations = _load_target_observations(season_name, competition_id)
    target_team_seasons = _load_target_team_seasons(
        season_name,
        competition_id,
    )
    player_profiles = _load_player_profiles()
    target_player_ids = {int(item["player_id"]) for item in observations}
    existing_rows = fetch_all(SQL_SELECT_EXISTING_CAPOLOGY_PLAYER_IDS)
    existing_by_player = {
        int(player_id): str(external_player_id)
        for player_id, external_player_id in existing_rows
    }
    existing_by_external_id = {
        external_player_id: player_id
        for player_id, external_player_id in existing_by_player.items()
    }
    team_slugs_by_id = {
        int(team_id): str(external_team_id)
        for team_id, external_team_id in fetch_all(
            SQL_SELECT_CAPOLOGY_TEAM_SLUGS
        )
    }

    session = _CapologyBrowserSession()
    try:
        (
            source_groups,
            source_failures,
            fetched_pages,
        ) = _collect_source_groups_from_saved_team_slugs(
            target_team_seasons,
            team_slugs_by_id,
            session,
        )
    finally:
        session.close()

    matches, unresolved = _build_source_complete_matches(
        observations,
        player_profiles,
        source_groups,
        existing_by_player,
        existing_by_external_id,
        team_slugs_by_id,
    )
    new_matches = [
        match
        for match in matches
        if match["method"] != "existing_mapping"
    ]
    ignored_without_loaded_db_match = [
        item
        for item in unresolved
        if item["reason"]
        in {"no_name_age_candidate", "verified_player_not_loaded"}
    ]
    blocking_unresolved = [
        item
        for item in unresolved
        if item["reason"]
        not in {"no_name_age_candidate", "verified_player_not_loaded"}
    ]
    source_appearances = _source_appearances_by_external_id(source_groups)
    existing_source_mappings = sum(
        1 for match in matches if match["method"] == "existing_mapping"
    )
    summary: Dict[str, object] = {
        "target_players": len(target_player_ids),
        "target_team_seasons": len(target_team_seasons),
        "unique_capology_players": len(source_appearances),
        "capology_player_appearances": sum(
            len(appearances) for appearances in source_appearances.values()
        ),
        "existing_capology_mappings": existing_source_mappings,
        "unmapped_players": len(source_appearances) - existing_source_mappings,
        "fetched_capology_pages": fetched_pages,
        "matched_teams": fetched_pages,
        "inserted_mappings": 0,
        "unmatched_players": len(ignored_without_loaded_db_match),
        "ignored_source_players_without_loaded_db_match": len(
            ignored_without_loaded_db_match
        ),
        "ambiguous_players": len(blocking_unresolved),
        "unresolved_capology_players": len(blocking_unresolved),
        "source_failures": len(source_failures),
    }

    if source_failures or blocking_unresolved:
        report_path = _write_capology_player_ids_report(
            {
                "scope": {
                    "season_name": season_name or "all",
                    "competition_id": competition_id,
                },
                "summary": summary,
                "matches": matches,
                "ignored_source_players_without_loaded_db_match": (
                    ignored_without_loaded_db_match
                ),
                "unresolved_capology_players": blocking_unresolved,
                "source_failures": source_failures,
            }
        )
        summary["report_path"] = str(report_path)
        raise RuntimeError(
            "Capology source coverage or matching is incomplete; "
            "no mappings were inserted. "
            f"source_failures={len(source_failures)} "
            f"unresolved={len(blocking_unresolved)} report={report_path}"
        )

    inserted_mappings = _insert_capology_player_ids(new_matches)
    summary["inserted_mappings"] = inserted_mappings
    report_path = _write_capology_player_ids_report(
        {
            "scope": {
                "season_name": season_name or "all",
                "competition_id": competition_id,
            },
            "summary": summary,
            "matches": matches,
            "ignored_source_players_without_loaded_db_match": (
                ignored_without_loaded_db_match
            ),
            "unresolved_capology_players": [],
            "source_failures": source_failures,
        }
    )
    summary["report_path"] = str(report_path)
    print(
        "[capology-player-ids] completed "
        f"targets={summary['target_players']} "
        f"existing={summary['existing_capology_mappings']} "
        f"inserted={summary['inserted_mappings']} "
        f"ignored={summary['ignored_source_players_without_loaded_db_match']} "
        "ambiguous=0 "
        f"source_failures={summary['source_failures']} "
        f"report={report_path}"
    )
    return summary


def collect_all_capology_player_ids() -> Dict[str, object]:
    return _collect_capology_player_ids()


def collect_capology_player_ids_for_competition_season(
    season_name: str,
    competition_id: int,
) -> Dict[str, object]:
    return _collect_capology_player_ids(
        season_name=season_name,
        competition_id=competition_id,
    )
