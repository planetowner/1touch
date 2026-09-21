from __future__ import annotations

from datetime import date

from ...core.player_membership import build_club_history
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


def get_player_club_history(player_id: int, as_of: date, *, query=None) -> dict:
    if player_id in WITHHELD_PLAYER_MOVEMENTS:
        return {"player_id": player_id, "clubs": []}
    fetch = query or fetch_all_dict
    rows = fetch(f"SELECT {TRANSFER_COLUMNS} {TRANSFER_FROM}" + """
        WHERE tr.player_id=%s AND tr.transfer_date<=%s ORDER BY tr.transfer_date, tr.transfer_id
    """, (player_id, as_of))
    # 선수 상세에서는 같은 읽기 전용 연결을 공유해 원격 DB 재연결을 줄여요.
    senior_ids = load_senior_team_ids(query=lambda sql: [(row['team_id'],) for row in fetch(sql)]) if query else load_senior_team_ids()
    return {"player_id": player_id, "clubs": build_club_history(rows, senior_ids)}
