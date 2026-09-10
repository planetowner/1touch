from __future__ import annotations

from datetime import date

from ...core.transfer_team_levels import load_senior_team_ids
from ...core.transfer_source_rules import WITHHELD_PLAYER_MOVEMENTS
from ..db import fetch_all_dict


TRANSFER_COLUMNS = """
tr.transfer_id, tr.player_id, p.display_name AS player_name, p.image_path AS player_image,
       tr.from_team_id, ft.name AS from_team_name, ft.image_path AS from_team_image,
       tr.to_team_id, tt.name AS to_team_name, tt.image_path AS to_team_image,
       tr.type_id, ty.name AS type_name, tr.amount, tr.transfer_date
"""
TRANSFER_FROM = """
FROM transfers tr
JOIN players p ON p.player_id=tr.player_id
JOIN transfer_types ty ON ty.type_id=tr.type_id
LEFT JOIN teams ft ON ft.team_id=tr.from_team_id
LEFT JOIN teams tt ON tt.team_id=tr.to_team_id
"""


def get_team_transfers_by_window(team_id: int, season_id: int, window: dict, as_of: date) -> list[dict]:
    # 계약 시작과 이적 날짜는 달라질 수 있어요. 원문 관계 ID가 없으면 날짜로 추정하지 않아요.
    rows = fetch_all_dict(f"SELECT {TRANSFER_COLUMNS}, c.start_date AS contract_start_date, c.end_date AS contract_end_date, sm.jersey_number {TRANSFER_FROM}" + """
        LEFT JOIN player_contracts c ON c.transfer_id=tr.transfer_id AND c.player_id=tr.player_id AND c.team_id=tr.to_team_id
        LEFT JOIN team_squad_members sm ON sm.player_id=tr.player_id AND sm.team_id=%s AND sm.season_id=%s
        WHERE (tr.from_team_id=%s OR tr.to_team_id=%s) AND tr.transfer_date BETWEEN %s AND %s
        ORDER BY tr.transfer_date DESC, tr.transfer_id DESC
    """, (team_id, season_id, team_id, team_id, window["start_date"], min(as_of, window["end_date"])))
    # 원문·계약은 저장하지만 웹 대조 뒤에도 불확실한 선수의 이적 카드는 표시하지 않아요.
    return [row for row in rows if row["player_id"] not in WITHHELD_PLAYER_MOVEMENTS]


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


def get_player_club_history(player_id: int, as_of: date) -> dict:
    if player_id in WITHHELD_PLAYER_MOVEMENTS:
        return {"player_id": player_id, "clubs": []}
    rows = fetch_all_dict(f"SELECT {TRANSFER_COLUMNS} {TRANSFER_FROM}" + """
        WHERE tr.player_id=%s AND tr.transfer_date<=%s ORDER BY tr.transfer_date, tr.transfer_id
    """, (player_id, as_of))
    return {"player_id": player_id, "clubs": build_club_history(rows, load_senior_team_ids())}
