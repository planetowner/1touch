"""공개 Chalkboard DOM에서 확인한 유효슈팅을 읽어요. DB에는 저장하지 않아요."""

from __future__ import annotations

import re
import json
import math
from collections import Counter
from urllib.parse import parse_qs, urlsplit


# 위젯 3.267.0의 normal.js와 generic.pitchevents에서 확인한 이벤트 영역 여백이에요.
# 잔디 그림의 800×524 크기와 이벤트 좌표의 범위는 달라요.
EVENT_INDENTS = {"left": 0.026, "right": 0.022, "top": 0.016, "bottom": 0.016}
SHOT_EVENTS = {"Goals": "goal", "Shots on target": "on_target"}
COORDINATE_SYSTEM = {"range": [0, 100], "origin": "top_left", "home_attacks": "right", "away_attacks": "left"}
# 유럽 예선의 AET·AET+P도 종료예요. FT만 검사하면 연장·승부차기 경기를 건너뛰어요.
FINISHED_SELECTOR = ", ".join(f'#Opta_0 abbr[title="{title}"]' for title in (
    "Full time", "After extra time", "After extra time penalties",
))

# Selenium과 수집 시험은 같은 DOM 추출 규칙을 사용해요. 숨겨진 앱 상태나 피드 키는 읽지 않아요.
EXTRACT_DOM = r"""() => {
    const widget = document.querySelector('.Opta_F_CB_container');
    const svg = widget?.querySelector('svg.Opta-selectable-area');
    const layer = svg?.querySelector('.Opta-events-layer');
    if (!layer) return null;
    const teams = {};
    for (const side of ['home', 'away']) {
        const holder = widget.querySelector(`.Opta-Teamsheet-Holder.Opta-${side === 'home' ? 'Home' : 'Away'}`);
        const team = holder?.querySelector('dt.Opta-Team');
        if (!team) return null;
        const id = [...team.classList].find(c => c.startsWith('Opta-Team-')).slice(10);
        teams[side] = {
            external_team_id: id, name: team.querySelector('.Opta-Name').textContent.trim(),
            players: [...holder.querySelectorAll('li.Opta-Player[data-id]')].map(p => ({
                external_player_id: p.getAttribute('data-id'),
                name: p.querySelector('.Opta-Name').textContent.trim(),
                jersey_number: Number(p.querySelector('.Opta-Shirt').textContent.trim())
            }))
        };
    }
    const summary = {};
    for (const row of document.querySelectorAll('#Opta_2_a tr')) {
        const heading = row.querySelector('th')?.textContent.trim();
        if (!['Goals', 'Shots on target'].includes(heading)) continue;
        const cells = row.nextElementSibling?.querySelectorAll('td');
        if (cells?.length === 3) {
            summary[heading] = {home: Number(cells[0].textContent.trim()),
                               away: Number(cells[2].textContent.trim())};
        }
    }
    // 경기장보다 요약 표가 늦게 도착하는 경기를 확인했어요. 빈 요약을 완료 결과로 읽지 않아요.
    if (!summary['Shots on target']) return null;
    return {
        source_url: document.URL,
        match_id: widget.getAttribute('match'),
        competition_id: widget.getAttribute('competition'),
        season_id: widget.getAttribute('season'),
        finished: Boolean(document.querySelector(__FINISHED_SELECTOR__)),
        match_date: document.querySelector('#Opta_0 .Opta-Date')?.textContent.trim(),
        teams,
        orientation: svg.parentElement.classList.contains('Opta-FootballPitch-Horizontal')
                     ? 'horizontal' : 'vertical',
        event_layer: {width: layer.querySelector('rect').getAttribute('width'),
                      height: layer.querySelector('rect').getAttribute('height')},
        selected_events: Array.from(widget.querySelectorAll('li[data-eid].Opta-On'))
                              .map(e => e.textContent.trim()),
        full_game: widget.querySelector('button.Opta-Full').classList.contains('Opta-On'),
        all_players_selected: [...widget.querySelectorAll('li.Opta-Player[data-id]')]
            .every(p => p.classList.contains('Opta-On')),
        summary,
        events: Array.from(layer.querySelectorAll('g.Opta-Player')).map(e => {
            const previous = e.previousElementSibling;
            const line = previous?.tagName.toLowerCase() === 'line' ? previous : null;
            // SVG 행렬로 읽으면 float32로 반올림돼요. 속성의 소수를 그대로 읽어 경계 판정을 보존해요.
            const position = e.getAttribute('transform')?.match(/^translate\(([-+0-9.e]+),\s*([-+0-9.e]+)\)$/i);
            return {
                id: e.getAttribute('data-id'), classes: e.getAttribute('class'),
                event_type: e.querySelector('.Opta-Tooltip-Key').textContent.trim(),
                time: e.querySelector('.Opta-Tooltip-Value').textContent.trim(),
                player_name: e.querySelector('p').textContent.trim(),
                team_name: e.querySelector('img').getAttribute('alt'),
                coords: ['x1', 'y1', 'x2', 'y2'].map(k => line?.getAttribute(k) ?? null),
                position: position ? [position[1], position[2]] : null
            };
        })
    };
}""".replace("__FINISHED_SELECTOR__", json.dumps(FINISHED_SELECTOR))


def match_page_ids(url: str) -> dict[str, str]:
    parsed = urlsplit(url)
    if (parsed.scheme != "https" or parsed.netloc not in {
        "theanalyst.com", "dataviz.theanalyst.com"
    } or parsed.path.rstrip("/") != "/opta-football-match-centre"):
        raise ValueError("Opta Analyst 경기 페이지의 HTTPS 주소를 입력해 주세요.")
    query = parse_qs(parsed.query)
    result = {}
    for key in ("competitionId", "seasonId", "matchId"):
        values = query.get(key, [])
        if len(values) != 1 or not re.fullmatch(r"[a-z0-9]+", values[0]):
            raise ValueError(f"경기 주소의 {key} 값을 확인해 주세요.")
        result[key] = values[0]
    return result


def validate_snapshot(snapshot: dict, required_events) -> tuple[float, float]:
    ids = match_page_ids(snapshot["source_url"])
    if snapshot["match_id"] != ids["matchId"]:
        raise ValueError("요청한 경기와 화면의 경기 ID가 달라요.")
    if (snapshot["competition_id"] != ids["competitionId"]
            or snapshot["season_id"] != ids["seasonId"]):
        raise ValueError("요청한 대회·시즌과 화면의 ID가 달라요.")
    if snapshot["orientation"] != "horizontal" or not snapshot["full_game"]:
        raise ValueError("가로 경기장과 Full game을 선택해 주세요.")
    if not set(required_events).issubset(snapshot["selected_events"]):
        raise ValueError(f"필요한 이벤트를 모두 포함해 주세요: {list(required_events)}")

    width = float(snapshot["event_layer"]["width"])
    height = float(snapshot["event_layer"]["height"])
    if not all(math.isfinite(v) and v > 0 for v in (width, height)):
        raise ValueError("경기장 이벤트 영역을 읽지 못했어요.")
    return width, height


def normalize_point(x, y, width: float, height: float) -> dict[str, float]:
    px = (float(x) / width - EVENT_INDENTS["left"]) / (
        1 - EVENT_INDENTS["left"] - EVENT_INDENTS["right"]
    ) * 100
    py = (float(y) / height - EVENT_INDENTS["top"]) / (
        1 - EVENT_INDENTS["top"] - EVENT_INDENTS["bottom"]
    ) * 100
    if not all(math.isfinite(v) for v in (px, py)):
        raise ValueError("이벤트 위치를 읽지 못했어요.")
    # 표시는 왼쪽 위가 원점이며 홈은 오른쪽, 원정은 왼쪽을 공격해요.
    return {"x": round(px, 6), "y": round(py, 6)}


def event_identity(snapshot: dict, event: dict) -> dict:
    event_id = event["id"]
    prefix = f"{snapshot['match_id']}-"
    if not event_id.startswith(prefix):
        raise ValueError("다른 경기의 이벤트가 섞여 있어요.")
    team_id, _ = event_id[len(prefix):].rsplit("-", 1)
    classes = event["classes"].split()
    players = [c.removeprefix("Opta-Player-") for c in classes if c.startswith("Opta-Player-")]
    sides = [s for s in ("home", "away") if f"Opta-{s.title()}" in classes]
    if len(players) != 1 or len(sides) != 1:
        raise ValueError(f"선수 ID나 홈·원정 팀을 확인할 수 없어요: {event_id}")
    side = sides[0]
    if team_id != snapshot["teams"][side]["external_team_id"]:
        raise ValueError(f"이벤트 ID와 홈·원정 팀이 달라요: {event_id}")
    time_text = event["time"].replace("\u200e", "").strip()
    match = re.fullmatch(r"(\d+)(?:\+(\d+))?'", time_text)
    if match is None:
        raise ValueError(f"경기 시간을 확인할 수 없어요: {time_text}")
    return {"external_event_id": event_id, "external_team_id": team_id,
            "external_player_id": players[0], "player_name": event["player_name"],
            "team_name": event["team_name"], "side": side,
            "minute": int(match[1]), "extra_minute": int(match[2] or 0)}


def source_metadata(snapshot: dict) -> dict:
    return {"provider": "opta", "coordinate_source": "chalkboard_svg",
            "source_url": snapshot["source_url"], "external_fixture_id": snapshot["match_id"],
            "external_competition_id": snapshot["competition_id"],
            "external_season_id": snapshot["season_id"], "coordinate_system": COORDINATE_SYSTEM}


def normalize_chalkboard(snapshot: dict) -> dict:
    width, height = validate_snapshot(snapshot, SHOT_EVENTS)

    shots = {}
    for event in snapshot["events"]:
        if event["event_type"] not in SHOT_EVENTS:
            continue
        event_id = event["id"]
        x1, y1, x2, y2 = event["coords"]
        shot = {
            **event_identity(snapshot, event),
            # Positive/Neutral은 도형 스타일이에요. 득점 여부는 툴팁의 이벤트명으로 구분해요.
            "result": SHOT_EVENTS[event["event_type"]],
            "start": normalize_point(x1, y1, width, height),
            "end": normalize_point(x2, y2, width, height),
        }
        # 실제 경기에서 같은 득점이 두 번 렌더링돼요. 순번이나 좌표로 새 ID를 만들지 않아요.
        if event_id in shots and shots[event_id] != shot:
            previous = shots[event_id]
            # AEK–LASK에서는 같은 득점이 Goals와 Shots on target 양쪽에 나타나요.
            # 선수·시간·좌표가 모두 같은 경우만 하나로 합치고 득점을 유지해요.
            if ({k: v for k, v in previous.items() if k != "result"}
                    != {k: v for k, v in shot.items() if k != "result"}):
                raise ValueError(f"같은 이벤트 ID의 내용이 달라요: {event_id}")
            shot["result"] = "goal" if "goal" in {previous["result"], shot["result"]} else "on_target"
        shots[event_id] = shot

    actual = Counter(shot["side"] for shot in shots.values())
    expected = snapshot["summary"]["Shots on target"]
    if any(actual[side] != expected[side] for side in ("home", "away")):
        raise ValueError(f"화면 요약과 추출한 유효슈팅 수가 달라요: {dict(actual)} / {expected}")
    return {
        **source_metadata(snapshot),
        # 끝점은 위젯이 그린 골라인·막힌 지점이에요. 높이·전체 궤적·xG는 이 DOM에 없어요.
        "end_position_kind": "widget_endpoint",
        "counts": {side: actual[side] for side in ("home", "away")},
        "shots": list(shots.values()),
    }
