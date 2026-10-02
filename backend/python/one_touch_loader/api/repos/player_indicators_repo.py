"""미리 계산한 선수 한 명의 지표와 최신 팀 내 역할을 조회해요."""

from __future__ import annotations

from ..db import fetch_one_dict
from ...core.db_json import decoded
from ...core.player_rating_percentile import RATING_COMPETITION_IDS


class IndicatorsNotReadyError(RuntimeError):
    """현재 소속의 첫 계산이 아직 저장되지 않았어요."""


def get_current_player_indicators(player_id: int) -> dict | None:
    row = fetch_one_dict(
        f"""
        SELECT i.payload, sm.squad_role
        FROM team_squad_members sm
        JOIN seasons s ON s.season_id=sm.season_id
        LEFT JOIN player_indicator_snapshots i ON i.player_id=sm.player_id
             AND i.team_id=sm.team_id AND i.season_id=sm.season_id
        WHERE sm.player_id=%s AND s.is_current=1
          AND s.competition_id IN ({",".join(map(str, RATING_COMPETITION_IDS))})
        ORDER BY sm.team_id DESC, sm.season_id DESC LIMIT 1
    """,
        (player_id,),
    )
    if row is None:
        return None
    if row["payload"] is None:
        raise IndicatorsNotReadyError(
            "Current player indicators have not been calculated yet"
        )
    # 역할 변경은 모델 입력이 아니에요. 점수를 다시 계산하지 않고 최신 값을 보여 줘요.
    return {**decoded(row["payload"]), "squad_role": row["squad_role"]}
