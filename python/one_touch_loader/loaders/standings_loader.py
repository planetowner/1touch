from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime
from typing import Dict, List, Optional, Tuple

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient


# =========================================================
# Constants
# =========================================================

BIG5_LEAGUE_IDS: Tuple[int, ...] = (8, 82, 301, 384, 564)
EURO_LEAGUE_IDS: Tuple[int, ...] = (2, 5, 2286)
DOMESTIC_CUP_LEAGUE_IDS: Tuple[int, ...] = (24, 27, 390, 570)
KNOCKOUT_BRACKET_LEAGUE_IDS: Tuple[int, ...] = EURO_LEAGUE_IDS + DOMESTIC_CUP_LEAGUE_IDS

STAGE_TYPE_GROUP = 223  # group-stage / league-phase
STAGE_TYPE_KNOCKOUT = 224

# UEFA away-goals rule: applied through 2020/2021 season, abolished from 2021/22.
UEFA_AWAY_GOALS_LAST_SEASON_YEAR = 2020

MIN_SEASON_START_YEAR = 2017

# Canonical names for stage_type_id=224 (knockout) round_name values.
# Built from a full DB scan of all knockout fixtures across
# UCL/UEL/UECL/FA Cup/EFL Cup/Coupe de France/Copa del Rey.
# Unknown values raise — when a new round_name appears in future data,
# this mapping must be updated explicitly rather than silently passed through.
KNOCKOUT_ROUND_CANONICAL: Dict[str, str] = {
    "Final": "Final",
    "Semi-finals": "Semi-finals",
    "Quarter-finals": "Quarter-finals",
    # EFL Cup historical typo (no hyphen)
    "Quarterfinals": "Quarter-finals",
    # "Round of 16" and "8th Finals" = same step (8 remaining ties = 16 teams)
    "Round of 16": "Round of 16",
    "8th Finals": "Round of 16",
    # "Round of 32" and "16th Finals" = same step
    "Round of 32": "Round of 32",
    "16th Finals": "Round of 32",
    # Domestic cup rounds 1-5 (equivalent representations)
    "1st Round": "Round 1",
    "Round 1": "Round 1",
    "2nd Round": "Round 2",
    "Round 2": "Round 2",
    "3rd Round": "Round 3",
    "Round 3": "Round 3",
    "4th Round": "Round 4",
    "Round 4": "Round 4",
    # EFL Cup 2025/26 introduced bare-digit round_name "4"
    "4": "Round 4",
    "5th Round": "Round 5",
    # FA Cup replays kept as separate rounds (one-off re-matches after draws)
    "3rd Round Replays": "Round 3 Replay",
    "4th Round Replays": "Round 4 Replay",
    "5th Round Replays": "Round 5 Replay",
    # UEFA 2024/25+ league-phase 9-16 vs 1-8 decider before R16
    "Knockout Round Play-offs": "Knockout Round Play-offs",
    # UECL main-draw entry decider (different from above)
    "Play-offs": "Play-offs",
    # Qualifiers
    "Preliminary Round": "Preliminary Round",
    "1st Qualifying Round": "1st Qualifying Round",
    "2nd Qualifying Round": "2nd Qualifying Round",
    "3rd Qualifying Round": "3rd Qualifying Round",
}


# =========================================================
# SQL
# =========================================================

SQL_UPSERT_STANDINGS = """
INSERT INTO standings (
  league_id, season_id, phase, group_name, team_id, position, prev_position,
  matches_played, won, draw, lost, goals_for, goals_against, goal_diff, points, last5_form
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  position=VALUES(position),
  prev_position=VALUES(prev_position),
  matches_played=VALUES(matches_played),
  won=VALUES(won), draw=VALUES(draw), lost=VALUES(lost),
  goals_for=VALUES(goals_for), goals_against=VALUES(goals_against),
  goal_diff=VALUES(goal_diff), points=VALUES(points),
  last5_form=VALUES(last5_form)
"""

SQL_UPSERT_TIE = """
INSERT INTO knockout_ties (
  league_id, season_id, round_name, team1_id, team2_id,
  leg1_fixture_id, leg1_home_team_id, leg1_away_team_id, leg1_home_score, leg1_away_score,
  leg2_fixture_id, leg2_home_team_id, leg2_away_team_id, leg2_home_score, leg2_away_score,
  aggregate_team1, aggregate_team2, winner_team_id
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  leg1_fixture_id = VALUES(leg1_fixture_id),
  leg1_home_team_id = VALUES(leg1_home_team_id),
  leg1_away_team_id = VALUES(leg1_away_team_id),
  leg1_home_score = VALUES(leg1_home_score),
  leg1_away_score = VALUES(leg1_away_score),
  leg2_fixture_id = VALUES(leg2_fixture_id),
  leg2_home_team_id = VALUES(leg2_home_team_id),
  leg2_away_team_id = VALUES(leg2_away_team_id),
  leg2_home_score = VALUES(leg2_home_score),
  leg2_away_score = VALUES(leg2_away_score),
  aggregate_team1 = VALUES(aggregate_team1),
  aggregate_team2 = VALUES(aggregate_team2),
  winner_team_id = IFNULL(winner_team_id, VALUES(winner_team_id))
"""

SQL_SELECT_LEAGUE_FIXTURES = """
SELECT home_team_id, away_team_id, home_score, away_score, starting_at
FROM fixtures
WHERE league_id = %s
  AND season_id = %s
  AND status = 'past'
  AND home_score IS NOT NULL
  AND away_score IS NOT NULL
  AND competition_type = 'league'
  AND round_name REGEXP '^[0-9]+$'
ORDER BY starting_at DESC
"""

SQL_SELECT_EURO_GROUP_FIXTURES = """
SELECT
  f.home_team_id, f.away_team_id,
  f.home_score, f.away_score, f.starting_at,
  f.group_id, g.name AS group_name
FROM fixtures f
LEFT JOIN stage_groups g ON g.group_id = f.group_id
WHERE f.league_id = %s
  AND f.season_id = %s
  AND f.status = 'past'
  AND f.home_score IS NOT NULL
  AND f.away_score IS NOT NULL
  AND f.stage_type_id = %s
ORDER BY f.starting_at ASC
"""

SQL_SELECT_KNOCKOUT_FIXTURES = """
SELECT
  fixture_id, home_team_id, away_team_id,
  home_score, away_score,
  home_penalty_score, away_penalty_score,
  round_name, leg_number, starting_at
FROM fixtures
WHERE league_id = %s
  AND season_id = %s
  AND status = 'past'
  AND home_score IS NOT NULL
  AND away_score IS NOT NULL
  AND stage_type_id = %s
ORDER BY starting_at, leg_number, fixture_id
"""

SQL_SELECT_SEASON_START_YEAR = """
SELECT YEAR(starting_at)
FROM seasons
WHERE season_id = %s
"""

SQL_SELECT_BIG5_SEASONS_FOR_BUILD = """
SELECT season_id, league_id
FROM seasons
WHERE league_id IN (8,82,301,384,564)
  AND YEAR(starting_at) >= %s
ORDER BY league_id, starting_at
"""

SQL_SELECT_EURO_SEASONS_FOR_BUILD = """
SELECT season_id, league_id
FROM seasons
WHERE league_id IN (2,5,2286)
  AND YEAR(starting_at) >= %s
ORDER BY league_id, starting_at
"""

SQL_SELECT_KNOCKOUT_SEASONS_FOR_BUILD = """
SELECT season_id, league_id
FROM seasons
WHERE league_id IN (2,5,2286, 24,27,390,570)
  AND YEAR(starting_at) >= %s
ORDER BY league_id, starting_at
"""

SQL_SELECT_CURRENT_SEASONS_FOR_REFRESH = """
SELECT season_id, league_id
FROM seasons
WHERE is_current = 1
  AND league_id IN (8,82,301,384,564, 2,5,2286, 24,27,390,570)
"""

SQL_SELECT_TEAM_LEAGUE_STANDING = """
SELECT position, prev_position
FROM standings
WHERE league_id = %s
  AND season_id = %s
  AND phase = 'league'
  AND group_name = ''
  AND team_id = %s
"""

SQL_DELETE_STANDINGS_FOR_LEAGUE_SEASON = """
DELETE FROM standings
WHERE league_id = %s
  AND season_id = %s
"""


# =========================================================
# Strict helpers
# =========================================================

def _require_int(value, field_name: str) -> int:
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer field: {field_name}={value!r}")

    return value


def _require_optional_int(value, field_name: str) -> Optional[int]:
    if value is None:
        return None

    if type(value) is not int:
        raise ValueError(f"Invalid optional integer field: {field_name}={value!r}")

    return value


def _require_non_empty_str(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string field: {field_name}={value!r}")

    return value.strip()


def _require_datetime(value, field_name: str) -> datetime:
    if not isinstance(value, datetime):
        raise ValueError(f"Missing or invalid datetime field: {field_name}={value!r}")

    return value


def _normalize_knockout_round_name(name: str) -> str:
    if name not in KNOCKOUT_ROUND_CANONICAL:
        raise ValueError(
            f"Unknown knockout round_name {name!r}. "
            f"Update KNOCKOUT_ROUND_CANONICAL with the correct mapping."
        )

    return KNOCKOUT_ROUND_CANONICAL[name]


# =========================================================
# Standings aggregation primitives
# =========================================================

def _result_for_team(
    home_id: int,
    home_score: int,
    away_score: int,
    team_id: int,
) -> str:
    if team_id == home_id:
        if home_score > away_score:
            return "W"

        if home_score < away_score:
            return "L"

        return "D"

    if away_score > home_score:
        return "W"

    if away_score < home_score:
        return "L"

    return "D"


def _last5_for_team(
    fixtures: List[Tuple[int, int, int, int, datetime]],
    team_id: int,
) -> List[str]:
    """Return the team's results for its 5 most recent matches, ordered past → most recent.

    Sorts internally by starting_at, so the caller does not need to maintain
    any particular SQL ORDER BY direction.
    """
    sorted_oldest_first = sorted(fixtures, key=lambda f: f[4])
    recent5 = sorted_oldest_first[-5:]

    return [_result_for_team(h, hs, as_, team_id) for h, _a, hs, as_, _ in recent5]


def _last5_by_team(
    fixtures: List[Tuple[int, int, int, int, datetime]],
) -> Dict[int, List[str]]:
    """{team_id: 최근 5경기 결과}. fixture 집계는 공식 순위가 아니라 last5_form 같은
    앱 전용 보조 정보를 만드는 데에만 쓴다."""
    by_team: Dict[int, List[Tuple[int, int, int, int, datetime]]] = defaultdict(list)

    for fx in fixtures:
        by_team[fx[0]].append(fx)
        by_team[fx[1]].append(fx)

    return {team_id: _last5_for_team(games, team_id) for team_id, games in by_team.items()}


# =========================================================
# Official standings from the Sportmonks standings API
# =========================================================
#
# Official league/group order comes from Sportmonks' standings `position`, not
# from re-aggregating fixtures. Self-ranking by points→GD→GF→team_id cannot
# reflect per-league tiebreakers (head-to-head etc.) and would force-split ties
# by team_id, diverging from the official table. team_id is only used to
# stabilise output order of equal positions on the read side, never to decide
# the position value.

_DETAIL_MATCHES_PLAYED = "overall-matches-played"
_DETAIL_WON = "overall-won"
_DETAIL_DRAW = "overall-draw"
_DETAIL_LOST = "overall-lost"
_DETAIL_GOALS_FOR = "overall-goals-for"
_DETAIL_GOALS_AGAINST = "overall-goals-against"
_DETAIL_GOAL_DIFFERENCE = "goal-difference"


def _detail_value(details: List[Dict], code: str, context: str) -> int:
    found: Optional[int] = None

    for detail in details:
        type_obj = detail.get("type") or {}
        if type_obj.get("code") == code:
            if found is not None:
                raise ValueError(f"{context}: duplicate standing detail code {code!r}")
            found = _require_int(detail["value"], f"{context}.{code}")

    if found is None:
        raise ValueError(f"{context}: missing standing detail code {code!r}")

    return found


def _parse_standing_row(row: Dict, context: str) -> Dict:
    details = row["details"]
    if not isinstance(details, list):
        raise ValueError(
            f"{context}: standing details must be a list, got {type(details).__name__}"
        )

    group_id = _require_optional_int(row["group_id"], f"{context}.group_id")
    if group_id is None:
        group_name = ""
    else:
        group_obj = row["group"]
        if not isinstance(group_obj, dict):
            raise ValueError(f"{context}: group_id={group_id} but group object missing")
        group_name = _require_non_empty_str(group_obj["name"], f"{context}.group.name")

    return {
        "team_id": _require_int(row["participant_id"], f"{context}.participant_id"),
        "position": _require_int(row["position"], f"{context}.position"),
        "points": _require_int(row["points"], f"{context}.points"),
        "mp": _detail_value(details, _DETAIL_MATCHES_PLAYED, context),
        "w": _detail_value(details, _DETAIL_WON, context),
        "d": _detail_value(details, _DETAIL_DRAW, context),
        "l": _detail_value(details, _DETAIL_LOST, context),
        "gf": _detail_value(details, _DETAIL_GOALS_FOR, context),
        "ga": _detail_value(details, _DETAIL_GOALS_AGAINST, context),
        "gd": _detail_value(details, _DETAIL_GOAL_DIFFERENCE, context),
        "group_id": group_id,
        "group_name": group_name,
    }


def _parse_official_standings(api_rows: List[Dict], context: str) -> List[Dict]:
    if not api_rows:
        raise ValueError(f"{context}: empty standings response")

    parsed: List[Dict] = []
    seen: set = set()

    for row in api_rows:
        parsed_row = _parse_standing_row(row, context)
        team_id = parsed_row["team_id"]
        if team_id in seen:
            raise ValueError(f"{context}: duplicate participant_id={team_id}")
        seen.add(team_id)
        parsed.append(parsed_row)

    return parsed


def _prev_round_position_map(sm: SportmonksClient, season_id: int) -> Dict[int, int]:
    """{team_id: 직전 완료 라운드 기준 공식 position}.

    완료된 라운드가 2개 미만이면(=직전 라운드 없음) 빈 dict. Big5 리그 rank delta
    산출에만 쓴다. 라운드 순서는 name(매치데이 숫자) 기준.
    """
    rounds = sm.get_rounds_for_season(season_id)
    finished = [r for r in rounds if r["finished"]]
    finished.sort(key=lambda r: int(_require_non_empty_str(r["name"], "round.name")))

    if len(finished) < 2:
        return {}

    prev_round_id = _require_int(finished[-2]["id"], "round.id")
    context = f"standings/round {prev_round_id}"

    out: Dict[int, int] = {}
    for row in sm.get_standings_for_round(prev_round_id):
        team_id = _require_int(row["participant_id"], f"{context}.participant_id")
        position = _require_int(row["position"], f"{context}.position")
        if team_id in out:
            raise ValueError(f"{context}: duplicate participant_id={team_id}")
        out[team_id] = position

    return out


def _store_standings_for_league_season(
    league_id: int,
    season_id: int,
    batch: List[Tuple],
) -> None:
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                SQL_DELETE_STANDINGS_FOR_LEAGUE_SEASON,
                (league_id, season_id),
            )

            if batch:
                cur.executemany(SQL_UPSERT_STANDINGS, batch)


# =========================================================
# 1) Big5 domestic league standings
# =========================================================

def _load_league_fixtures(
    league_id: int,
    season_id: int,
) -> List[Tuple[int, int, int, int, datetime]]:
    out: List[Tuple[int, int, int, int, datetime]] = []
    for h, a, hs, as_, dt in fetch_all(SQL_SELECT_LEAGUE_FIXTURES, (league_id, season_id)):
        out.append(
            (
                _require_int(h, "fixtures.home_team_id"),
                _require_int(a, "fixtures.away_team_id"),
                _require_int(hs, "fixtures.home_score"),
                _require_int(as_, "fixtures.away_score"),
                _require_datetime(dt, "fixtures.starting_at"),
            )
        )
    return out


def build_league_standings_for_season(
    sm: SportmonksClient,
    league_id: int,
    season_id: int,
) -> None:
    context = f"league {league_id} season {season_id}"

    # Official order comes from Sportmonks standings `position`.
    parsed = _parse_official_standings(
        sm.get_standings_for_season(season_id),
        context,
    )

    # last5_form: app-only extra from fixtures, merged onto the official rows.
    last5_map = _last5_by_team(_load_league_fixtures(league_id, season_id))

    # Rank delta: official position now vs official position at the previous
    # completed round (Big5 league only).
    prev_map = _prev_round_position_map(sm, season_id)

    batch: List[Tuple] = []
    for p in parsed:
        if p["group_id"] is not None:
            raise ValueError(
                f"{context}: unexpected group_id={p['group_id']} on a domestic league standing"
            )

        team_id = p["team_id"]
        if prev_map and team_id not in prev_map:
            raise ValueError(
                f"{context}: team {team_id} is in the current standings but missing "
                f"from the previous-round standings"
            )

        batch.append(
            (
                league_id,
                season_id,
                "league",
                "",
                team_id,
                p["position"],
                prev_map.get(team_id),
                p["mp"],
                p["w"],
                p["d"],
                p["l"],
                p["gf"],
                p["ga"],
                p["gd"],
                p["points"],
                json.dumps(last5_map.get(team_id, []), ensure_ascii=False),
            )
        )

    _store_standings_for_league_season(league_id, season_id, batch)

    print(f"[standings] {context}: teams={len(batch)}")


# =========================================================
# 2) European group / league-phase standings (stage_type_id=223)
# =========================================================

def _load_euro_fixtures(
    league_id: int,
    season_id: int,
) -> List[Tuple[int, int, int, int, datetime]]:
    out: List[Tuple[int, int, int, int, datetime]] = []
    for row in fetch_all(SQL_SELECT_EURO_GROUP_FIXTURES, (league_id, season_id, STAGE_TYPE_GROUP)):
        out.append(
            (
                _require_int(row[0], "fixtures.home_team_id"),
                _require_int(row[1], "fixtures.away_team_id"),
                _require_int(row[2], "fixtures.home_score"),
                _require_int(row[3], "fixtures.away_score"),
                _require_datetime(row[4], "fixtures.starting_at"),
            )
        )
    return out


def build_euro_phase_standings_for_season_db(
    sm: SportmonksClient,
    league_id: int,
    season_id: int,
) -> None:
    """
    유로 대회 group / league-phase 공식 standings.
      - group_id 가 있으면 phase='group' (group_name별로)
      - group_id 가 NULL이면 phase='league_phase'
    순위는 Sportmonks standings `position`을 그대로 쓰고, last5_form만 fixtures로
    보강한다. rank delta(prev_position)는 Big5 리그 전용이라 여기선 NULL.
    """
    context = f"euro {league_id} season {season_id}"

    parsed = _parse_official_standings(
        sm.get_standings_for_season(season_id),
        context,
    )

    # A team plays in exactly one group / the league-phase, so per-team last5
    # over all euro fixtures is the team's own recent form.
    last5_map = _last5_by_team(_load_euro_fixtures(league_id, season_id))

    batch: List[Tuple] = []
    for p in parsed:
        if p["group_id"] is None:
            phase = "league_phase"
            group_name = ""
        else:
            phase = "group"
            group_name = p["group_name"]

        team_id = p["team_id"]
        batch.append(
            (
                league_id,
                season_id,
                phase,
                group_name,
                team_id,
                p["position"],
                None,
                p["mp"],
                p["w"],
                p["d"],
                p["l"],
                p["gf"],
                p["ga"],
                p["gd"],
                p["points"],
                json.dumps(last5_map.get(team_id, []), ensure_ascii=False),
            )
        )

    _store_standings_for_league_season(league_id, season_id, batch)

    groups = {p["group_name"] for p in parsed if p["group_id"] is not None}
    print(f"[standings] {context}: rows={len(batch)} groups={len(groups)}")


# =========================================================
# 3) Knockout brackets (Euro + domestic cups)
# =========================================================

def _ordered_pair(team_a: int, team_b: int) -> Tuple[int, int]:
    return (team_a, team_b) if team_a < team_b else (team_b, team_a)


def _leg_parts(
    game: Optional[Tuple[int, int, int, int, int, Optional[int], Optional[int], int, datetime]],
) -> Tuple[Optional[int], Optional[int], Optional[int], Optional[int], Optional[int]]:
    """game이 None이면 (None,)*5. 아니면 (fixture_id, home, away, home_score, away_score)."""
    if game is None:
        return (None, None, None, None, None)

    fixture_id, home_id, away_id, home_score, away_score, _, _, _, _ = game
    return (fixture_id, home_id, away_id, home_score, away_score)


def _season_start_year(season_id: int) -> int:
    rows = fetch_all(SQL_SELECT_SEASON_START_YEAR, (season_id,))
    return _require_int(rows[0][0], "YEAR(seasons.starting_at)")


def build_knockout_brackets_for_season(league_id: int, season_id: int) -> None:
    """
    stage_type_id=224 fixtures를 tie 단위로 정규화하여 knockout_ties에 저장.

    승자 결정 우선순위:
      1) 합계 다득점
      2) (UEFA 2020/21까지) 원정 다득점
      3) 승부차기 스코어 (마지막 승부차기 경기 기준)
    """
    season_start_year = _season_start_year(season_id)

    apply_away_goals_rule = (
        league_id in EURO_LEAGUE_IDS
        and season_start_year <= UEFA_AWAY_GOALS_LAST_SEASON_YEAR
    )

    rows = fetch_all(
        SQL_SELECT_KNOCKOUT_FIXTURES,
        (league_id, season_id, STAGE_TYPE_KNOCKOUT),
    )

    grouped: Dict[
        Tuple[str, int, int],
        List[Tuple[int, int, int, int, int, Optional[int], Optional[int], int, datetime]],
    ] = defaultdict(list)

    for row in rows:
        fixture_id = _require_int(row[0], "fixtures.fixture_id")
        home_team_id = _require_int(row[1], "fixtures.home_team_id")
        away_team_id = _require_int(row[2], "fixtures.away_team_id")
        home_score = _require_int(row[3], "fixtures.home_score")
        away_score = _require_int(row[4], "fixtures.away_score")
        home_penalty = _require_optional_int(row[5], "fixtures.home_penalty_score")
        away_penalty = _require_optional_int(row[6], "fixtures.away_penalty_score")
        round_name_raw = _require_non_empty_str(row[7], "fixtures.round_name")
        leg_number = _require_int(row[8], "fixtures.leg_number")
        starting_at = _require_datetime(row[9], "fixtures.starting_at")

        canonical_round = _normalize_knockout_round_name(round_name_raw)
        team1_id, team2_id = _ordered_pair(home_team_id, away_team_id)

        grouped[(canonical_round, team1_id, team2_id)].append(
            (
                fixture_id,
                home_team_id,
                away_team_id,
                home_score,
                away_score,
                home_penalty,
                away_penalty,
                leg_number,
                starting_at,
            )
        )

    batch: List[Tuple] = []

    for (round_name, team1_id, team2_id), games in grouped.items():
        games.sort(key=lambda g: (g[8], g[7], g[0]))

        aggregate_team1 = 0
        aggregate_team2 = 0
        away_goals_team1 = 0
        away_goals_team2 = 0
        last_penalty_game: Optional[Tuple[int, int, int, int]] = None

        for fxid, h, a, hs, as_, p_h, p_a, _leg, _dt in games:
            team1_is_home = (h == team1_id)
            team1_goals = hs if team1_is_home else as_
            team2_goals = as_ if team1_is_home else hs

            aggregate_team1 += team1_goals
            aggregate_team2 += team2_goals

            if apply_away_goals_rule:
                if team1_is_home:
                    away_goals_team2 += team2_goals
                else:
                    away_goals_team1 += team1_goals

            if p_h is not None:
                last_penalty_game = (h, a, p_h, p_a)

        winner_team_id: Optional[int] = None

        if aggregate_team1 != aggregate_team2:
            winner_team_id = team1_id if aggregate_team1 > aggregate_team2 else team2_id
        elif apply_away_goals_rule and away_goals_team1 != away_goals_team2:
            winner_team_id = team1_id if away_goals_team1 > away_goals_team2 else team2_id
        elif last_penalty_game is not None:
            penalty_home_team, _, penalty_home_score, penalty_away_score = last_penalty_game

            if penalty_home_team == team1_id:
                team1_penalty = penalty_home_score
                team2_penalty = penalty_away_score
            else:
                team1_penalty = penalty_away_score
                team2_penalty = penalty_home_score

            if team1_penalty != team2_penalty:
                winner_team_id = team1_id if team1_penalty > team2_penalty else team2_id

        leg1 = games[0]
        leg2 = games[-1] if len(games) > 1 else None

        fx1, h1, a1, hs1, as1 = _leg_parts(leg1)
        fx2, h2, a2, hs2, as2 = _leg_parts(leg2)

        batch.append(
            (
                league_id,
                season_id,
                round_name,
                team1_id,
                team2_id,
                fx1, h1, a1, hs1, as1,
                fx2, h2, a2, hs2, as2,
                aggregate_team1,
                aggregate_team2,
                winner_team_id,
            )
        )

    if batch:
        with transaction() as conn:
            with conn.cursor() as cur:
                cur.executemany(SQL_UPSERT_TIE, batch)

    print(
        f"[knockout] league {league_id} season {season_id}: "
        f"ties={len(batch)}"
    )


# =========================================================
# 4) Entry points: full build / current-season refresh
# =========================================================

def build_all_standings() -> None:
    sm = SportmonksClient()

    big5_seasons = fetch_all(
        SQL_SELECT_BIG5_SEASONS_FOR_BUILD,
        (MIN_SEASON_START_YEAR,),
    )

    for sid, lid in big5_seasons:
        build_league_standings_for_season(
            sm,
            _require_int(lid, "seasons.league_id"),
            _require_int(sid, "seasons.season_id"),
        )

    euro_seasons = fetch_all(
        SQL_SELECT_EURO_SEASONS_FOR_BUILD,
        (MIN_SEASON_START_YEAR,),
    )

    for sid, lid in euro_seasons:
        build_euro_phase_standings_for_season_db(
            sm,
            _require_int(lid, "seasons.league_id"),
            _require_int(sid, "seasons.season_id"),
        )

    knockout_seasons = fetch_all(
        SQL_SELECT_KNOCKOUT_SEASONS_FOR_BUILD,
        (MIN_SEASON_START_YEAR,),
    )

    for sid, lid in knockout_seasons:
        build_knockout_brackets_for_season(
            _require_int(lid, "seasons.league_id"),
            _require_int(sid, "seasons.season_id"),
        )


def refresh_current_standings() -> None:
    sm = SportmonksClient()
    rows = fetch_all(SQL_SELECT_CURRENT_SEASONS_FOR_REFRESH)

    for sid, lid in rows:
        league_id = _require_int(lid, "seasons.league_id")
        season_id = _require_int(sid, "seasons.season_id")

        if league_id in BIG5_LEAGUE_IDS:
            build_league_standings_for_season(sm, league_id, season_id)

        if league_id in EURO_LEAGUE_IDS:
            build_euro_phase_standings_for_season_db(sm, league_id, season_id)

        if league_id in KNOCKOUT_BRACKET_LEAGUE_IDS:
            build_knockout_brackets_for_season(league_id, season_id)


# =========================================================
# 5) Rank delta vs previous round (BIG5 league only)
# =========================================================

def compute_rank_delta_since_last_match(
    team_id: int,
    league_id: int,
    season_id: int,
) -> Tuple[int, str]:
    """
    저장된 공식 standings의 position vs prev_position(직전 완료 라운드 기준 공식
    순위)로 등락 산출. 반환: (delta, symbol) 예) (+2, '▲'), (-1, '▼'), (0, '—').
    공식 순위를 fixture로 재계산하지 않는다.
    """
    rows = fetch_all(
        SQL_SELECT_TEAM_LEAGUE_STANDING,
        (league_id, season_id, team_id),
    )

    if not rows:
        return (0, "—")

    position = _require_int(rows[0][0], "standings.position")
    prev_position = _require_optional_int(rows[0][1], "standings.prev_position")

    if prev_position is None:
        return (0, "—")

    delta = prev_position - position  # 순위가 올라가면 양수

    if delta > 0:
        symbol = "▲"
    elif delta < 0:
        symbol = "▼"
    else:
        symbol = "—"

    return (delta, symbol)
