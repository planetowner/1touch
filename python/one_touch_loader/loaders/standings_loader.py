from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime
from typing import Dict, List, Optional, Tuple

from ..core.db import fetch_all, transaction


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
  league_id, season_id, phase, group_name, team_id, position,
  matches_played, won, draw, lost, goals_for, goals_against, goal_diff, points, last5_form
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  position=VALUES(position),
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

SQL_SELECT_LAST_FIXTURE_FOR_TEAM = """
SELECT starting_at
FROM fixtures
WHERE league_id = %s
  AND season_id = %s
  AND status = 'past'
  AND home_score IS NOT NULL
  AND away_score IS NOT NULL
  AND (home_team_id = %s OR away_team_id = %s)
ORDER BY starting_at DESC
LIMIT 1
"""

SQL_SELECT_LEAGUE_FIXTURES_ASOF = """
SELECT home_team_id, away_team_id, home_score, away_score
FROM fixtures
WHERE league_id = %s
  AND season_id = %s
  AND status = 'past'
  AND home_score IS NOT NULL
  AND away_score IS NOT NULL
  AND competition_type = 'league'
  AND round_name REGEXP '^[0-9]+$'
  AND starting_at {cmp} %s
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


def _rank_rows(rows: List[Dict]) -> List[Dict]:
    """정렬: pts desc, gd desc, gf desc, team_id asc."""
    rows.sort(key=lambda r: (-r["pts"], -r["gd"], -r["gf"], r["team_id"]))

    for position, row in enumerate(rows, start=1):
        row["pos"] = position

    return rows


def _aggregate_standings(
    fixtures: List[Tuple[int, int, int, int, Optional[datetime]]],
) -> Tuple[List[Dict], Dict[int, List[Tuple[int, int, int, int, Optional[datetime]]]]]:
    """
    fixtures: list of (home_team_id, away_team_id, home_score, away_score, starting_at)
    returns: (ranked_rows, latest_by_team)
    """
    latest_by_team: Dict[
        int, List[Tuple[int, int, int, int, Optional[datetime]]]
    ] = defaultdict(list)

    agg: Dict[int, Dict] = defaultdict(
        lambda: {
            "team_id": 0,
            "mp": 0,
            "w": 0,
            "d": 0,
            "l": 0,
            "gf": 0,
            "ga": 0,
            "gd": 0,
            "pts": 0,
        }
    )

    for home_id, away_id, home_score, away_score, dt in fixtures:
        latest_by_team[home_id].append(
            (home_id, away_id, home_score, away_score, dt)
        )
        latest_by_team[away_id].append(
            (home_id, away_id, home_score, away_score, dt)
        )

        for tid, gf, ga in (
            (home_id, home_score, away_score),
            (away_id, away_score, home_score),
        ):
            agg[tid]["team_id"] = tid
            agg[tid]["mp"] += 1
            agg[tid]["gf"] += gf
            agg[tid]["ga"] += ga

        if home_score > away_score:
            agg[home_id]["w"] += 1
            agg[home_id]["pts"] += 3
            agg[away_id]["l"] += 1
        elif home_score < away_score:
            agg[away_id]["w"] += 1
            agg[away_id]["pts"] += 3
            agg[home_id]["l"] += 1
        else:
            agg[home_id]["d"] += 1
            agg[home_id]["pts"] += 1
            agg[away_id]["d"] += 1
            agg[away_id]["pts"] += 1

    for row in agg.values():
        row["gd"] = row["gf"] - row["ga"]

    ranked = _rank_rows(list(agg.values()))

    return ranked, latest_by_team


def _standings_batch(
    *,
    league_id: int,
    season_id: int,
    phase: str,
    group_name: str,
    ranked: List[Dict],
    latest_by_team: Dict[int, List[Tuple]],
) -> List[Tuple]:
    batch: List[Tuple] = []

    for row in ranked:
        team_id = row["team_id"]
        last5 = _last5_for_team(latest_by_team[team_id], team_id)

        batch.append(
            (
                league_id,
                season_id,
                phase,
                group_name,
                team_id,
                row["pos"],
                row["mp"],
                row["w"],
                row["d"],
                row["l"],
                row["gf"],
                row["ga"],
                row["gd"],
                row["pts"],
                json.dumps(last5, ensure_ascii=False),
            )
        )

    return batch


# =========================================================
# 1) Big5 domestic league standings
# =========================================================

def build_league_standings_for_season(league_id: int, season_id: int) -> None:
    rows = fetch_all(SQL_SELECT_LEAGUE_FIXTURES, (league_id, season_id))

    fixtures: List[Tuple[int, int, int, int, datetime]] = []

    for h, a, hs, as_, dt in rows:
        fixtures.append(
            (
                _require_int(h, "fixtures.home_team_id"),
                _require_int(a, "fixtures.away_team_id"),
                _require_int(hs, "fixtures.home_score"),
                _require_int(as_, "fixtures.away_score"),
                _require_datetime(dt, "fixtures.starting_at"),
            )
        )

    ranked, latest_by_team = _aggregate_standings(fixtures)

    batch = _standings_batch(
        league_id=league_id,
        season_id=season_id,
        phase="league",
        group_name="",
        ranked=ranked,
        latest_by_team=latest_by_team,
    )

    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                SQL_DELETE_STANDINGS_FOR_LEAGUE_SEASON,
                (league_id, season_id),
            )

            if batch:
                cur.executemany(SQL_UPSERT_STANDINGS, batch)

    print(
        f"[standings] league {league_id} season {season_id}: "
        f"teams={len(batch)}"
    )


# =========================================================
# 2) European group / league-phase standings (stage_type_id=223)
# =========================================================

def build_euro_phase_standings_for_season_db(league_id: int, season_id: int) -> None:
    """
    fixtures + stage_groups로 그룹/리그페이즈 standings 계산.
      - group_id 가 있으면 phase='group' (group_name별로)
      - group_id 가 NULL이면 phase='league_phase'
    """
    rows = fetch_all(
        SQL_SELECT_EURO_GROUP_FIXTURES,
        (league_id, season_id, STAGE_TYPE_GROUP),
    )

    league_phase_games: List[Tuple[int, int, int, int, datetime]] = []
    by_group_name: Dict[str, List[Tuple[int, int, int, int, datetime]]] = defaultdict(list)

    for row in rows:
        home_id = _require_int(row[0], "fixtures.home_team_id")
        away_id = _require_int(row[1], "fixtures.away_team_id")
        home_score = _require_int(row[2], "fixtures.home_score")
        away_score = _require_int(row[3], "fixtures.away_score")
        starting_at = _require_datetime(row[4], "fixtures.starting_at")
        group_id = _require_optional_int(row[5], "fixtures.group_id")
        group_name_raw = row[6]

        tup = (home_id, away_id, home_score, away_score, starting_at)

        if group_id is None:
            league_phase_games.append(tup)
        else:
            group_name = _require_non_empty_str(
                group_name_raw,
                f"stage_groups.name for group_id={group_id}",
            )
            by_group_name[group_name].append(tup)

    all_batches: List[Tuple] = []

    for group_name, games in by_group_name.items():
        ranked, latest_by_team = _aggregate_standings(games)
        all_batches.extend(
            _standings_batch(
                league_id=league_id,
                season_id=season_id,
                phase="group",
                group_name=group_name,
                ranked=ranked,
                latest_by_team=latest_by_team,
            )
        )

    if league_phase_games:
        ranked, latest_by_team = _aggregate_standings(league_phase_games)
        all_batches.extend(
            _standings_batch(
                league_id=league_id,
                season_id=season_id,
                phase="league_phase",
                group_name="",
                ranked=ranked,
                latest_by_team=latest_by_team,
            )
        )

    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                SQL_DELETE_STANDINGS_FOR_LEAGUE_SEASON,
                (league_id, season_id),
            )

            if all_batches:
                cur.executemany(SQL_UPSERT_STANDINGS, all_batches)

    print(
        f"[standings] euro {league_id} season {season_id}: "
        f"groups={len(by_group_name)} league_phase_games={len(league_phase_games)}"
    )


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
    big5_seasons = fetch_all(
        SQL_SELECT_BIG5_SEASONS_FOR_BUILD,
        (MIN_SEASON_START_YEAR,),
    )

    for sid, lid in big5_seasons:
        build_league_standings_for_season(
            _require_int(lid, "seasons.league_id"),
            _require_int(sid, "seasons.season_id"),
        )

    euro_seasons = fetch_all(
        SQL_SELECT_EURO_SEASONS_FOR_BUILD,
        (MIN_SEASON_START_YEAR,),
    )

    for sid, lid in euro_seasons:
        build_euro_phase_standings_for_season_db(
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
    rows = fetch_all(SQL_SELECT_CURRENT_SEASONS_FOR_REFRESH)

    for sid, lid in rows:
        league_id = _require_int(lid, "seasons.league_id")
        season_id = _require_int(sid, "seasons.season_id")

        if league_id in BIG5_LEAGUE_IDS:
            build_league_standings_for_season(league_id, season_id)

        if league_id in EURO_LEAGUE_IDS:
            build_euro_phase_standings_for_season_db(league_id, season_id)

        if league_id in KNOCKOUT_BRACKET_LEAGUE_IDS:
            build_knockout_brackets_for_season(league_id, season_id)


# =========================================================
# 5) Rank delta vs previous match (BIG5 league only)
# =========================================================

def compute_rank_delta_since_last_match(
    team_id: int,
    league_id: int,
    season_id: int,
) -> Tuple[int, str]:
    """
    팀의 '직전 종료 경기' 전후 standings를 비교해 등락 산출.
    반환: (delta, symbol) 예) (+2, '▲'), (-1, '▼'), (0, '—')
    """
    rows = fetch_all(
        SQL_SELECT_LAST_FIXTURE_FOR_TEAM,
        (league_id, season_id, team_id, team_id),
    )

    if not rows:
        return (0, "—")

    last_starting_at = _require_datetime(rows[0][0], "fixtures.starting_at")

    before = _compute_position_asof(
        league_id, season_id, last_starting_at, include_cutoff=False,
    )
    after = _compute_position_asof(
        league_id, season_id, last_starting_at, include_cutoff=True,
    )

    pos_before = before.get(team_id)
    pos_after = after.get(team_id)

    if pos_before is None or pos_after is None:
        return (0, "—")

    delta = pos_before - pos_after  # 순위가 올라가면 양수

    if delta > 0:
        symbol = "▲"
    elif delta < 0:
        symbol = "▼"
    else:
        symbol = "—"

    return (delta, symbol)


def _compute_position_asof(
    league_id: int,
    season_id: int,
    cutoff: datetime,
    include_cutoff: bool,
) -> Dict[int, int]:
    comparator = "<=" if include_cutoff else "<"
    sql = SQL_SELECT_LEAGUE_FIXTURES_ASOF.replace("{cmp}", comparator)
    rows = fetch_all(sql, (league_id, season_id, cutoff))

    fixtures: List[Tuple[int, int, int, int, Optional[datetime]]] = []

    for h, a, hs, as_ in rows:
        fixtures.append(
            (
                _require_int(h, "fixtures.home_team_id"),
                _require_int(a, "fixtures.away_team_id"),
                _require_int(hs, "fixtures.home_score"),
                _require_int(as_, "fixtures.away_score"),
                None,
            )
        )

    ranked, _ = _aggregate_standings(fixtures)

    return {row["team_id"]: row["pos"] for row in ranked}
