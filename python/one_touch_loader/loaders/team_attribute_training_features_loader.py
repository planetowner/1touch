from __future__ import annotations

from one_touch_loader.core.db import fetch_all, upsert_many


TARGET_SEASON_IDS = [
    17420, 18378, 19734, 21646, 23614,
    17361, 18444, 19744, 21795, 23744,
    17160, 18441, 19745, 21779, 23643,
    17488, 18576, 19806, 21818, 23746,
    17480, 18462, 19799, 21694, 23621,
]


UPSERT_SQL = """
INSERT INTO team_attribute_training_features (
  league_id,
  season_id,
  team_id,

  matches_played,
  points,
  points_per_match,

  ball_possession_avg,
  ball_safe_per_match,
  passes_per_match,
  pass_accuracy,

  dangerous_attacks_per_match,
  total_crosses_per_match,
  cross_accuracy,
  dribble_attempts_per_match,
  dribble_success_rate,

  corners_per_match,
  key_passes_per_match,
  big_chances_created_per_match,

  shots_insidebox_per_match,
  conversion_rate,
  shots_on_target_per_match,
  shot_accuracy,

  goals_against_per_match,
  shots_on_target_against_per_match,
  shots_insidebox_against_per_match,
  big_chances_against_per_match,
  dangerous_attacks_against_per_match
)
VALUES (
  %s, %s, %s,
  %s, %s, %s,
  %s, %s, %s, %s,
  %s, %s, %s, %s, %s,
  %s, %s, %s,
  %s, %s, %s, %s,
  %s, %s, %s, %s, %s
)
ON DUPLICATE KEY UPDATE
  matches_played = VALUES(matches_played),
  points = VALUES(points),
  points_per_match = VALUES(points_per_match),

  ball_possession_avg = VALUES(ball_possession_avg),
  ball_safe_per_match = VALUES(ball_safe_per_match),
  passes_per_match = VALUES(passes_per_match),
  pass_accuracy = VALUES(pass_accuracy),

  dangerous_attacks_per_match = VALUES(dangerous_attacks_per_match),
  total_crosses_per_match = VALUES(total_crosses_per_match),
  cross_accuracy = VALUES(cross_accuracy),
  dribble_attempts_per_match = VALUES(dribble_attempts_per_match),
  dribble_success_rate = VALUES(dribble_success_rate),

  corners_per_match = VALUES(corners_per_match),
  key_passes_per_match = VALUES(key_passes_per_match),
  big_chances_created_per_match = VALUES(big_chances_created_per_match),

  shots_insidebox_per_match = VALUES(shots_insidebox_per_match),
  conversion_rate = VALUES(conversion_rate),
  shots_on_target_per_match = VALUES(shots_on_target_per_match),
  shot_accuracy = VALUES(shot_accuracy),

  goals_against_per_match = VALUES(goals_against_per_match),
  shots_on_target_against_per_match = VALUES(shots_on_target_against_per_match),
  shots_insidebox_against_per_match = VALUES(shots_insidebox_against_per_match),
  big_chances_against_per_match = VALUES(big_chances_against_per_match),
  dangerous_attacks_against_per_match = VALUES(dangerous_attacks_against_per_match)
"""


def _target_seasons_cte(season_ids: list[int]) -> str:
    return " UNION ALL ".join(["SELECT %s AS season_id"] * len(season_ids))


def build_team_attribute_training_features_for_seasons(
    season_ids: list[int] | None = None,
) -> int:
    season_ids = season_ids or TARGET_SEASON_IDS
    target_seasons_cte = _target_seasons_cte(season_ids)

    sql = f"""
    WITH target_seasons AS (
      {target_seasons_cte}
    ),

    own_stat_pivot AS (
      SELECT
        r.league_id,
        r.season_id,
        r.team_id,

        AVG(CASE WHEN r.stat_code = 'ball-possession' THEN r.stat_value_num END) AS ball_possession_avg,

        SUM(CASE WHEN r.stat_code = 'ball-safe' THEN r.stat_value_num ELSE 0 END) AS ball_safe_sum,
        SUM(CASE WHEN r.stat_code = 'passes' THEN r.stat_value_num ELSE 0 END) AS passes_sum,
        SUM(CASE WHEN r.stat_code = 'successful-passes' THEN r.stat_value_num ELSE 0 END) AS successful_passes_sum,

        SUM(CASE WHEN r.stat_code = 'dangerous-attacks' THEN r.stat_value_num ELSE 0 END) AS dangerous_attacks_sum,
        SUM(CASE WHEN r.stat_code = 'total-crosses' THEN r.stat_value_num ELSE 0 END) AS total_crosses_sum,
        SUM(CASE WHEN r.stat_code = 'accurate-crosses' THEN r.stat_value_num ELSE 0 END) AS accurate_crosses_sum,
        SUM(CASE WHEN r.stat_code = 'dribble-attempts' THEN r.stat_value_num ELSE 0 END) AS dribble_attempts_sum,
        SUM(CASE WHEN r.stat_code = 'successful-dribbles' THEN r.stat_value_num ELSE 0 END) AS successful_dribbles_sum,

        SUM(CASE WHEN r.stat_code = 'corners' THEN r.stat_value_num ELSE 0 END) AS corners_sum,
        SUM(CASE WHEN r.stat_code = 'key-passes' THEN r.stat_value_num ELSE 0 END) AS key_passes_sum,
        SUM(CASE WHEN r.stat_code = 'big-chances-created' THEN r.stat_value_num ELSE 0 END) AS big_chances_created_sum,

        SUM(CASE WHEN r.stat_code = 'shots-insidebox' THEN r.stat_value_num ELSE 0 END) AS shots_insidebox_sum,
        SUM(CASE WHEN r.stat_code = 'goals' THEN r.stat_value_num ELSE 0 END) AS goals_sum,
        SUM(CASE WHEN r.stat_code = 'shots-total' THEN r.stat_value_num ELSE 0 END) AS shots_total_sum,
        SUM(CASE WHEN r.stat_code = 'shots-on-target' THEN r.stat_value_num ELSE 0 END) AS shots_on_target_sum

      FROM fixture_team_stats_raw r
      INNER JOIN fixtures f
        ON f.fixture_id = r.fixture_id
       AND f.league_id = r.league_id
       AND f.season_id = r.season_id
      WHERE r.season_id IN (SELECT season_id FROM target_seasons)
        AND f.status = 'past'
        AND COALESCE(f.round_name, '') REGEXP '^[0-9]+$'
      GROUP BY
        r.league_id,
        r.season_id,
        r.team_id
    ),

    against_stat_pivot AS (
      SELECT
        r.league_id,
        r.season_id,
        r.opponent_team_id AS team_id,

        SUM(CASE WHEN r.stat_code = 'goals' THEN r.stat_value_num ELSE 0 END) AS goals_against_sum,
        SUM(CASE WHEN r.stat_code = 'shots-on-target' THEN r.stat_value_num ELSE 0 END) AS shots_on_target_against_sum,
        SUM(CASE WHEN r.stat_code = 'shots-insidebox' THEN r.stat_value_num ELSE 0 END) AS shots_insidebox_against_sum,
        SUM(CASE WHEN r.stat_code = 'big-chances-created' THEN r.stat_value_num ELSE 0 END) AS big_chances_against_sum,
        SUM(CASE WHEN r.stat_code = 'dangerous-attacks' THEN r.stat_value_num ELSE 0 END) AS dangerous_attacks_against_sum

      FROM fixture_team_stats_raw r
      INNER JOIN fixtures f
        ON f.fixture_id = r.fixture_id
       AND f.league_id = r.league_id
       AND f.season_id = r.season_id
      WHERE r.season_id IN (SELECT season_id FROM target_seasons)
        AND r.opponent_team_id IS NOT NULL
        AND f.status = 'past'
        AND COALESCE(f.round_name, '') REGEXP '^[0-9]+$'
      GROUP BY
        r.league_id,
        r.season_id,
        r.opponent_team_id
    )

    SELECT
      s.league_id,
      s.season_id,
      s.team_id,

      s.matches_played,
      s.points,
      s.points / NULLIF(s.matches_played, 0) AS points_per_match,

      own.ball_possession_avg,
      own.ball_safe_sum / NULLIF(s.matches_played, 0) AS ball_safe_per_match,
      own.passes_sum / NULLIF(s.matches_played, 0) AS passes_per_match,
      own.successful_passes_sum / NULLIF(own.passes_sum, 0) AS pass_accuracy,

      own.dangerous_attacks_sum / NULLIF(s.matches_played, 0) AS dangerous_attacks_per_match,
      own.total_crosses_sum / NULLIF(s.matches_played, 0) AS total_crosses_per_match,
      own.accurate_crosses_sum / NULLIF(own.total_crosses_sum, 0) AS cross_accuracy,
      own.dribble_attempts_sum / NULLIF(s.matches_played, 0) AS dribble_attempts_per_match,
      own.successful_dribbles_sum / NULLIF(own.dribble_attempts_sum, 0) AS dribble_success_rate,

      own.corners_sum / NULLIF(s.matches_played, 0) AS corners_per_match,
      own.key_passes_sum / NULLIF(s.matches_played, 0) AS key_passes_per_match,
      own.big_chances_created_sum / NULLIF(s.matches_played, 0) AS big_chances_created_per_match,

      own.shots_insidebox_sum / NULLIF(s.matches_played, 0) AS shots_insidebox_per_match,
      own.goals_sum / NULLIF(own.shots_total_sum, 0) AS conversion_rate,
      own.shots_on_target_sum / NULLIF(s.matches_played, 0) AS shots_on_target_per_match,
      own.shots_on_target_sum / NULLIF(own.shots_total_sum, 0) AS shot_accuracy,

      against_stats.goals_against_sum / NULLIF(s.matches_played, 0) AS goals_against_per_match,
      against_stats.shots_on_target_against_sum / NULLIF(s.matches_played, 0) AS shots_on_target_against_per_match,
      against_stats.shots_insidebox_against_sum / NULLIF(s.matches_played, 0) AS shots_insidebox_against_per_match,
      against_stats.big_chances_against_sum / NULLIF(s.matches_played, 0) AS big_chances_against_per_match,
      against_stats.dangerous_attacks_against_sum / NULLIF(s.matches_played, 0) AS dangerous_attacks_against_per_match

    FROM standings s
    INNER JOIN own_stat_pivot own
      ON own.league_id = s.league_id
     AND own.season_id = s.season_id
     AND own.team_id = s.team_id
    INNER JOIN against_stat_pivot against_stats
      ON against_stats.league_id = s.league_id
     AND against_stats.season_id = s.season_id
     AND against_stats.team_id = s.team_id
    WHERE s.phase = 'league'
      AND s.season_id IN (SELECT season_id FROM target_seasons)
    ORDER BY
      s.league_id,
      s.season_id,
      s.team_id
    """

    rows = fetch_all(sql, tuple(season_ids))
    upsert_many(UPSERT_SQL, rows)

    print(f"[team-attributes] training features upserted: rows={len(rows)}")
    return len(rows)

BIG5_LEAGUE_IDS = [8, 82, 301, 384, 564]


def get_current_big5_season_ids() -> list[int]:
    rows = fetch_all(
        """
        SELECT season_id
        FROM seasons
        WHERE is_current = 1
          AND league_id IN (8, 82, 301, 384, 564)
        ORDER BY league_id, season_id
        """
    )

    return [int(row[0]) for row in rows]


def build_current_team_attribute_training_features() -> int:
    season_ids = get_current_big5_season_ids()

    if not season_ids:
        raise RuntimeError("No current Big 5 seasons found in seasons table.")

    return build_team_attribute_training_features_for_seasons(season_ids)