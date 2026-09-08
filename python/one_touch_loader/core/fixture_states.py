from __future__ import annotations

from typing import Optional


UPCOMING_STATE_IDS = (1, 10, 13, 16)
LIVE_STATE_IDS = (2, 3, 4, 6, 9, 11, 18, 21, 22, 23, 25)
PAST_STATE_IDS = (5, 7, 8, 14, 15, 17)

# 경기 결과와 통계를 정상 완료 경기로 계산할 수 있는 상태만 포함해요.
COMPLETED_STATE_IDS = (5, 7, 8)

SCREEN_STATUS_STATE_IDS = {
    "upcoming": UPCOMING_STATE_IDS,
    "live": LIVE_STATE_IDS,
    "past": PAST_STATE_IDS,
}


def screen_status_for_state_id(state_id: int) -> Optional[str]:
    for screen_status, state_ids in SCREEN_STATUS_STATE_IDS.items():
        if state_id in state_ids:
            return screen_status
    return None


def state_ids_for_screen_status(screen_status: str) -> tuple[int, ...]:
    try:
        return SCREEN_STATUS_STATE_IDS[screen_status]
    except KeyError as exc:
        raise ValueError(
            "screen_status must be one of: upcoming, live, past"
        ) from exc
