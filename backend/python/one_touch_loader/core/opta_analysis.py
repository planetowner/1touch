"""공개 패스·수비 행동을 정규화하고 승인한 1Touch 전진 지표를 계산해요."""

from __future__ import annotations

from collections import Counter
from math import hypot

from .opta_chalkboard import (
    event_identity, normalize_chalkboard, normalize_point, source_metadata, validate_snapshot,
)


ANALYSIS_EVENTS = {
    "Successful passes": "completed_pass", "Key Passes": "key_pass", "Assists": "assist",
    "Tackles won": "tackle_won", "Tackles lost": "tackle_lost",
    "Defensive blocks": "block", "Interceptions": "interception",
    "Clearances": "clearance", "Recoveries": "recovery",
}
PASS_KINDS = {"completed_pass", "key_pass", "assist"}
DEFENSIVE_KINDS = tuple(k for k in ANALYSIS_EVENTS.values() if k not in PASS_KINDS)
PITCH_LENGTH_M, PITCH_WIDTH_M = 105.0, 68.0
PROGRESSION_METHOD = {
    "provider": "1touch", "version": "goal_distance_30_15_10_v1",
    "pitch_length_m": PITCH_LENGTH_M, "pitch_width_m": PITCH_WIDTH_M,
    "distance_kind": "standardized_pitch_not_measured",
    "thresholds_m": {"own_half": 30, "cross_half": 15, "opponent_half": 10},
    "channel_basis": "destination_y_in_attack_direction",
    "pass_scope": "opta_successful_passes_excludes_crosses_throws",
}


def normalize_analysis(snapshot: dict) -> dict:
    width, height = validate_snapshot(snapshot, ANALYSIS_EVENTS)
    if snapshot.get("all_players_selected") is not True:
        raise ValueError("두 팀의 선수 전체를 선택한 화면이 필요해요.")
    # 같은 전체 경기 화면의 슈팅 수를 요약 표와 대조해 초기 로딩 중인 화면을 거절해요.
    normalize_chalkboard(snapshot)
    events = {}
    for raw in snapshot["events"]:
        kind = ANALYSIS_EVENTS.get(raw["event_type"])
        if kind is None:
            continue
        event = event_identity(snapshot, raw)
        if kind in PASS_KINDS:
            x1, y1, x2, y2 = raw["coords"]
            event.update(start=normalize_point(x1, y1, width, height),
                         end=normalize_point(x2, y2, width, height))
        else:
            # 수비 행동은 화살표 없이 g의 translate 위치만 있어요. 이전 도형의 좌표를 쓰지 않아요.
            x, y = raw["position"]
            event.update(start=normalize_point(x, y, width, height), end=None)
        key = event["external_event_id"]
        if key in events:
            previous = events[key]
            identity = {k: v for k, v in event.items() if k != "end"}
            if ({k: v for k, v in previous.items() if k not in {"kinds", "end"}} != identity
                    or (previous["end"] is not None and event["end"] is not None
                        and previous["end"] != event["end"])):
                raise ValueError(f"같은 이벤트 ID의 내용이 달라요: {key}")
            # 실제 5경기에서 태클·걷어내기가 어시스트로도 표시돼요. 점에는 없는 끝 좌표만 보충해요.
            # 성공 패스 분류를 새로 붙이지 않으므로 이 행동을 전진 패스로 계산하지 않아요.
            if previous["end"] is None:
                previous["end"] = event["end"]
            previous["kinds"] = sorted(set(previous["kinds"]) | {kind})
        else:
            events[key] = {**event, "kinds": [kind]}
    # 실제로 성공 패스와 키패스·어시스트가 중복 표시돼요. ID는 하나, 제공사 분류는 모두 보존해요.
    counts = Counter(e["side"] for e in events.values())
    return {**source_metadata(snapshot), "counts": {s: counts[s] for s in ("home", "away")},
            "events": sorted(events.values(), key=lambda e: (e["minute"], e["extra_minute"], e["external_event_id"]))}


def attacking_point(point: dict, side: str) -> dict:
    # 위젯은 홈→오른쪽, 원정→왼쪽이에요. 원정을 180도 돌려 팀 기준의 좌·우도 맞춰요.
    return {axis: point[axis] if side == "home" else 100 - point[axis] for axis in ("x", "y")}


def progressive_distance(start: dict, end: dict) -> tuple[float, float]:
    def distance(point):
        return hypot(PITCH_LENGTH_M * (1 - point["x"] / 100),
                     PITCH_WIDTH_M * (0.5 - point["y"] / 100))

    # 승인한 Wyscout 구역별 기준을 1Touch 표준 경기장에 적용해요. Opta 자체 지표가 아니에요.
    # https://dataglossary.wyscout.com/progressive_pass/
    threshold = 30.0 if end["x"] < 50 else 15.0 if start["x"] < 50 else 10.0
    return distance(start) - distance(end), threshold


def passing_metrics(events: list[dict], side: str) -> dict:
    completed, key_passes, final_third, progressive = [], [], [], []
    channels = Counter()
    for event in events:
        kinds = set(event["kinds"])
        # Opta의 Key Passes는 어시스트를 제외해요. 득점 도움을 기회 창출 수로 합치지 않아요.
        if "key_pass" in kinds and "assist" not in kinds:
            key_passes.append(event["external_event_id"])
        # 키패스·어시스트만으로는 크로스인지 일반 패스인지 알 수 없어요.
        # 실제 Successful passes 분류가 있는 이벤트만 전진 패스의 후보로 사용해요.
        if "completed_pass" not in kinds:
            continue
        completed.append(event["external_event_id"])
        start, end = (attacking_point(event[key], side) for key in ("start", "end"))
        if start["x"] < 200 / 3 <= end["x"]:
            final_third.append(event["external_event_id"])
        gain, threshold = progressive_distance(start, end)
        if gain >= threshold:
            channel = "left" if end["y"] < 100 / 3 else "center" if end["y"] < 200 / 3 else "right"
            channels[channel] += 1
            progressive.append({"external_event_id": event["external_event_id"],
                                "goal_distance_reduction_m": round(gain, 3), "channel": channel})
    total = len(progressive)
    return {
        "attack": {"key_passes": len(key_passes), "key_pass_event_ids": key_passes,
                   "completed_passes_into_final_third": len(final_third),
                   "final_third_entry_event_ids": final_third},
        "progression": {"completed_passes": len(completed), "progressive_passes": total,
                        "passes": progressive,
                        "channels": [{"channel": c, "count": channels[c],
                                      "percentage": round(100 * channels[c] / total, 2) if total else None}
                                     for c in ("left", "center", "right")]},
    }


def defensive_metrics(events: list[dict], side: str) -> dict:
    actions, recoveries = [], []
    for event in events:
        kinds = [kind for kind in event["kinds"] if kind in DEFENSIVE_KINDS]
        if not kinds:
            continue
        position = attacking_point(event["start"], side)
        actions.append({"external_event_id": event["external_event_id"], "kinds": kinds,
                        "attacking_position": position})
        if "recovery" in kinds:
            recoveries.append(position)
    # 태클 성공에는 공이 아웃된 상황도 있어요. 점유 회수로 판정된 Recoveries만 집계해요.
    mean_x = sum(p["x"] for p in recoveries) / len(recoveries) if recoveries else None
    return {"action_count": len(actions), "actions": actions,
            "recoveries": len(recoveries), "high_regains": sum(p["x"] >= 50 for p in recoveries),
            "average_regain_x": round(mean_x, 6) if mean_x is not None else None,
            "average_regain_height_m": round(mean_x * PITCH_LENGTH_M / 100, 2) if mean_x is not None else None}


def team_analysis(events: list[dict], side: str) -> dict:
    return {**passing_metrics(events, side), "defensive_activity": defensive_metrics(events, side)}
