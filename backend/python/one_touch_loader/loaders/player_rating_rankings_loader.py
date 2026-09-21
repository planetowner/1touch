"""누적 비교 표본과 영향받는 모든 리그·시즌 점수를 함께 갱신해요."""
from __future__ import annotations

from collections import Counter
from contextlib import closing, contextmanager
import re

from one_touch_loader.core.db import get_conn, transaction
from one_touch_loader.core.fixture_states import COMPLETED_STATE_IDS
from one_touch_loader.core.player_rating_percentile import (
    MINIMUM_RATED_MATCHES, RATING_COMPETITION_IDS, REFERENCE_START_SEASON_NAME,
    score_season_records,
)


def fetch_rating_aggregates(cursor, season_ids: list[int], minimum_rated_matches: int) -> list[dict]:
    # 같은 리그 내 이적·포지션 변경은 합치고, 다른 리그 기록은 각각 한 표본으로 세요.
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


def _lock_rating_pool(cur):
    # 리그별 잠금으로는 공유 표본을 보호할 수 없어서 모든 갱신이 같은 행을 먼저 잠가요.
    # 일반 SELECT보다 먼저 잠가, 기다린 작업도 직전 커밋의 표본을 읽도록 해요.
    cur.execute("SELECT competition_id FROM competitions WHERE competition_id=%s FOR UPDATE",
                (RATING_COMPETITION_IDS[0],))
    cur.fetchone()


def _rating_seasons(cur) -> list[dict]:
    cur.execute(f"""SELECT season_id, competition_id, name AS season_name FROM seasons
        WHERE competition_id IN ({','.join(['%s'] * len(RATING_COMPETITION_IDS))})
          AND name >= %s ORDER BY name, competition_id""",
                (*RATING_COMPETITION_IDS, REFERENCE_START_SEASON_NAME))
    seasons = cur.fetchall()
    if not seasons or any(not re.fullmatch(r"\d{4}/\d{4}", row["season_name"]) for row in seasons):
        raise ValueError("Five-league seasons from 2017/2018 are required")
    last_year = int(seasons[-1]["season_name"][:4])
    expected = {(competition, f"{year}/{year + 1}")
                for year in range(int(REFERENCE_START_SEASON_NAME[:4]), last_year + 1)
                for competition in RATING_COMPETITION_IDS}
    if {(row["competition_id"], row["season_name"]) for row in seasons} != expected:
        raise ValueError("Every year from 2017/2018 must contain all five league seasons")
    return seasons


def _season_minimums(cur, season_ids: list[int], standard_minimum: int) -> dict[int, int]:
    completed = ",".join(map(str, COMPLETED_STATE_IDS))
    cur.execute(f"""SELECT season_id, COUNT(*) AS total_rounds,
                          COALESCE(SUM(round_finished), 0) AS completed_rounds
        FROM (
            SELECT st.season_id, r.round_id,
                   MIN(CASE WHEN f.state_id IN ({completed}) THEN 1 ELSE 0 END) AS round_finished
            FROM fixtures f
            JOIN stages st ON st.stage_id=f.stage_id
            JOIN rounds r ON r.round_id=f.round_id
            WHERE st.season_id IN ({','.join(['%s'] * len(season_ids))}) AND r.name REGEXP '^[0-9]+$'
            GROUP BY st.season_id, r.round_id
        ) AS season_rounds GROUP BY season_id""", tuple(season_ids))
    minimums = dict.fromkeys(season_ids, 1)
    for row in cur.fetchall():
        # 미래 일정도 분모에 포함하고, 연기·진행 중 경기가 있는 라운드는 완료로 세지 않아요.
        if row["total_rounds"] > 0 and row["completed_rounds"] * 2 >= row["total_rounds"]:
            minimums[row["season_id"]] = standard_minimum
    return minimums


def minimum_rated_matches_for_season(cur, season_id: int, standard_minimum: int) -> int:
    return _season_minimums(cur, [season_id], standard_minimum)[season_id]


def _eligible_rating_rows(cur, seasons: list[dict]) -> list[dict]:
    names = {row["season_id"]: row["season_name"] for row in seasons}
    minimums = _season_minimums(cur, list(names), MINIMUM_RATED_MATCHES)
    # 평가 선수와 비교 표본에 같은 시즌별 출전 기준을 적용해요.
    return [{**row, "season_name": names[row["season_id"]]}
            for row in fetch_rating_aggregates(cur, list(names), 1)
            if row["rated_matches"] >= minimums[row["season_id"]]]


def _pool_is_ready(cur) -> bool:
    cur.execute("SELECT competition_id, start_season_name FROM player_rating_references")
    rows = {row["competition_id"]: row["start_season_name"] for row in cur.fetchall()}
    return all(rows.get(competition) == REFERENCE_START_SEASON_NAME for competition in RATING_COMPETITION_IDS)


def _save_reference_metadata(cur, seasons: list[dict]):
    # 이 메타데이터는 적재된 범위예요. 실제 비교의 끝 시즌은 평가 시즌마다 달라요.
    cur.executemany("""INSERT INTO player_rating_references
        (competition_id, start_season_name, end_season_name, minimum_rated_matches)
        VALUES (%s,%s,%s,%s)
        ON DUPLICATE KEY UPDATE start_season_name=VALUES(start_season_name),
          end_season_name=VALUES(end_season_name), minimum_rated_matches=VALUES(minimum_rated_matches),
          updated_at=CURRENT_TIMESTAMP""", [
        (competition, REFERENCE_START_SEASON_NAME,
         max(row["season_name"] for row in seasons if row["competition_id"] == competition),
         MINIMUM_RATED_MATCHES) for competition in RATING_COMPETITION_IDS
    ])


def _replace_samples(cur, season_ids: list[int], rows: list[dict]):
    cur.execute(f"DELETE FROM player_rating_reference_samples WHERE season_id IN ({','.join(['%s'] * len(season_ids))})",
                tuple(season_ids))
    if rows:
        cur.executemany("""INSERT INTO player_rating_reference_samples
            (competition_id, season_id, player_id, rated_matches, rating_sum) VALUES (%s,%s,%s,%s,%s)""", [
            (row["competition_id"], row["season_id"], row["player_id"], row["rated_matches"], row["rating_sum"])
            for row in rows
        ])


def _replace_scores(cur, season_ids: list[int], scored: list[dict]):
    cur.execute(f"DELETE FROM player_rating_scores WHERE season_id IN ({','.join(['%s'] * len(season_ids))})",
                tuple(season_ids))
    values = [(row["competition_id"], row["season_id"], row["player_id"], row["rated_matches"],
               row["rating_sum"], row["percentile_score"]) for row in scored if row["season_id"] in season_ids]
    if values:
        cur.executemany("""INSERT INTO player_rating_scores
            (competition_id, season_id, player_id, rated_matches, rating_sum, percentile_score)
            VALUES (%s,%s,%s,%s,%s,%s)""", values)


def rebuild_player_rating_scores(*, apply: bool = False) -> dict:
    """저장된 원본으로 전체 범위를 계산해요. --apply에서만 표본과 점수를 교체해요."""
    with (transaction() if apply else closing(get_conn())) as conn:
        with conn.cursor(dictionary=True) as cur:
            if apply:
                _lock_rating_pool(cur)
            seasons = _rating_seasons(cur)
            rows = _eligible_rating_rows(cur, seasons)
            scored = score_season_records(rows)
            if apply:
                _save_reference_metadata(cur, seasons)
                ids = [row["season_id"] for row in seasons]
                _replace_samples(cur, ids, rows)
                _replace_scores(cur, ids, scored)
    counts = Counter(row["season_name"] for row in rows)
    cumulative = 0
    reports = []
    for name in sorted({row["season_name"] for row in seasons}):
        cumulative += counts[name]
        reports.append({"season_name": name, "players": counts[name], "reference_samples": cumulative})
    return {"apply": apply, "league_seasons": len(seasons), "scores": len(scored), "seasons": reports}


def build_player_rating_scores(season_id: int) -> int:
    with transaction() as conn:
        with conn.cursor(dictionary=True) as cur:
            _lock_rating_pool(cur)
            return _write_player_rating_scores(cur, season_id)


def _write_player_rating_scores(cur, season_id: int) -> int:
    if not _pool_is_ready(cur):
        raise ValueError("Run player-rankings rebuild --apply to initialize the cumulative five-league reference")
    seasons = _rating_seasons(cur)
    target = next((row for row in seasons if row["season_id"] == season_id), None)
    if target is None:
        raise ValueError("A five-league season from 2017/2018 is required")
    changed = [row for row in seasons if row["season_name"] == target["season_name"]]
    rows = _eligible_rating_rows(cur, changed)
    _replace_samples(cur, [row["season_id"] for row in changed], rows)
    cur.execute(f"""SELECT sample.*, s.name AS season_name FROM player_rating_reference_samples sample
        JOIN seasons s ON s.season_id=sample.season_id
        WHERE sample.competition_id IN ({','.join(['%s'] * len(RATING_COMPETITION_IDS))})
          AND s.name >= %s ORDER BY s.name, sample.competition_id, sample.player_id""",
                (*RATING_COMPETITION_IDS, REFERENCE_START_SEASON_NAME))
    scored = score_season_records(cur.fetchall())
    # 과거 평점 정정은 그 시즌과 이후 시즌의 기준에도 영향을 줘요. 이전 시즌은 건드리지 않아요.
    affected = [row["season_id"] for row in seasons if row["season_name"] >= target["season_name"]]
    _replace_scores(cur, affected, scored)
    _save_reference_metadata(cur, seasons)
    return sum(row["season_id"] == season_id for row in rows)


@contextmanager
def refresh_player_ratings_after_fixture(connection, fixture_id: int, *,
                                         state_id: int | None = None, lineups_changed: bool = True):
    if not lineups_changed:
        yield
        return
    with connection.cursor(dictionary=True) as cur:
        _lock_rating_pool(cur)
        completed = ",".join(map(str, COMPLETED_STATE_IDS))
        cur.execute(f"""SELECT s.season_id FROM fixtures f
            JOIN stages st ON st.stage_id=f.stage_id
            JOIN seasons s ON s.season_id=st.season_id
            JOIN rounds r ON r.round_id=f.round_id
            WHERE f.fixture_id=%s AND r.name REGEXP '^[0-9]+$'
              AND s.competition_id IN ({','.join(['%s'] * len(RATING_COMPETITION_IDS))})
              AND s.name >= %s AND (f.state_id IN ({completed}) OR %s IN ({completed}))""",
                    (fixture_id, *RATING_COMPETITION_IDS, REFERENCE_START_SEASON_NAME, state_id))
        scope = cur.fetchone()
        ready = scope is not None and _pool_is_ready(cur)
        yield
        if ready:
            _write_player_rating_scores(cur, scope["season_id"])
