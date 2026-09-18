"""확정한 경기별 선수 지표와 포지션별 표시 순서를 한곳에서 관리해요."""
from __future__ import annotations

from collections import defaultdict


# Sportmonks의 경기 라인업 position_id예요. 선수 프로필의 세부 포지션과 달라요.
POSITION_GROUPS = {24: "GK", 25: "DF", 26: "MF", 27: "FW"}
MAN_OF_MATCH_TYPE_ID = 1490

# pair·percentage의 ID 순서는 성공 횟수, 전체 시도 횟수예요.
METRICS = {
    "saves": ("Saves", "count", (57,)),
    "goals_conceded": ("Goals conceded", "count", (1535,)),
    "touches": ("Touches", "count", (120,)),
    "passes": ("Passes completed / attempted", "pair", (116, 80)),
    "possession_lost": ("Possession lost", "count", (27273,)),
    "clearances": ("Clearances", "count", (101,)),
    "ball_recoveries": ("Ball recoveries", "count", (27271,)),
    "long_balls": ("Long balls attempted", "count", (122,)),
    "long_ball_success_rate": ("Long ball success rate", "percentage", (123, 122)),
    "duels": ("Duels won / contested", "pair", (106, 105)),
    "aerial_duels_won": ("Aerial duels won", "count", (107,)),
    # 실제 응답에서 성공 태클이 전체 태클보다 큰 사례가 있어 횟수만 표시해요.
    "tackles": ("Tackles", "count", (78,)),
    "dribbled_past": ("Dribbled past", "count", (110,)),
    "fouls_committed": ("Fouls committed", "count", (56,)),
    "interceptions": ("Interceptions", "count", (100,)),
    "key_passes": ("Key passes", "count", (117,)),
    "final_third_passes": ("Passes in final third", "count", (27269,)),
    "assists": ("Assists", "count", (79,)),
    "total_duels": ("Total duels", "count", (105,)),
    "fouls_drawn": ("Fouls drawn", "count", (96,)),
    "goals": ("Goals", "count", (52,)),
    "xg": ("xG", "decimal", ()),
    "shots": ("Total shots", "count", (42,)),
    "dribble_attempts": ("Dribble attempts", "count", (108,)),
    "dribble_success_rate": ("Dribble success rate", "percentage", (109, 108)),
}

# GK High Claim과 DF Dribbling은 제외했어요. 공통 지표는 위 정의를 재사용해요.
CATEGORIES = {
    24: (
        ("save", "Save", ("saves", "goals_conceded")),
        ("build_up", "Build Up", ("touches", "passes", "possession_lost")),
        ("defensive_actions", "Defensive Actions", ("clearances", "ball_recoveries")),
        ("long_balls", "Long Balls", ("long_balls", "long_ball_success_rate")),
    ),
    25: (
        ("physicality", "Physicality", ("duels", "aerial_duels_won")),
        ("tackles", "Tackles", ("tackles", "dribbled_past", "fouls_committed")),
        ("build_up", "Build Up", ("touches", "passes", "long_ball_success_rate")),
        ("recoveries", "Recoveries", ("ball_recoveries", "interceptions", "clearances")),
    ),
    26: (
        ("build_up", "Build Up", ("touches", "passes")),
        ("defence", "Defence", ("tackles", "interceptions", "ball_recoveries")),
        ("playmaking", "Playmaking", ("key_passes", "final_third_passes", "assists")),
        # 이동 거리가 아니라 경합·피파울 기록으로 활동을 보여줘요.
        ("work_rate", "Work Rate", ("total_duels", "fouls_drawn")),
        ("attack", "Attack", ("goals", "xg", "shots")),
    ),
    27: (
        ("finish", "Finish", ("goals", "xg", "shots")),
        ("playmaking", "Playmaking", ("key_passes", "final_third_passes", "assists")),
        ("defence", "Defence", ("ball_recoveries", "tackles")),
        ("dribble", "Dribble", ("dribble_attempts", "dribble_success_rate", "fouls_drawn")),
        ("link_up", "Link Up", ("touches", "passes", "possession_lost")),
    ),
}

# Touches는 출전 선수 모두의 값이 필요하지만, 블록은 기록된 선수만 응답에 나와요.
# 97은 상대 슈팅을 막은 횟수예요. 우리 슈팅이 막힌 58과 바꾸어 쓰지 않아요.
TEAM_TOTALS = {
    120: ("touches", "Touches", True),
    97: ("blocked-shots", "Blocks", False),
}

STORED_STAT_TYPE_IDS = frozenset(
    type_id for _, _, type_ids in METRICS.values() for type_id in type_ids
) | {MAN_OF_MATCH_TYPE_ID} | frozenset(TEAM_TOTALS)


def _metric(code: str, stats: dict, xg) -> dict:
    label, kind, type_ids = METRICS[code]
    result = {
        "code": code, "label": label, "kind": kind,
        "source": "understat" if code == "xg" else "sportmonks",
        "stat_type_ids": list(type_ids), "value": None,
    }
    if kind in {"pair", "percentage"}:
        numerator, denominator = (stats.get(type_id) for type_id in type_ids)
        result.update(numerator=numerator, denominator=denominator)
        # 누락을 0으로 채우거나 모순된 성공/시도 값을 100%로 보정하지 않아요.
        if (kind == "percentage" and numerator is not None and denominator is not None
                and denominator > 0 and 0 <= numerator <= denominator):
            result["value"] = round(float(numerator / denominator * 100), 1)
    else:
        result["value"] = xg if code == "xg" else stats.get(type_ids[0])
    return result


def _stats_by_player(stat_rows: list[dict]) -> dict:
    by_player = defaultdict(dict)
    for row in stat_rows:
        by_player[(row["team_id"], row["player_id"])][row["stat_type_id"]] = row["value"]
    return by_player


def build_team_player_statistics(team_ids: list[int], lineups: list[dict], stat_rows: list[dict]) -> list[dict]:
    """선수 통계를 공급자의 기록 방식에 맞춰 팀 statistics로 합쳐요."""
    by_player = _stats_by_player(stat_rows)
    result = []
    for type_id, (code, name, require_all_players) in TEAM_TOTALS.items():
        values = defaultdict(list)
        for lineup in lineups:
            value = by_player[(lineup["team_id"], lineup["player_id"])].get(type_id)
            # 미출전 벤치는 제외하고, 0분 교체 선수도 기록이 있으면 포함해요.
            if lineup["lineup_type_id"] == 11 or (lineup["minutes_played"] or 0) > 0 or value is not None:
                if require_all_players or value is not None:
                    values[lineup["team_id"]].append(value)
        for team_id in team_ids:
            team_values = values[team_id]
            # 19134453처럼 Touches가 일부 빠지면 부분합을 표시하지 않아요.
            # 블록도 기록 자체가 없으면 미수집·미제공과 0을 구분할 수 없어 null로 남겨요.
            total = sum(team_values) if team_values and all(v is not None for v in team_values) else None
            result.append({"team_id": team_id, "stat_type_id": type_id, "stat_code": code,
                           "stat_name": name, "value": total})
    return result


def build_player_statistics(lineups: list[dict], stat_rows: list[dict], xg_rows: list[dict]) -> list[dict]:
    by_player = _stats_by_player(stat_rows)
    xg_by_player = {row["player_id"]: row["xg"] for row in xg_rows}
    players = []
    for lineup in lineups:
        position_id = lineup["match_position_id"]
        stats = by_player[(lineup["team_id"], lineup["player_id"])]
        pom = stats.get(MAN_OF_MATCH_TYPE_ID)
        players.append({
            "team_id": lineup["team_id"], "player_id": lineup["player_id"],
            "match_position_id": position_id, "position_group": POSITION_GROUPS.get(position_id),
            "minutes_played": lineup["minutes_played"], "rating": lineup["rating"],
            # 최고 평점으로 POM을 만들어 내지 않아요. 미제공은 null로 남겨요.
            "is_man_of_match": None if pom is None else bool(pom),
            "categories": [
                {"code": code, "label": label,
                 "metrics": [_metric(metric, stats, xg_by_player.get(lineup["player_id"]))
                             for metric in metric_codes]}
                for code, label, metric_codes in CATEGORIES.get(position_id, ())
            ],
        })
    return players
