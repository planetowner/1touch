from __future__ import annotations

import pandas as pd

from one_touch_loader.core.db import fetch_all, upsert_many
from one_touch_loader.core.fixture_states import COMPLETED_STATE_IDS
from one_touch_loader.loaders.team_attribute_common import ALL_FEATURES, FEATURE_STAT_SPECS


# 완료된 21/22~25/26 시즌만 사용하고, 특성 집계와 회귀 학습이 같은 목록을 공유해요.
TARGET_SEASON_IDS = [
    18378, 19734, 21646, 23614, 25583,
    18444, 19744, 21795, 23744, 25646,
    18441, 19745, 21779, 23643, 25651,
    18576, 19806, 21818, 23746, 25533,
    18462, 19799, 21694, 23621, 25659,
]


UPSERT_SQL = """
INSERT INTO team_attribute_features (
  season_id,
  team_id,

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
  %s, %s, %s, %s,
  %s, %s, %s, %s, %s,
  %s, %s, %s,
  %s, %s, %s, %s,
  %s, %s, %s, %s, %s
)
ON DUPLICATE KEY UPDATE
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


def _build_feature_query(season_ids: list[int]) -> str:
    """영역별로 같은 경기 범위의 평균·비율을 집계하는 읽기 쿼리를 만들어요."""
    stat_codes = sorted({
        code
        for specs in FEATURE_STAT_SPECS.values()
        for codes in specs.values()
        for code in codes
    })
    # PK와 통계 코드의 UNIQUE 제약으로 한 경기·팀·통계는 값이 하나예요.
    pivot_columns = ",\n        ".join(
        f"MAX(CASE WHEN stat_type.code = '{code}' THEN r.stat_value END) "
        f"AS {code.replace('-', '_')}"
        for code in stat_codes
    )
    group_ctes = []
    feature_columns = []
    joins = []
    for group, specs in FEATURE_STAT_SPECS.items():
        required_stats = sorted({code.replace("-", "_") for codes in specs.values() for code in codes})
        available = " AND ".join(f"{column} IS NOT NULL" for column in required_stats)
        team_column = "opponent_team_id" if group == "defending" else "team_id"
        aggregates = []
        for feature, codes in specs.items():
            numerator = codes[0].replace("-", "_")
            if len(codes) == 1:
                expression = f"AVG({numerator})"
            else:
                denominator = codes[1].replace("-", "_")
                expression = f"SUM({numerator}) / NULLIF(SUM({denominator}), 0)"
            aggregates.append(f"{expression} AS {feature}")
            feature_columns.append(f"{group}.{feature}")
        group_ctes.append(f"""
    {group} AS (
      SELECT competition_id, season_id, {team_column} AS team_id,
        {', '.join(aggregates)}
      FROM fixture_stat_pivot
      WHERE {available}
      GROUP BY competition_id, season_id, {team_column}
    )""")
        joins.append(f"""
    LEFT JOIN {group}
      ON {group}.competition_id = s.competition_id
     AND {group}.season_id = s.season_id
     AND {group}.team_id = s.team_id""")

    return f"""
    WITH target_seasons AS (
      {_target_seasons_cte(season_ids)}
    ),
    -- 제공된 0은 그대로 두고, 통계 행이 없으면 NULL로 남겨요.
    fixture_stat_pivot AS (
      SELECT
        fixture_season.competition_id,
        fixture_stage.season_id,
        f.fixture_id,
        r.team_id,
        CASE WHEN r.team_id = f.home_team_id
             THEN f.away_team_id ELSE f.home_team_id END AS opponent_team_id,
        {pivot_columns}
      FROM fixture_team_stats r
      JOIN fixture_stat_types stat_type ON stat_type.stat_type_id = r.stat_type_id
      JOIN fixtures f ON f.fixture_id = r.fixture_id
      JOIN stages fixture_stage ON fixture_stage.stage_id = f.stage_id
      JOIN seasons fixture_season ON fixture_season.season_id = fixture_stage.season_id
      JOIN rounds fixture_round ON fixture_round.round_id = f.round_id
      WHERE fixture_stage.season_id IN (SELECT season_id FROM target_seasons)
        AND f.state_id IN ({','.join(str(value) for value in COMPLETED_STATE_IDS)})
        AND fixture_round.name REGEXP '^[0-9]+$'
      GROUP BY fixture_season.competition_id, fixture_stage.season_id,
               f.fixture_id, r.team_id, f.home_team_id, f.away_team_id
    ),
    -- 영역별 필수 통계가 모두 있는 경기만 평균과 비율의 분자·분모에 함께 써요.
    -- 예를 들어 수비 자료가 38경기 중 30경기에 있으면 수비의 모든 항목은 그 30경기로 계산해요.
    {', '.join(group_ctes)},
    standing_rows AS (
      SELECT
        season.competition_id,
        standing.season_id,
        standing.team_id,
        standing.won + standing.draw + standing.lost AS matches_played,
        standing.points
      FROM standings standing
      JOIN seasons season ON season.season_id = standing.season_id
      WHERE standing.season_id IN (SELECT season_id FROM target_seasons)
    )
    SELECT
      s.season_id, s.team_id,
      s.points / NULLIF(s.matches_played, 0) AS points_per_match,
      {', '.join(feature_columns)}
    FROM standing_rows s
    {''.join(joins)}
    ORDER BY s.competition_id, s.season_id, s.team_id
    """


def build_team_attribute_training_features_for_seasons(
    season_ids: list[int] | None = None,
) -> int:
    # 학습 목표인 시즌 경기당 승점은 유지하고, 통계의 평균 분모만 실제 제공 경기 수로 맞춰요.
    # 선수 합계나 경기 점수를 통계의 대체값으로 사용하지 않아요.
    # 별도 최소 경기 수·제공률 기준은 두지 않고, 필수 통계가 함께 있는 경기를 사용해요.
    # 필수 항목의 공통 제공 경기가 없거나 비율의 분모가 0이면 NULL로 저장해 해당 영역을 미산출해요.
    season_ids = season_ids or TARGET_SEASON_IDS
    rows = fetch_all(_build_feature_query(season_ids), tuple(season_ids))
    upsert_many(UPSERT_SQL, rows)

    print(f"[team-attributes] training features upserted: rows={len(rows)}")
    return len(rows)


def fetch_team_attribute_feature_dataframe(
    season_ids: list[int] | None = None, *, include_target: bool = False,
) -> pd.DataFrame:
    # 학습과 점수 계산이 같은 집계값을 읽고, 대회 ID는 시즌 관계에서 구해요.
    value_columns = (["points_per_match"] if include_target else []) + ALL_FEATURES
    columns = ["competition_id", "season_id", "team_id", *value_columns]
    where_sql = ""
    params: tuple = ()
    if season_ids:
        where_sql = f"WHERE f.season_id IN ({', '.join(['%s'] * len(season_ids))})"
        params = tuple(season_ids)
    rows = fetch_all(
        f"""
        SELECT s.competition_id, f.season_id, f.team_id,
               {', '.join('f.' + column for column in value_columns)}
        FROM team_attribute_features f
        JOIN seasons s ON s.season_id = f.season_id
        {where_sql}
        ORDER BY s.competition_id, f.season_id, f.team_id
        """,
        params,
    )
    df = pd.DataFrame(rows, columns=columns)
    if df.empty:
        raise RuntimeError("No rows found in team_attribute_features.")
    # 미제공 값은 그대로 넘겨 각 영역에서 산출 가능 여부를 판단해요.
    for column in value_columns:
        df[column] = pd.to_numeric(df[column], errors="coerce")
    return df


def get_current_big5_season_ids() -> list[int]:
    rows = fetch_all(
        """
        SELECT season_id
        FROM seasons
        WHERE is_current = 1
          AND competition_id IN (8, 82, 301, 384, 564)
        ORDER BY competition_id, season_id
        """
    )

    return [int(row[0]) for row in rows]


def build_current_team_attribute_training_features() -> int:
    season_ids = get_current_big5_season_ids()

    if not season_ids:
        raise RuntimeError("No current Big 5 seasons found in seasons table.")

    return build_team_attribute_training_features_for_seasons(season_ids)
