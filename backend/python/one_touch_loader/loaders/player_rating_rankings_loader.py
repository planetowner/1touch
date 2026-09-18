"""과거 기준은 고정하고, 경기 평점을 저장할 때 시즌 점수를 함께 갱신해요."""
from __future__ import annotations

from contextlib import contextmanager

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
            return _write_player_rating_scores(cur, season_id)


def minimum_rated_matches_for_season(cur, season_id: int, standard_minimum: int) -> int:
    # 시작한 라운드 번호가 아니라 모든 경기가 끝난 라운드 수로 중반을 판단해요.
    # 미래 일정도 분모에 포함하고, 연기·진행 중 경기가 남은 라운드는 완료로 세지 않아요.
    completed = ",".join(map(str, COMPLETED_STATE_IDS))
    cur.execute(f"""SELECT COUNT(*) AS total_rounds,
                          COALESCE(SUM(round_finished), 0) AS completed_rounds
        FROM (
            SELECT r.round_id,
                   MIN(CASE WHEN f.state_id IN ({completed}) THEN 1 ELSE 0 END) AS round_finished
            FROM fixtures f
            JOIN stages st ON st.stage_id=f.stage_id
            JOIN rounds r ON r.round_id=f.round_id
            WHERE st.season_id=%s AND r.name REGEXP '^[0-9]+$'
            GROUP BY r.round_id
        ) AS season_rounds""", (season_id,))
    progress = cur.fetchone()
    halfway = progress["total_rounds"] > 0 and progress["completed_rounds"] * 2 >= progress["total_rounds"]
    return standard_minimum if halfway else 1


def _write_player_rating_scores(cur, season_id: int) -> int:
    # 수동 실행과 경기 저장이 같은 계산·삭제·저장 규칙을 사용해요.
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
    # 과거 표본의 10경기 기준은 고정하고, 평가 시즌만 중반 전까지 제한을 풀어요.
    minimum = minimum_rated_matches_for_season(cur, season_id, reference["minimum_rated_matches"])
    rows = fetch_rating_aggregates(cur, [season_id], minimum)
    values = [(
        competition_id, season_id, row["player_id"], row["rated_matches"], row["rating_sum"],
        distribution.score(average_rating(row["rating_sum"], row["rated_matches"])),
    ) for row in rows]
    # 중반의 기준 전환이나 평점 정정으로 자격을 잃은 선수도 빠지도록 시즌 전체를 교체해요.
    cur.execute("DELETE FROM player_rating_scores WHERE season_id=%s", (season_id,))
    if values:
        cur.executemany("""INSERT INTO player_rating_scores
            (competition_id, season_id, player_id, rated_matches, rating_sum, percentile_score)
            VALUES (%s,%s,%s,%s,%s,%s)""", values)
    return len(values)


@contextmanager
def refresh_player_ratings_after_fixture(connection, fixture_id: int, *,
                                         state_id: int | None = None, lineups_changed: bool = True):
    """경기 저장과 시즌 점수를 한 트랜잭션에 묶고, 준비된 리그만 갱신해요."""
    if not lineups_changed:
        yield
        return
    with connection.cursor(dictionary=True) as cur:
        # 일반 조회나 선수 저장 전에 시즌을 잠가 동시 수집이 서로의 최신 평점을 놓치지 않게 해요.
        # 종료 판정이 취소된 경우에도 이전 점수에서 그 경기를 빼야 해요.
        completed = ",".join(map(str, COMPLETED_STATE_IDS))
        cur.execute(f"""SELECT s.season_id
            FROM fixtures f
            JOIN stages st ON st.stage_id=f.stage_id
            JOIN seasons s ON s.season_id=st.season_id
            JOIN rounds r ON r.round_id=f.round_id
            JOIN player_rating_references ref ON ref.competition_id=s.competition_id
            WHERE f.fixture_id=%s AND r.name REGEXP '^[0-9]+$'
              AND (f.state_id IN ({completed}) OR %s IN ({completed}))
            FOR UPDATE""", (fixture_id, state_id))
        scope = cur.fetchone()
        yield
        if scope is not None:
            _write_player_rating_scores(cur, scope["season_id"])
