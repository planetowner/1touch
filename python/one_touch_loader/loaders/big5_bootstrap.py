# python/one_touch_loader/loaders/big5_bootstrap.py
from __future__ import annotations

from collections import defaultdict
from datetime import datetime
from typing import DefaultDict, Dict, Iterable, List, Optional, Set, Tuple

from ..core.db import execute, upsert_many
from ..core.sportmonks import SportmonksClient


# =========================
# Upsert SQL
# =========================

SQL_UPSERT_LEAGUE = """
INSERT INTO leagues (league_id, name, image_path)
VALUES (%s, %s, %s)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  image_path = VALUES(image_path)
"""

SQL_UPSERT_SEASON = """
INSERT INTO seasons (season_id, league_id, name, is_current, starting_at, ending_at)
VALUES (%s, %s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  league_id = VALUES(league_id),
  name = VALUES(name),
  is_current = VALUES(is_current),
  starting_at = VALUES(starting_at),
  ending_at = VALUES(ending_at)
"""

SQL_UPSERT_TEAM = """
INSERT INTO teams (team_id, name, short_code, image_path)
VALUES (%s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  short_code = VALUES(short_code),
  image_path = VALUES(image_path)
"""

SQL_UPSERT_TEAM_SEASON = """
INSERT INTO team_seasons (team_id, season_id, league_id)
VALUES (%s, %s, %s)
ON DUPLICATE KEY UPDATE
  league_id = VALUES(league_id)
"""

SQL_UPSERT_FIXTURE = """
INSERT INTO fixtures (
  fixture_id, season_id, league_id,
  home_team_id, away_team_id,
  competition_type, round_name, stage_type_id, stage_id, group_id,
  leg_number, status, starting_at,
  home_score, away_score, home_penalty_score, away_penalty_score
)
VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  season_id          = VALUES(season_id),
  league_id          = VALUES(league_id),
  home_team_id       = VALUES(home_team_id),
  away_team_id       = VALUES(away_team_id),
  competition_type   = VALUES(competition_type),
  round_name         = VALUES(round_name),
  stage_type_id      = VALUES(stage_type_id),
  stage_id           = VALUES(stage_id),
  group_id           = VALUES(group_id),
  leg_number         = VALUES(leg_number),
  status             = VALUES(status),
  starting_at        = VALUES(starting_at),
  home_score         = VALUES(home_score),
  away_score         = VALUES(away_score),
  home_penalty_score = VALUES(home_penalty_score),
  away_penalty_score = VALUES(away_penalty_score)
"""

SQL_UPSERT_STAGE = """
INSERT INTO stages (stage_id, league_id, season_id, type_id, name)
VALUES (%s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  league_id=VALUES(league_id),
  season_id=VALUES(season_id),
  type_id=VALUES(type_id),
  name=VALUES(name)
"""

SQL_UPSERT_GROUP_META = """
INSERT INTO stage_groups (group_id, stage_id, league_id, season_id, name)
VALUES (%s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  stage_id=VALUES(stage_id),
  league_id=VALUES(league_id),
  season_id=VALUES(season_id),
  name=VALUES(name)
"""


# =========================
# Constants
# =========================

BIG5_NAME_TO_LEAGUE_ID = {
    "Premier League": 8,
    "Bundesliga": 82,
    "Ligue 1": 301,
    "Serie A": 384,
    "La Liga": 564,
}

BIG5_LEAGUE_IDS = [8, 82, 301, 384, 564]
EURO_LEAGUE_IDS = [2, 5, 2286]
DOMESTIC_CUP_LEAGUE_IDS = [24, 27, 390, 570]

MIN_SEASON_START_YEAR = 2017
MAX_SEASON_START_YEAR = 2025

SCORE_CURRENT_TYPE_ID = 1525
SCORE_PENALTY_SHOOTOUT_TYPE_ID = 5

STATE_TO_STATUS = {
    "FT": "past",
    "AET": "past",
    "FT_PEN": "past",
    "AWARDED": "past",
    "ABANDONED": "past",
    "POSTPONED": "upcoming",
    "CANCELLED": "past",
}

STATES_ALLOWING_EMPTY_SCORES = {
    "POSTPONED",
    "CANCELLED",
}

LEAGUE_SUB_TYPE_TO_COMPETITION = {
    "domestic": "league",
    "domestic_cup": "domestic_cup",
    "cup_international": "europe",
}


# =========================
# Caches
# =========================

class Caches:
    def __init__(self) -> None:
        self.league_meta: Dict[int, Dict] = {}
        self.league_to_seasons: DefaultDict[int, List[int]] = defaultdict(list)
        self.season_info: Dict[int, Dict] = {}


# =========================
# DB upsert helpers
# =========================

def upsert_leagues_rows(rows: List[Tuple[int, str, Optional[str]]]) -> None:
    if rows:
        upsert_many(SQL_UPSERT_LEAGUE, rows)


def upsert_teams_rows(rows: List[Tuple[int, str, Optional[str], Optional[str]]]) -> None:
    if rows:
        upsert_many(SQL_UPSERT_TEAM, rows)


def upsert_team_seasons_rows(rows: List[Tuple[int, int, int]]) -> None:
    if rows:
        upsert_many(SQL_UPSERT_TEAM_SEASON, rows)


def upsert_fixtures_rows(rows: List[Tuple]) -> None:
    if rows:
        upsert_many(SQL_UPSERT_FIXTURE, rows)


# =========================
# Strict payload helpers
# =========================

def _require_non_empty_str(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string field: {field_name}")
    return value.strip()


def _normalize_dt(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None

    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Invalid datetime value: {value!r}")

    dt = datetime.fromisoformat(value)
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def _season_start_year(season: Dict) -> int:
    starting_at = _require_non_empty_str(season["starting_at"], "season.starting_at")
    return int(starting_at[:4])


def _parse_leg_to_int(leg) -> int:
    # Verified across 24,958 fixtures + live Sportmonks payloads: leg is
    # always a string of the form "N/M" (e.g. "1/1", "1/2", "2/2"). The
    # current leg number is the part before the slash. No int / bare-digit
    # / NULL inputs occur, so we don't carry fallbacks for them.
    if not isinstance(leg, str) or "/" not in leg:
        raise ValueError(f"Unsupported fixture leg value: {leg!r}")

    first_part = leg.strip().split("/", 1)[0].strip()

    if not first_part.isdigit():
        raise ValueError(f"Unsupported fixture leg value: {leg!r}")

    return int(first_part)


def _map_state_to_status(state_code: str) -> str:
    if state_code not in STATE_TO_STATUS:
        raise ValueError(f"Unsupported fixture state: {state_code!r}")

    return STATE_TO_STATUS[state_code]


def _map_league_sub_type_to_competition(sub_type: str) -> str:
    if sub_type not in LEAGUE_SUB_TYPE_TO_COMPETITION:
        raise ValueError(f"Unsupported league sub_type: {sub_type!r}")

    return LEAGUE_SUB_TYPE_TO_COMPETITION[sub_type]


def _resolve_big5_league_ids(league_names: Optional[List[str]]) -> List[int]:
    if league_names is None:
        return BIG5_LEAGUE_IDS

    league_ids = []

    for name in league_names:
        if name not in BIG5_NAME_TO_LEAGUE_ID:
            raise ValueError(
                f"Unsupported Big5 league name: {name!r}. "
                f"Allowed names: {sorted(BIG5_NAME_TO_LEAGUE_ID)}"
            )

        league_ids.append(BIG5_NAME_TO_LEAGUE_ID[name])

    return league_ids


def _extract_home_away_ids(participants: List[Dict]) -> Tuple[int, int]:
    home_id = None
    away_id = None

    for participant in participants:
        participant_id = participant["id"]
        location = participant["meta"]["location"]

        if not isinstance(participant_id, int):
            raise ValueError(f"Invalid participant id: {participant_id!r}")

        if location == "home":
            if home_id is not None:
                raise ValueError("Duplicate home participant in fixture payload.")
            home_id = participant_id

        elif location == "away":
            if away_id is not None:
                raise ValueError("Duplicate away participant in fixture payload.")
            away_id = participant_id

        else:
            raise ValueError(f"Unsupported participant location: {location!r}")

    if home_id is None or away_id is None:
        raise ValueError("Fixture payload must contain exactly one home and one away participant.")

    return home_id, away_id


def _extract_current_scores(
    scores: List[Dict],
    state_code: str,
) -> Tuple[Optional[int], Optional[int]]:
    current_scores = [
        score
        for score in scores
        if score["description"] == "CURRENT"
        and score["type_id"] == SCORE_CURRENT_TYPE_ID
    ]

    if not current_scores:
        if state_code in STATES_ALLOWING_EMPTY_SCORES and not scores:
            return None, None

        raise ValueError(
            f"Expected 2 CURRENT score rows for state={state_code!r}, "
            f"found 0."
        )

    if len(current_scores) != 2:
        raise ValueError(
            f"Expected exactly 2 CURRENT score rows for state={state_code!r}, "
            f"found {len(current_scores)}."
        )

    home_score = None
    away_score = None

    for score in current_scores:
        side = score["score"]["participant"]
        goals = score["score"]["goals"]

        if not isinstance(goals, int):
            raise ValueError(f"Invalid CURRENT score goals value: {goals!r}")

        if side == "home":
            if home_score is not None:
                raise ValueError("Duplicate home CURRENT score row.")
            home_score = goals

        elif side == "away":
            if away_score is not None:
                raise ValueError("Duplicate away CURRENT score row.")
            away_score = goals

        else:
            raise ValueError(f"Unsupported CURRENT score participant side: {side!r}")

    if home_score is None or away_score is None:
        raise ValueError("CURRENT score rows must include both home and away.")

    return home_score, away_score


def _extract_penalty_shootout_scores(scores: List[Dict]) -> Tuple[Optional[int], Optional[int]]:
    penalty_scores = [
        score
        for score in scores
        if score["description"] == "PENALTY_SHOOTOUT"
        and score["type_id"] == SCORE_PENALTY_SHOOTOUT_TYPE_ID
    ]

    if not penalty_scores:
        return None, None

    if len(penalty_scores) != 2:
        raise ValueError(f"Expected exactly 2 PENALTY_SHOOTOUT score rows, found {len(penalty_scores)}.")

    home_penalty_score = None
    away_penalty_score = None

    for score in penalty_scores:
        side = score["score"]["participant"]
        goals = score["score"]["goals"]

        if not isinstance(goals, int):
            raise ValueError(f"Invalid PENALTY_SHOOTOUT goals value: {goals!r}")

        if side == "home":
            if home_penalty_score is not None:
                raise ValueError("Duplicate home PENALTY_SHOOTOUT score row.")
            home_penalty_score = goals

        elif side == "away":
            if away_penalty_score is not None:
                raise ValueError("Duplicate away PENALTY_SHOOTOUT score row.")
            away_penalty_score = goals

        else:
            raise ValueError(f"Unsupported PENALTY_SHOOTOUT participant side: {side!r}")

    if home_penalty_score is None or away_penalty_score is None:
        raise ValueError("PENALTY_SHOOTOUT score rows must include both home and away.")

    return home_penalty_score, away_penalty_score


def _round_name(fixture: Dict) -> str:
    round_obj = fixture["round"]

    if round_obj is not None:
        return _require_non_empty_str(round_obj["name"], "fixture.round.name")

    return _require_non_empty_str(fixture["stage"]["name"], "fixture.stage.name")


def _fixture_group_id(fixture: Dict) -> Optional[int]:
    group_obj = fixture["group"]

    if group_obj is None:
        return None

    group_id = group_obj["id"]

    if group_id != fixture["group_id"]:
        raise ValueError(
            f"Fixture group_id mismatch: "
            f"fixture.group_id={fixture['group_id']!r}, group.id={group_id!r}"
        )

    if group_obj["stage_id"] != fixture["stage_id"]:
        raise ValueError(
            f"Fixture group stage_id mismatch: "
            f"fixture.stage_id={fixture['stage_id']!r}, group.stage_id={group_obj['stage_id']!r}"
        )

    if group_obj["league_id"] != fixture["league_id"]:
        raise ValueError(
            f"Fixture group league_id mismatch: "
            f"fixture.league_id={fixture['league_id']!r}, group.league_id={group_obj['league_id']!r}"
        )

    if group_obj["season_id"] != fixture["season_id"]:
        raise ValueError(
            f"Fixture group season_id mismatch: "
            f"fixture.season_id={fixture['season_id']!r}, group.season_id={group_obj['season_id']!r}"
        )

    return group_id


def _group_row_from_fixture(fixture: Dict) -> Optional[Tuple[int, int, int, int, str]]:
    group_obj = fixture["group"]

    if group_obj is None:
        return None

    group_id = _fixture_group_id(fixture)
    group_name = _require_non_empty_str(group_obj["name"], "fixture.group.name")

    return (
        group_id,
        group_obj["stage_id"],
        group_obj["league_id"],
        group_obj["season_id"],
        group_name,
    )


def _stage_row_from_fixture(fixture: Dict, league_id: int, season_id: int) -> Tuple[int, int, int, int, str]:
    stage = fixture["stage"]

    stage_id = stage["id"]
    stage_type_id = stage["type_id"]
    stage_name = _require_non_empty_str(stage["name"], "fixture.stage.name")

    if not isinstance(stage_id, int):
        raise ValueError(f"Invalid stage id: {stage_id!r}")

    if not isinstance(stage_type_id, int):
        raise ValueError(f"Invalid stage type_id: {stage_type_id!r}")

    return stage_id, league_id, season_id, stage_type_id, stage_name


def _fixture_row(
    *,
    fixture: Dict,
    season_id: int,
    league_id: int,
    competition_type: str,
) -> Tuple:
    participants = fixture["participants"]
    scores = fixture["scores"]

    state_code = fixture["state"]["state"]
    status = _map_state_to_status(state_code)

    home_team_id, away_team_id = _extract_home_away_ids(participants)
    home_score, away_score = _extract_current_scores(scores, state_code)
    home_penalty_score, away_penalty_score = _extract_penalty_shootout_scores(scores)

    stage = fixture["stage"]
    group_id = _fixture_group_id(fixture)

    return (
        fixture["id"],
        season_id,
        league_id,
        home_team_id,
        away_team_id,
        competition_type,
        _round_name(fixture),
        stage["type_id"],
        stage["id"],
        group_id,
        _parse_leg_to_int(fixture["leg"]),
        status,
        _normalize_dt(fixture["starting_at"]),
        home_score,
        away_score,
        home_penalty_score,
        away_penalty_score,
    )


# =========================
# API helpers
# =========================

def ensure_leagues_by_ids(
    sm: SportmonksClient,
    league_ids: Iterable[int],
    caches: Caches,
) -> None:
    rows = []

    for league_id in league_ids:
        if league_id in caches.league_meta:
            continue

        league = sm.get_league(league_id)

        league_id_from_payload = league["id"]
        name = _require_non_empty_str(league["name"], "league.name")
        image_path = league["image_path"]
        sub_type = _require_non_empty_str(league["sub_type"], "league.sub_type")

        if league_id_from_payload != league_id:
            raise ValueError(
                f"Requested league_id={league_id}, "
                f"but Sportmonks returned id={league_id_from_payload}."
            )

        rows.append((league_id_from_payload, name, image_path))

        caches.league_meta[league_id_from_payload] = {
            "name": name,
            "image_path": image_path,
            "sub_type": sub_type,
        }

    upsert_leagues_rows(rows)
    print(f"[leagues] upserted: {len(rows)}")


def upsert_current_and_historical_seasons(
    sm: SportmonksClient,
    caches: Caches,
) -> None:
    rows = []
    total = 0

    for league_id in list(caches.league_meta.keys()):
        league = sm.get_league_with_seasons(league_id)
        seasons = league["seasons"]

        if not isinstance(seasons, list):
            raise ValueError(f"Expected league.seasons to be list for league_id={league_id}.")

        # Build this league's rows first so we can apply the offseason fallback
        # below: in the gap between seasons Sportmonks reports is_current=false
        # for every season, which leaves downstream `WHERE is_current = 1`
        # queries (injuries, transfers, standings, ...) with nothing to resolve.
        league_rows: List[List] = []
        any_current = False
        latest_idx: Optional[int] = None
        latest_start_year: Optional[int] = None

        for season in seasons:
            start_year = _season_start_year(season)

            if start_year < MIN_SEASON_START_YEAR or start_year > MAX_SEASON_START_YEAR:
                continue

            season_id = season["id"]
            is_current = bool(season["is_current"])
            any_current = any_current or is_current

            league_rows.append(
                [
                    season_id,
                    league_id,
                    season["name"],
                    is_current,
                    _normalize_dt(season["starting_at"]),
                    _normalize_dt(season["ending_at"]),
                ]
            )

            if latest_start_year is None or start_year > latest_start_year:
                latest_start_year = start_year
                latest_idx = len(league_rows) - 1

            caches.league_to_seasons[league_id].append(season_id)
            caches.season_info[season_id] = {
                "league_id": league_id,
                "name": season["name"],
                "start_year": start_year,
            }

            total += 1

        # Offseason fallback: no season flagged current by the API, so treat the
        # most-recent season as current until the new season opens.
        if not any_current and latest_idx is not None:
            league_rows[latest_idx][3] = True
            print(
                f"[seasons] league {league_id}: no current season from API; "
                f"flagged most-recent season_id={league_rows[latest_idx][0]} as current"
            )

        rows.extend(tuple(row) for row in league_rows)

    if rows:
        upsert_many(SQL_UPSERT_SEASON, rows)

    print(f"[seasons] upserted: {total}")


def upsert_teams_for_season(
    sm: SportmonksClient,
    league_id: int,
    season_id: int,
) -> None:
    rows: List[Tuple[int, str, Optional[str], Optional[str]]] = []
    membership: List[Tuple[int, int, int]] = []
    count = 0

    # teams/seasons/{season_id} is the authoritative roster for the season, so
    # we record team↔season membership (team_seasons) here too. This lets the
    # API resolve a team's current-season domestic league even before that
    # season's fixtures exist (e.g. at season rollover), without inferring the
    # league from the most recent fixture.
    for team in sm.iter_teams_by_season(season_id):
        team_id = team["id"]
        name = _require_non_empty_str(team["name"], "team.name")
        short_code = team["short_code"]
        image_path = team["image_path"]

        rows.append((team_id, name, short_code, image_path))
        membership.append((team_id, season_id, league_id))
        count += 1

        if len(rows) >= 500:
            upsert_teams_rows(rows)
            upsert_team_seasons_rows(membership)
            rows.clear()
            membership.clear()

    if rows:
        upsert_teams_rows(rows)
        upsert_team_seasons_rows(membership)

    print(f"[teams] league {league_id} season {season_id} upserted: {count}")


def ensure_teams_from_participants(participants: List[Dict]) -> None:
    rows: List[Tuple[int, str, Optional[str], Optional[str]]] = []
    seen: Set[int] = set()

    for participant in participants:
        team_id = participant["id"]

        if not isinstance(team_id, int):
            raise ValueError(f"Invalid participant team id: {team_id!r}")

        if team_id in seen:
            continue

        name = _require_non_empty_str(participant["name"], "participant.name")
        short_code = participant["short_code"]
        image_path = participant["image_path"]

        rows.append((team_id, name, short_code, image_path))
        seen.add(team_id)

        if len(rows) >= 500:
            upsert_teams_rows(rows)
            rows.clear()

    if rows:
        upsert_teams_rows(rows)


def classify_comp_by_league_id(
    league_id: int,
    caches: Caches,
    sm: SportmonksClient,
) -> str:
    if league_id not in caches.league_meta:
        ensure_leagues_by_ids(sm, [league_id], caches)

    sub_type = caches.league_meta[league_id]["sub_type"]
    return _map_league_sub_type_to_competition(sub_type)


# =========================
# Domestic leagues: BIG5
# =========================

def upsert_domestic_via_fixtures_api(
    sm: SportmonksClient,
    caches: Caches,
) -> None:
    rows: List[Tuple] = []
    total = 0

    for league_id, season_ids in caches.league_to_seasons.items():
        competition_type = classify_comp_by_league_id(league_id, caches, sm)

        if competition_type != "league":
            raise ValueError(
                f"Expected Big5 domestic league competition_type='league', "
                f"got {competition_type!r} for league_id={league_id}."
            )

        for season_id in sorted(set(season_ids)):
            for fixture in sm.iter_fixtures_by_season(season_id):
                participants = fixture["participants"]
                ensure_teams_from_participants(participants)

                rows.append(
                    _fixture_row(
                        fixture=fixture,
                        season_id=season_id,
                        league_id=league_id,
                        competition_type=competition_type,
                    )
                )

                total += 1

                if len(rows) >= 500:
                    upsert_fixtures_rows(rows)
                    rows.clear()

    if rows:
        upsert_fixtures_rows(rows)

    print(f"[fixtures] domestic via fixtures API: upserted {total}")


# =========================
# Europe: UCL / UEL / UECL
# =========================

def ingest_euro_all_seasons_full(
    sm: SportmonksClient,
    caches: Caches,
) -> None:
    season_upserts = 0
    stage_rows: List[Tuple[int, int, int, int, str]] = []
    group_rows: List[Tuple[int, int, int, int, str]] = []
    fix_rows: List[Tuple] = []
    total_fixtures = 0

    for league_id in EURO_LEAGUE_IDS:
        ensure_leagues_by_ids(sm, [league_id], caches)

        league = sm.get_league_with_seasons(league_id)
        seasons = league["seasons"]

        if not isinstance(seasons, list):
            raise ValueError(f"Expected league.seasons to be list for league_id={league_id}.")

        for season in seasons:
            start_year = _season_start_year(season)

            if start_year < MIN_SEASON_START_YEAR or start_year > MAX_SEASON_START_YEAR:
                continue

            season_id = season["id"]
            fixtures = list(sm.iter_fixtures_by_season(season_id))

            start_norm = _normalize_dt(season["starting_at"])
            end_norm = _normalize_dt(season["ending_at"])

            # Verified across all ingested leagues (Big5 + Euro + cups),
            # 104 seasons in 2017-2025: Sportmonks always returns non-null
            # starting_at/ending_at. No fixture-derived inference — a missing
            # date should surface as an error, not be guessed from fixtures.
            if start_norm is None or end_norm is None:
                raise ValueError(
                    f"season_id={season_id} is missing starting_at/ending_at."
                )

            upsert_many(
                SQL_UPSERT_SEASON,
                [
                    (
                        season_id,
                        league_id,
                        season["name"],
                        bool(season["is_current"]),
                        start_norm,
                        end_norm,
                    )
                ],
            )
            season_upserts += 1

            for fixture in fixtures:
                participants = fixture["participants"]
                ensure_teams_from_participants(participants)

                stage_rows.append(_stage_row_from_fixture(fixture, league_id, season_id))

                group_row = _group_row_from_fixture(fixture)
                if group_row is not None:
                    group_rows.append(group_row)

                fix_rows.append(
                    _fixture_row(
                        fixture=fixture,
                        season_id=season_id,
                        league_id=league_id,
                        competition_type="europe",
                    )
                )

                total_fixtures += 1

                if len(stage_rows) >= 500:
                    upsert_many(SQL_UPSERT_STAGE, stage_rows)
                    stage_rows.clear()

                if len(group_rows) >= 500:
                    upsert_many(SQL_UPSERT_GROUP_META, group_rows)
                    group_rows.clear()

                if len(fix_rows) >= 500:
                    upsert_fixtures_rows(fix_rows)
                    fix_rows.clear()

    if stage_rows:
        upsert_many(SQL_UPSERT_STAGE, stage_rows)

    if group_rows:
        upsert_many(SQL_UPSERT_GROUP_META, group_rows)

    if fix_rows:
        upsert_fixtures_rows(fix_rows)

    print(f"[seasons] euro all seasons upserted: {season_upserts}")
    print(f"[fixtures] euro all seasons (full): upserted {total_fixtures}")


# =========================
# Domestic Cups: BIG5 team-related only
# =========================

def upsert_domestic_cups_big5_only(
    sm: SportmonksClient,
    caches: Caches,
) -> None:
    year_to_big5_teams: Dict[int, Set[int]] = defaultdict(set)

    for season_id, info in caches.season_info.items():
        start_year = info["start_year"]

        for team in sm.iter_teams_by_season(season_id):
            team_id = team["id"]

            if not isinstance(team_id, int):
                raise ValueError(f"Invalid team id from season teams payload: {team_id!r}")

            year_to_big5_teams[start_year].add(team_id)

    stage_rows: List[Tuple[int, int, int, int, str]] = []
    group_rows: List[Tuple[int, int, int, int, str]] = []
    fix_rows: List[Tuple] = []
    total = 0

    for league_id in DOMESTIC_CUP_LEAGUE_IDS:
        ensure_leagues_by_ids(sm, [league_id], caches)

        league = sm.get_league_with_seasons(league_id)
        seasons = league["seasons"]

        if not isinstance(seasons, list):
            raise ValueError(f"Expected league.seasons to be list for league_id={league_id}.")

        for season in seasons:
            start_year = _season_start_year(season)

            if start_year < MIN_SEASON_START_YEAR or start_year > MAX_SEASON_START_YEAR:
                continue

            allowed_team_ids = year_to_big5_teams[start_year]

            if not allowed_team_ids:
                continue

            season_id = season["id"]
            fixtures = list(sm.iter_fixtures_by_season(season_id))

            start_norm = _normalize_dt(season["starting_at"])
            end_norm = _normalize_dt(season["ending_at"])

            # Verified across all ingested leagues (Big5 + Euro + cups),
            # 104 seasons in 2017-2025: Sportmonks always returns non-null
            # starting_at/ending_at. No fixture-derived inference — a missing
            # date should surface as an error, not be guessed from fixtures.
            if start_norm is None or end_norm is None:
                raise ValueError(
                    f"season_id={season_id} is missing starting_at/ending_at."
                )

            upsert_many(
                SQL_UPSERT_SEASON,
                [
                    (
                        season_id,
                        league_id,
                        season["name"],
                        bool(season["is_current"]),
                        start_norm,
                        end_norm,
                    )
                ],
            )

            for fixture in fixtures:
                participants = fixture["participants"]
                participant_ids = {participant["id"] for participant in participants}

                if not participant_ids & allowed_team_ids:
                    continue

                ensure_teams_from_participants(participants)

                stage_rows.append(_stage_row_from_fixture(fixture, league_id, season_id))

                group_row = _group_row_from_fixture(fixture)
                if group_row is not None:
                    group_rows.append(group_row)

                fix_rows.append(
                    _fixture_row(
                        fixture=fixture,
                        season_id=season_id,
                        league_id=league_id,
                        competition_type="domestic_cup",
                    )
                )

                total += 1

                if len(stage_rows) >= 500:
                    upsert_many(SQL_UPSERT_STAGE, stage_rows)
                    stage_rows.clear()

                if len(group_rows) >= 500:
                    upsert_many(SQL_UPSERT_GROUP_META, group_rows)
                    group_rows.clear()

                if len(fix_rows) >= 500:
                    upsert_fixtures_rows(fix_rows)
                    fix_rows.clear()

    if stage_rows:
        upsert_many(SQL_UPSERT_STAGE, stage_rows)

    if group_rows:
        upsert_many(SQL_UPSERT_GROUP_META, group_rows)

    if fix_rows:
        upsert_fixtures_rows(fix_rows)

    print(f"[fixtures] domestic cups (big5-related, all seasons): upserted {total}")


# =========================
# Knockout winner backfill
# =========================

def finalize_knockout_winners() -> int:
    sql_pen_leg2 = """
    UPDATE knockout_ties kt
    JOIN fixtures f2 ON f2.fixture_id = kt.leg2_fixture_id
    SET kt.winner_team_id = CASE
      WHEN f2.home_penalty_score > f2.away_penalty_score THEN f2.home_team_id
      WHEN f2.home_penalty_score < f2.away_penalty_score THEN f2.away_team_id
      ELSE kt.winner_team_id
    END,
        kt.updated_at = NOW()
    WHERE kt.winner_team_id IS NULL
      AND kt.aggregate_team1 = kt.aggregate_team2
      AND kt.leg2_fixture_id IS NOT NULL
      AND f2.home_penalty_score IS NOT NULL
      AND f2.away_penalty_score IS NOT NULL;
    """

    sql_pen_single = """
    UPDATE knockout_ties kt
    JOIN fixtures f1 ON f1.fixture_id = kt.leg1_fixture_id
    LEFT JOIN fixtures f2 ON f2.fixture_id = kt.leg2_fixture_id
    SET kt.winner_team_id = CASE
      WHEN f1.home_penalty_score > f1.away_penalty_score THEN f1.home_team_id
      WHEN f1.home_penalty_score < f1.away_penalty_score THEN f1.away_team_id
      ELSE kt.winner_team_id
    END,
        kt.updated_at = NOW()
    WHERE kt.winner_team_id IS NULL
      AND kt.aggregate_team1 = kt.aggregate_team2
      AND kt.leg2_fixture_id IS NULL
      AND f1.home_penalty_score IS NOT NULL
      AND f1.away_penalty_score IS NOT NULL;
    """

    sql_away_goals = """
    UPDATE knockout_ties kt
    JOIN seasons s           ON s.season_id = kt.season_id
    JOIN fixtures l1         ON l1.fixture_id = kt.leg1_fixture_id
    JOIN fixtures l2         ON l2.fixture_id = kt.leg2_fixture_id
    SET kt.winner_team_id = CASE
      WHEN
        (CASE
           WHEN l1.away_team_id = kt.team1_id THEN l1.away_score
           WHEN l2.away_team_id = kt.team1_id THEN l2.away_score
           ELSE 0
         END)
        >
        (CASE
           WHEN l1.away_team_id = kt.team2_id THEN l1.away_score
           WHEN l2.away_team_id = kt.team2_id THEN l2.away_score
           ELSE 0
         END)
      THEN kt.team1_id

      WHEN
        (CASE
           WHEN l1.away_team_id = kt.team1_id THEN l1.away_score
           WHEN l2.away_team_id = kt.team1_id THEN l2.away_score
           ELSE 0
         END)
        <
        (CASE
           WHEN l1.away_team_id = kt.team2_id THEN l1.away_score
           WHEN l2.away_team_id = kt.team2_id THEN l2.away_score
           ELSE 0
         END)
      THEN kt.team2_id

      ELSE kt.winner_team_id
    END,
        kt.updated_at = NOW()
    WHERE kt.winner_team_id IS NULL
      AND kt.aggregate_team1 = kt.aggregate_team2
      AND kt.leg1_fixture_id IS NOT NULL
      AND kt.leg2_fixture_id IS NOT NULL
      AND kt.league_id IN (2,5)
      AND YEAR(s.starting_at) <= 2020;
    """

    updated = 0
    updated += execute(sql_pen_leg2)
    updated += execute(sql_pen_single)
    updated += execute(sql_away_goals)

    return updated


# =========================
# Entry point
# =========================

def run_big5_bootstrap(league_names: Optional[List[str]] = None) -> None:
    sm = SportmonksClient()
    caches = Caches()

    big5_league_ids = _resolve_big5_league_ids(league_names)

    # 1) BIG5 league meta
    ensure_leagues_by_ids(sm, big5_league_ids, caches)

    # 2) BIG5 seasons
    upsert_current_and_historical_seasons(sm, caches)

    # 3) BIG5 teams (+ team_seasons membership)
    for league_id, season_ids in caches.league_to_seasons.items():
        for season_id in sorted(set(season_ids)):
            upsert_teams_for_season(sm, league_id, season_id)

    # 4) BIG5 league fixtures
    upsert_domestic_via_fixtures_api(sm, caches)

    # 5) European competitions
    ingest_euro_all_seasons_full(sm, caches)

    # 6) Domestic cups involving BIG5 teams
    upsert_domestic_cups_big5_only(sm, caches)

    print("Big5 bootstrap done.")

    updated = finalize_knockout_winners()
    print(f"[knockout_winners] backfilled: {updated}")