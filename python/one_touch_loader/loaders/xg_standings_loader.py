"""이미 치른 경기를 xG로 다시 판정해 기존 1Touch 기대 순위를 만들어요.

Understat에서는 경기 xG를 가져오고, 기대 승점(xPts)은 아래 규칙으로 계산해요.
1. 같은 리그의 직전 5시즌에서 실제 결과와 xG가 모두 있는 완료 경기를 모아요.
2. 그 경기들의 실제 무승부 비율만큼, xG 차이가 작은 경기를 무승부로 보는 경계를 정해요.
3. 대상 시즌의 각 경기를 그 경계로 승·무·패 판정해 3·1·0점을 주고 합산해요.

확률에 따라 경기당 1.7점 등을 주는 모델은 아니에요. 이전 구현의 3·1·0점 규칙을 유지해요.
경기 화면의 수집 시작 시즌과 보정에 쓸 시즌은 별개예요. 17/18부터 xG를 모으면
직전 5시즌이 갖춰지는 22/23부터 기대 순위를 계산할 수 있어요.
"""
from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP
import math

from ..core.db import fetch_all, transaction
from ..core.fixture_states import COMPLETED_STATE_IDS
from .understat_common import load_understat_scope


# 직전 5시즌은 이전 구현에서 정한 기준이에요. 이번 테이블 정리에서 기간을 바꾸지 않아요.
CALIBRATION_LOOKBACK_SEASONS = 5
XG_PRECISION = Decimal("0.001")


def _round_xg(value) -> Decimal:
    # 기존 xG 순위 알고리즘은 경기별 xG를 세 자리로 반올림한 뒤 비교해요.
    return Decimal(str(value)).quantize(XG_PRECISION, rounding=ROUND_HALF_UP)


def _empirical_percentile_threshold(values: list[Decimal], percentile: Decimal) -> Decimal:
    """최소 percentile 비율의 관측값을 포함하는 가장 작은 경계를 선택해요."""
    if not values:
        raise ValueError("No xG differences for calibration")
    if percentile == 0:
        return Decimal("0.000")
    # 예: 경기 100개의 실제 무승부 비율이 25%면, xG 차이를 정렬한 25번째 값을 써요.
    # 같은 차이가 여러 경기에서 나오면 경계 안의 비율은 25%보다 커질 수 있어요.
    index = math.ceil(len(values) * float(percentile)) - 1
    return _round_xg(sorted(values)[index])


def load_xg_matches(season_ids: list[int]) -> list[dict]:
    rows = fetch_all(f"""
        SELECT st.season_id, f.fixture_id, f.home_team_id, f.away_team_id,
               f.home_score, f.away_score, x.home_xg, x.away_xg
        FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
        JOIN fixture_expected_goals x ON x.fixture_id=f.fixture_id
        WHERE st.season_id IN ({','.join('%s' for _ in season_ids)})
          AND f.state_id IN ({','.join(str(s) for s in COMPLETED_STATE_IDS)})
          AND f.home_score IS NOT NULL AND f.away_score IS NOT NULL
        ORDER BY f.starting_at, f.fixture_id
    """, tuple(season_ids))
    keys = ("season_id", "fixture_id", "home_team_id", "away_team_id", "home_score", "away_score", "home_xg", "away_xg")
    return [dict(zip(keys, row)) for row in rows]


def calculate_calibration(matches: list[dict]) -> dict:
    """그 리그의 과거 무승부 빈도를 xG 판정 기준에 반영해요.

    실제 무승부가 25%였다면, 대상 전체 경기의 xG 차이가 작은 쪽 25% 지점을 찾아요.
    실제로 무승부였던 경기만 골라 xG 차이를 구하는 것은 아니에요.
    예를 들어 그 지점의 차이가 0.4면, 새 시즌에서 양 팀 xG 차이가 0.4 이내일 때
    무승부로 판정해요. 0.4는 설명용 예시이며 실제 값은 리그·대상 시즌마다 계산해요.
    """
    # 무승부 비율과 xG 차이 분포는 정확히 같은 경기 범위를 사용해요.
    # 이전 초안처럼 실제 결과 전체와 일부 공급자 경기만 서로 비교하지 않아요.
    draws = sum(m["home_score"] == m["away_score"] for m in matches)
    rate = (Decimal(draws) / Decimal(len(matches))).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)
    differences = [abs(_round_xg(m["home_xg"]) - _round_xg(m["away_xg"])) for m in matches]
    return {"calibration_match_count": len(matches), "target_draw_rate": rate,
            "draw_band": _empirical_percentile_threshold(differences, rate)}


def aggregate_xg_standings(matches: list[dict], draw_band: Decimal) -> list[dict]:
    teams = {}
    for match in matches:
        for side, other in (("home", "away"), ("away", "home")):
            team_id = match[f"{side}_team_id"]
            if team_id not in teams:
                teams[team_id] = {"team_id": team_id, "matches_played": 0,
                                  "xg": Decimal("0.000"), "xga": Decimal("0.000"), "xpts": Decimal("0.00")}
            row = teams[team_id]
            own, opponent = _round_xg(match[f"{side}_xg"]), _round_xg(match[f"{other}_xg"])
            row["matches_played"] += 1
            row["xg"] += own
            row["xga"] += opponent
            difference = own - opponent
            # 그 경기의 실제 점수 대신 xG 차이로 판정해요. 경계가 0.4라는 예시에서는
            # 1.8 대 0.7이면 3점, 1.4 대 1.2이면 1점, 0.6 대 1.5이면 0점이에요.
            # 차이가 정확히 +0.4 또는 -0.4여도 무승부예요. 판정 전 xG는 세 자리로 반올림해요.
            if difference > draw_band:
                row["xpts"] += Decimal("3.00")
            elif difference >= -draw_band:
                row["xpts"] += Decimal("1.00")
    # 승점이 같으면 xG 득실차, 득점 xG 순으로 비교해요. 모두 같으면 팀 ID로 순서를 고정해요.
    rows = sorted(teams.values(), key=lambda r: (-r["xpts"], -(r["xg"] - r["xga"]), -r["xg"], r["team_id"]))
    for position, row in enumerate(rows, 1):
        row["position"] = position
    return rows


def _save_standings(season_id: int, calibration: dict, rows: list[dict]) -> None:
    with transaction() as connection:
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM xg_standings WHERE season_id=%s", (season_id,))
            cursor.execute("DELETE FROM xg_standings_calibration WHERE season_id=%s", (season_id,))
            cursor.execute("""
                INSERT INTO xg_standings_calibration
                (season_id,calibration_match_count,target_draw_rate,draw_band) VALUES (%s,%s,%s,%s)
            """, (season_id, calibration["calibration_match_count"], calibration["target_draw_rate"], calibration["draw_band"]))
            cursor.executemany("""
                INSERT INTO xg_standings (season_id,team_id,position,matches_played,xg,xga,xpts)
                VALUES (%s,%s,%s,%s,%s,%s,%s)
            """, [(season_id, r["team_id"], r["position"], r["matches_played"], r["xg"], r["xga"], r["xpts"]) for r in rows])


def build_xg_standings(season_name: str | None = None, competition_ids: list[int] | None = None,
                       *, check: bool = False) -> dict:
    result = {"seasons": 0, "rows": 0, "unavailable": []}
    for season in load_understat_scope(season_name, competition_ids):
        # 예: 26/27 EPL은 21/22~25/26 EPL만 참고해요. 다른 리그나 대상 시즌은 섞지 않아요.
        previous = fetch_all("""
            SELECT season_id, name FROM seasons
            WHERE competition_id=%s AND name<%s ORDER BY name DESC LIMIT 5
        """, (season["competition_id"], season["name"]))
        history = load_xg_matches([r[0] for r in previous]) if previous else []
        represented = {m["season_id"] for m in history}
        current = load_xg_matches([season["season_id"]])
        if len(represented) < CALIBRATION_LOOKBACK_SEASONS or not current:
            # 기존 규칙처럼 이전 5시즌 자료가 없으면 임의의 경계·승점을 만들지 않아요.
            reason = "five_previous_seasons_required" if len(represented) < 5 else "no_completed_xg_matches"
            result["unavailable"].append({**season, "reason": reason})
            print(f"[xg-standings] {season['name']} competition_id={season['competition_id']} unavailable={reason}", flush=True)
            continue
        calibration = calculate_calibration(history)
        rows = aggregate_xg_standings(current, calibration["draw_band"])
        if not check:
            _save_standings(season["season_id"], calibration, rows)
        result["seasons"] += 1
        result["rows"] += len(rows)
        print(f"[xg-standings] {season['name']} competition_id={season['competition_id']} "
              f"matches={len(current)} teams={len(rows)} draw_band={calibration['draw_band']} check={check}", flush=True)
    return result
