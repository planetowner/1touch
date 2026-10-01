"""선수 상세의 시즌 집계와 순위를 계산해요. DB를 변경하지 않아요."""
from __future__ import annotations

from collections import defaultdict

from .fixture_states import COMPLETED_STATE_IDS
from .player_match_metrics import (
    CATEGORIES, METRICS, POSITION_GROUPS, SUMMARY_METRICS, build_categories, build_metric,
)

MINIMUM_REFERENCE_MINUTES = 450
LOWER_IS_BETTER = frozenset({"goals_conceded", "possession_lost", "dribbled_past", "fouls_committed"})


def current_player_team(roster: list[dict], current_matches: list[dict]) -> dict | None:
    current_roster = [r for r in roster if r["is_current"]]
    team = current_roster[0] if current_roster else None
    # 이적 기록이 여러 개면 현재 시즌에 가장 최근에 출전한 팀을 우선해요.
    if len(current_roster) > 1 and current_matches:
        latest_team = max(current_matches, key=lambda r: r["starting_at"])["team_id"]
        team = next((r for r in current_roster if r["team_id"] == latest_team), team)
    return team


def dominant_position(matches: list[dict]) -> int | None:
    positions = defaultdict(lambda: [0, 0, ""])
    for row in matches:
        position = row["match_position_id"]
        if position in POSITION_GROUPS and row["state_id"] in COMPLETED_STATE_IDS:
            item = positions[position]
            item[0] += 1
            item[1] += row["minutes_played"] or 0
            item[2] = max(item[2], str(row["starting_at"]))
    # 출전 횟수가 같으면 출전 시간, 최근 출전 순으로 결정해요.
    return max(positions, key=lambda p: (*positions[p], -p)) if positions else None


def result_for(row: dict) -> str | None:
    if row["home_score"] is None or row["away_score"] is None:
        return None
    ours, theirs = (row["home_score"], row["away_score"]) if row["team_id"] == row["home_team_id"] else (row["away_score"], row["home_score"])
    return "WIN" if ours > theirs else "DEF" if ours < theirs else "DRAW"


def summarize(matches: list[dict]) -> dict:
    ratings = [float(r["rating"]) for r in matches if r["rating"] is not None]
    results = [result_for(r) for r in matches]
    known_results = [r for r in results if r is not None]
    wins = known_results.count("WIN")
    return {
        "appearances": len(matches), "starts": sum(r["lineup_type_id"] == 11 for r in matches),
        "minutes": sum(r["minutes_played"] or 0 for r in matches), "wins": wins,
        "win_rate": round(wins * 100 / len(known_results), 1) if matches and len(known_results) == len(matches) else None,
        "rating": round(sum(ratings) / len(ratings), 2) if ratings else None,
        "rated_matches": len(ratings),
    }


def stat_index(rows: list[dict]) -> dict:
    result = defaultdict(dict)
    for row in rows:
        result[(row["fixture_id"], row["team_id"], row["player_id"])][row["stat_type_id"]] = row["value"]
    return result


def season_categories(position: int | None, matches: list[dict], stats: dict) -> list[dict]:
    totals, coverage = {}, {}
    codes = [m for _, _, metrics in CATEGORIES.get(position, ()) for m in metrics]
    for code in codes:
        for type_id in METRICS[code][2]:
            values = [stats[(r["fixture_id"], r["team_id"], r["player_id"])].get(type_id) for r in matches]
            coverage[type_id] = sum(v is not None for v in values)
            # 일부 경기의 합계를 시즌 전체 기록으로 표시하거나 누락을 0으로 채우지 않아요.
            totals[type_id] = sum(values) if values and all(v is not None for v in values) else None
    xg_values = [r["xg"] for r in matches]
    xg = sum(xg_values) if xg_values and all(v is not None for v in xg_values) else None
    categories = build_categories(position, totals, xg)
    for category in categories:
        for metric in category["metrics"]:
            metric["observed_matches"] = (sum(v is not None for v in xg_values) if metric["code"] == "xg"
                                           else min((coverage[t] for t in metric["stat_type_ids"]), default=0))
            metric["total_matches"] = len(matches)
            metric["lower_is_better"] = metric["code"] in LOWER_IS_BETTER
            metric["per90"] = None
            if metric["kind"] != "percentage":
                # 기록과 출전 시간이 함께 있는 경기만 써요. 실제 0회 기록도 포함해요.
                # 성공/시도 쌍은 성공 횟수만 비교하므로 시도 기록의 누락과는 별개예요.
                samples = []
                for row in matches:
                    match_metric = build_metric(
                        metric["code"], stats[(row["fixture_id"], row["team_id"], row["player_id"])], row["xg"])
                    value = match_metric["numerator" if metric["kind"] == "pair" else "value"]
                    if value is not None and row["minutes_played"] is not None:
                        samples.append((value, row["minutes_played"]))
                metric["observed_matches"] = len(samples)
                minutes = sum(minutes for _, minutes in samples)
                if minutes > 0:
                    metric["per90"] = float(sum(value for value, _ in samples)) * 90 / minutes
            metric["rank_value"] = float(metric["numerator"] / metric["denominator"] * 100) if metric["value"] is not None and metric["kind"] == "percentage" else metric["per90"]
    return categories


def rank_categories(categories: list[dict], reference: list[list[dict]], *, includes_player: bool = True) -> list[dict]:
    by_code = defaultdict(list)
    for player_categories in reference:
        for category in player_categories:
            for metric in category["metrics"]:
                if metric["rank_value"] is not None:
                    by_code[metric["code"]].append(metric["rank_value"])
    ranked = []
    for category in categories:
        for metric in category["metrics"]:
            values = by_code[metric["code"]]
            value = metric["rank_value"]
            metric["reference_count"] = len(values) + (0 if includes_player or value is None else 1)
            metric["rank"] = None
            metric["percentile"] = None
            if value is not None and values:
                better = sum(v < value if metric["lower_is_better"] else v > value for v in values)
                metric["rank"] = better + 1
                metric["percentile"] = round(100 * (len(values) - better) / len(values), 1)
                ranked.append(metric)
    # 부진한 선수도 순위가 있는 항목 중 가장 높은 세 항목을 표시해요. 동순위는 카테고리 순서예요.
    return sorted(ranked, key=lambda m: m["rank"])[:3]


def build_career(matches: list[dict]) -> list[dict]:
    groups = defaultdict(list)
    for row in matches:
        if row["state_id"] in COMPLETED_STATE_IDS:
            groups[(row["season_name"], row["team_id"])].append(row)
    result = []
    for (season_name, team_id), rows in groups.items():
        competitions = defaultdict(list)
        for row in rows:
            competitions[row["competition_id"]].append(row)
        result.append({"season_name": season_name, "team_id": team_id,
                       "team_name": rows[0]["team_name"], "team_code": rows[0]["team_code"],
                       "team_image": rows[0]["team_image"], **summarize(rows),
                       "last_match_at": max(r["starting_at"] for r in rows),
                       "competitions": [{"competition_id": cid, "competition_name": items[0]["competition_name"],
                                         **summarize(items)} for cid, items in competitions.items()]})
    return sorted(result, key=lambda r: (r["season_name"], r["last_match_at"]), reverse=True)


def match_cards(matches: list[dict], position: int | None, stats: dict) -> list[dict]:
    return [{**r, "result": result_for(r), "position_group": POSITION_GROUPS.get(position),
             "metrics": [build_metric(code, stats[(r["fixture_id"], r["team_id"], r["player_id"])], r["xg"])
                         for code in SUMMARY_METRICS.get(position, ())]}
            for r in sorted(matches, key=lambda r: (r["starting_at"], r["fixture_id"]), reverse=True)]
