from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from ..core.db import fetch_all
from ..core.understat import UNDERSTAT_LEAGUES, season_start_year


# 2026-09-09: PSG–Rennes 31948에 CSKA–Rostov의 선수 명단 31명과 슈팅이 섞였어요.
# 사용자가 이 경기의 기대값·슈팅을 미제공으로 확정했어요. 원본 재검증 전에는 해제하지 않아요.
# https://pfc-cska.com/ru/novosti/vse-novosti/32444-pfk-cska-rostov-00/
# https://www.psg.fr/matchs/football-masculin/20262027/paris-vs-rennes-2026-08-23
UNAVAILABLE_UNDERSTAT_MATCHES = {
    "31948": "roster_and_shots_belong_to_cska_rostov",
    # 30804는 명단 29명·슈팅 23쌍이 중복됐고 팀 xG에도 중복 슈팅이 포함돼요.
    # 단건 재조회도 같았어요. 사용자가 미제공을 선택했으므로 임의로 빼거나 재계산하지 않아요.
    # https://understat.com/match/30804
    "30804": "duplicated_rosters_and_shots_in_team_xg",
    # 2026-09-09: 과거 5개 시즌을 대조한 뒤 사용자가 아래 3경기도 미제공으로 확정했어요.
    # 23028은 선수 30명의 명단이 중복돼요. 정상인 팀 xG·슈팅도 경기 단위 계약에 맞춰 제외해요.
    "23028": "duplicated_rosters",
    # 27930은 명단·슈팅이 모두 없고 xG만 실제 점수와 같은 2:2예요. 다른 공급자 값으로 채우지 않아요.
    "27930": "empty_rosters_and_shots_with_unverifiable_team_xg",
    # 29482는 선수 32명과 슈팅 23쌍이 중복되고 팀 xG에도 중복분이 포함돼요.
    "29482": "duplicated_rosters_and_shots_in_team_xg",
    # 18116은 Enzo Tchato의 교체 출전을 Sacha Delaye로 기록했어요. 사용자 확인 후 경기 전체를 제외해요.
    # Sportmonks 18155949와 당시 경기 기록을 대조했어요. 선수 ID·xG 0을 임의로 옮기지 않아요.
    # https://www.lequipe.fr/Football/match-direct/ligue-1/2021-2022/montpellier-brest-live/515773
    "18116": "roster_attributes_tchato_appearance_to_delaye",
}


def select_understat_matches(source: dict) -> tuple[list[dict], list[dict]]:
    """매핑과 수치 적재가 같은 완료 경기 범위를 사용해요."""
    matches, unavailable = [], []
    for match in source["dates"]:
        if not match["isResult"]:
            continue
        external_id = str(match["id"])
        if external_id in UNAVAILABLE_UNDERSTAT_MATCHES:
            unavailable.append({"external_fixture_id": external_id,
                                "reason": UNAVAILABLE_UNDERSTAT_MATCHES[external_id]})
        else:
            matches.append(match)
    return matches, unavailable


def load_understat_scope(season_name: str | None = None, competition_ids: list[int] | None = None) -> list[dict]:
    ids = competition_ids if competition_ids is not None else list(UNDERSTAT_LEAGUES)
    if not ids or any(cid not in UNDERSTAT_LEAGUES for cid in ids):
        raise ValueError("Understat supports competition IDs 8, 82, 301, 384, 564")
    where = ""
    params = list(ids)
    if season_name is not None:
        season_start_year(season_name)
        where = " AND name = %s"
        params.append(season_name)
    rows = fetch_all(f"""
        SELECT competition_id, season_id, name FROM seasons
        WHERE competition_id IN ({','.join('%s' for _ in ids)})
          AND name >= '2017/2018' {where}
        ORDER BY name, competition_id
    """, tuple(params))
    if not rows:
        raise ValueError(f"No DB seasons found: {season_name}, {ids}")
    return [dict(zip(("competition_id", "season_id", "name"), row)) for row in rows]


def load_external_ids(entity: str) -> dict[str, int]:
    # 호출자는 팀·선수·경기 세 종류만 사용해요. Capology와 같은 공급자별 ID 계약이에요.
    if entity not in {"team", "player", "fixture"}:
        raise ValueError(entity)
    return {str(external): internal for external, internal in fetch_all(
        f"SELECT external_{entity}_id, {entity}_id FROM {entity}_external_ids WHERE provider='understat'"
    )}


def load_player_observations(season_id: int) -> list[dict]:
    # 24/25 Stansfield·Gollini는 DB 시즌 스쿼드에서 빠졌지만 실제 라인업에 있어요.
    # 과거 경기 매핑은 재계산한 스쿼드뿐 아니라 확인된 출전 명단도 사용해요.
    rows = fetch_all("""
        SELECT m.team_id, t.name, m.player_id, p.display_name, p.full_name
        FROM team_squad_members m JOIN teams t ON t.team_id=m.team_id
        JOIN players p ON p.player_id=m.player_id
        WHERE m.season_id=%s
        UNION
        SELECT l.team_id, t.name, l.player_id, p.display_name, p.full_name
        FROM fixture_lineups l JOIN fixtures f ON f.fixture_id=l.fixture_id
        JOIN stages st ON st.stage_id=f.stage_id
        JOIN teams t ON t.team_id=l.team_id JOIN players p ON p.player_id=l.player_id
        WHERE st.season_id=%s
        ORDER BY team_id, player_id
    """, (season_id, season_id))
    return [dict(zip(("team_id", "team_name", "player_id", "display_name", "full_name"), r)) for r in rows]


def load_mapping_fixtures(season_id: int) -> list[dict]:
    rows = fetch_all("""
        SELECT f.fixture_id, f.home_team_id, f.away_team_id, f.starting_at
        FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
        WHERE st.season_id=%s ORDER BY f.starting_at, f.fixture_id
    """, (season_id,))
    return [dict(zip(("fixture_id", "home_team_id", "away_team_id", "starting_at"), r)) for r in rows]


def write_understat_report(kind: str, payload: dict) -> Path:
    directory = Path(__file__).resolve().parents[3] / "logs" / "diagnostics"
    directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    path = directory / f"understat_{kind}_{stamp}.json"
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    return path
