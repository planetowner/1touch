"""스쿼드와 이적 이력이 같은 시즌 경계·소속 기간 규칙을 사용해요."""
from __future__ import annotations

from datetime import date
import re


def season_start_date(season_name: str) -> date:
    match = re.fullmatch(r"(\d{4})/(\d{4})", season_name)
    if match is None:
        raise ValueError(f"Unsupported season name: {season_name!r}")

    start_year = int(match.group(1))
    end_year = int(match.group(2))
    if end_year != start_year + 1:
        raise ValueError(f"Unsupported season year range: {season_name!r}")

    return date(start_year, 7, 1)


def build_club_history(rows: list[dict], senior_ids: set[int]) -> list[dict]:
    # start_date·end_date는 이적 원문의 합류·이탈 날짜이며 계약 시작·종료일이 아니에요.
    # De Gea의 맨유 이탈(2023-07-01)과 Fiorentina 합류(2024-08-09)는 별도 행이에요.
    # 다음 팀 입단일로 이전 기간을 메우지 않고 해당 출발팀의 이탈 기록만 사용해요.
    history, open_spells = [], {}
    for row in rows:
        from_id, to_id = row["from_team_id"], row["to_team_id"]
        # Becker의 Mainz 임대→완전 이적은 복귀 행 없이 같은 출발·도착팀을 반환해요.
        # 이미 그 팀에 소속된 기간을 이어가며 원소속팀에 새 소속 기간을 만들지 않아요.
        if to_id in open_spells and row["type_id"] == 219:
            continue
        if from_id is not None:
            spell = open_spells.pop(from_id, None)
            if spell is None:
                # Griezmann의 Real Sociedad 입단일은 원문에 없어요. 이적일로 시작일을 만들지 않아요.
                spell = {"team_id": from_id, "team_name": row["from_team_name"], "team_image": row["from_team_image"], "start_date": None}
                history.append(spell)
            spell["end_date"] = row["transfer_date"]
        if to_id is not None:
            if to_id not in open_spells:
                spell = {"team_id": to_id, "team_name": row["to_team_name"], "team_image": row["to_team_image"],
                         "start_date": row["transfer_date"], "end_date": None}
                history.append(spell)
                open_spells[to_id] = spell
    # 종료일 NULL은 확인된 이탈 기록이 없다는 뜻이에요. 현재 소속을 확정하는 플래그는 아니에요.
    # 먼저 전체 이동으로 기간을 닫아요. 미분류·2군을 숨겨도 앞뒤 1군 기간을 합치지 않아요.
    return [spell for spell in reversed(history) if spell["team_id"] in senior_ids]
