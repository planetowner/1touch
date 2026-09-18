"""과거 기준 고정과 시즌 점수 갱신을 별도 명령으로 실행해요."""
from __future__ import annotations

from one_touch_loader.core.db import transaction
from one_touch_loader.core.fixture_states import COMPLETED_STATE_IDS
from one_touch_loader.core.player_rating_percentile import (
    HistoricalPercentile, MINIMUM_RATED_MATCHES, REFERENCE_SEASON_NAMES, average_rating,
)


def fetch_rating_aggregates(cursor, season_ids: list[int], minimum_rated_matches: int) -> list[dict]:
    # 포지션 변경과 같은 리그 내 이적은 나누지 않아요. 기준 표본과 평가 대상에 같은 집계 규칙을 써요.
    cursor.execute(f"""
        SELECT s.competition_id, s.season_id, fl.player_id,
               COUNT(fl.rating) AS rated_matches, SUM(fl.rating) AS rating_sum
        FROM fixture_lineups fl
        JOIN fixtures f ON f.fixture_id=fl.fixture_id
        JOIN stages st ON st.stage_id=f.stage_id
        JOIN seasons s ON s.season_id=st.season_id
        JOIN rounds r ON r.round_id=f.round_id
        WHERE s.season_id IN ({','.join(['%s'] * len(season_ids))})
          AND f.state_id IN ({','.join(map(str, COMPLETED_STATE_IDS))})
          AND r.name REGEXP '^[0-9]+$'
          AND fl.minutes_played > 0 AND fl.rating IS NOT NULL
        GROUP BY s.competition_id, s.season_id, fl.player_id
        HAVING COUNT(fl.rating) >= %s
    """, (*season_ids, minimum_rated_matches))
    return cursor.fetchall()


def freeze_player_rating_reference(competition_id: int) -> int:
    """리그별 2020/21~2024/25 표본을 처음 한 번만 저장하고 표본 수를 반환해요."""
    with transaction() as conn:
        with conn.cursor(dictionary=True) as cur:
            # 같은 리그의 중복 실행도 기존 표본을 다시 만들지 않게 직렬화해요.
            cur.execute("SELECT competition_type FROM competitions WHERE competition_id=%s FOR UPDATE", (competition_id,))
            competition = cur.fetchone()
            if competition is None or competition["competition_type"] != "league":
                raise ValueError("A league competition_id is required")
            cur.execute("SELECT competition_id FROM player_rating_references WHERE competition_id=%s", (competition_id,))
            if cur.fetchone() is not None:
                cur.execute("SELECT COUNT(*) AS n FROM player_rating_reference_samples WHERE competition_id=%s", (competition_id,))
                return cur.fetchone()["n"]

            cur.execute(f"""SELECT season_id, name FROM seasons
                WHERE competition_id=%s AND name IN ({','.join(['%s'] * len(REFERENCE_SEASON_NAMES))})
                ORDER BY name""", (competition_id, *REFERENCE_SEASON_NAMES))
            seasons = cur.fetchall()
            if tuple(row["name"] for row in seasons) != REFERENCE_SEASON_NAMES:
                raise ValueError("All five reference seasons (2020/2021 through 2024/2025) are required")
            season_ids = [row["season_id"] for row in seasons]
            samples = fetch_rating_aggregates(cur, season_ids, MINIMUM_RATED_MATCHES)
            if {row["season_id"] for row in samples} != set(season_ids):
                raise ValueError("Every reference season must have players with at least 10 rated matches")

            cur.execute("""INSERT INTO player_rating_references
                (competition_id, start_season_name, end_season_name, minimum_rated_matches)
                VALUES (%s,%s,%s,%s)""", (
                competition_id, REFERENCE_SEASON_NAMES[0], REFERENCE_SEASON_NAMES[-1], MINIMUM_RATED_MATCHES,
            ))
            cur.executemany("""INSERT INTO player_rating_reference_samples
                (competition_id, season_id, player_id, rated_matches, rating_sum)
                VALUES (%s,%s,%s,%s,%s)""", [
                (competition_id, row["season_id"], row["player_id"], row["rated_matches"], row["rating_sum"])
                for row in samples
            ])
    return len(samples)


def build_player_rating_scores(season_id: int) -> int:
    """저장된 기준 표본으로 한 시즌을 갱신해요. 기준 자체는 변경하지 않아요."""
    with transaction() as conn:
        with conn.cursor(dictionary=True) as cur:
            cur.execute("SELECT competition_id FROM seasons WHERE season_id=%s FOR UPDATE", (season_id,))
            season = cur.fetchone()
            if season is None:
                raise ValueError("Season not found")
            competition_id = season["competition_id"]
            cur.execute("SELECT minimum_rated_matches FROM player_rating_references WHERE competition_id=%s", (competition_id,))
            reference = cur.fetchone()
            if reference is None:
                raise ValueError("Freeze this league's historical rating reference before building scores")
            cur.execute("SELECT rating_sum, rated_matches FROM player_rating_reference_samples WHERE competition_id=%s", (competition_id,))
            distribution = HistoricalPercentile(
                average_rating(row["rating_sum"], row["rated_matches"]) for row in cur.fetchall()
            )
            rows = fetch_rating_aggregates(cur, [season_id], reference["minimum_rated_matches"])
            values = [(
                competition_id, season_id, row["player_id"], row["rated_matches"], row["rating_sum"],
                distribution.score(average_rating(row["rating_sum"], row["rated_matches"])),
            ) for row in rows]
            # 원본 정정으로 10경기 미만이 된 선수도 빠지도록 시즌 결과를 한 트랜잭션으로 교체해요.
            cur.execute("DELETE FROM player_rating_scores WHERE season_id=%s", (season_id,))
            if values:
                cur.executemany("""INSERT INTO player_rating_scores
                    (competition_id, season_id, player_id, rated_matches, rating_sum, percentile_score)
                    VALUES (%s,%s,%s,%s,%s,%s)""", values)
    return len(values)
