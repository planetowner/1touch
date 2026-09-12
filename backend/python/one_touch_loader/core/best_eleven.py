"""Best Eleven의 자리 정의와 선수 선정 규칙을 관리해요."""
from __future__ import annotations

import numpy as np
from scipy.optimize import linear_sum_assignment


def order_formations(matches_used: dict[str, int]) -> list[str]:
    """사용 횟수가 같으면 이름순으로 고정해 계산과 두 화면의 기본 선택을 맞춰요."""
    return sorted(matches_used, key=lambda name: (-matches_used[name], name))


def formation_slots(formation: str) -> list[str]:
    """공급자의 행:열 자리에서 1행은 골키퍼, 2행부터는 포메이션 숫자 순서예요."""
    slots = ["1:1"]
    for row, count in enumerate(formation.split("-"), start=2):
        slots.extend(f"{row}:{column}" for column in range(1, int(count) + 1))
    if len(slots) != 11:
        raise ValueError(f"Formation must contain 11 slots: {formation!r}")
    return slots


def _maximum_starts(starts: np.ndarray) -> int:
    """모든 자리를 채우는 최대 선발 횟수 합을 구해요. 배정 불가능은 -1이에요."""
    if starts.shape[0] == 0:
        return 0
    if starts.shape[0] > starts.shape[1]:
        return -1

    # 선발 기록이 없는 자리에는 배정할 수 없어요. 벌점을 가능한 전체 합보다 크게
    # 두면, 선발 횟수가 높다는 이유로 기록 없는 자리를 선택하는 일을 막을 수 있어요.
    penalty = int(starts.max(axis=1).sum()) + 1
    weights = np.where(starts > 0, starts, -penalty)
    rows, columns = linear_sum_assignment(weights, maximize=True)
    selected = starts[rows, columns]
    return int(selected.sum()) if np.all(selected > 0) else -1


def select_players(
    slots: list[str], starts_by_slot_player: dict[tuple[str, int], int],
) -> list[tuple[str, int, int]]:
    """서로 다른 선수로 모든 자리를 채우고, 해당 자리 선발 횟수 합을 최대화해요.

    SciPy의 Jonker–Volgenant 선형 배정 알고리즘으로 전체 조합을 비교해요.
    앞자리를 먼저 채우던 방식은
    25/26 웨스트햄처럼 두 선수의 자리만 바꿔도 선발 횟수 합이 늘어나는 경우를 놓쳤어요.
    출전 시간은 미제공 경기가 있어 비교에 쓰지 않고 원본 라인업에만 보존해요.
    """
    player_ids = sorted({player_id for _, player_id in starts_by_slot_player})
    starts = np.array([
        [starts_by_slot_player.get((slot, player_id), 0) for player_id in player_ids]
        for slot in slots
    ], dtype=np.int64)
    remaining_score = _maximum_starts(starts)
    if remaining_score < 0:
        raise ValueError("Cannot assign a different starting player to every slot")

    # 최대 합이 같은 조합만 남기면서, 자리 순서대로 가장 작은 선수 ID를 확정해요.
    # 라이브러리의 동점 처리나 입력 행 순서가 달라져도 같은 11명을 반환하기 위해서예요.
    available = list(range(len(player_ids)))
    selected = []
    for row, slot in enumerate(slots):
        for column in available:
            appearances = int(starts[row, column])
            if appearances == 0:
                continue
            remaining = [index for index in available if index != column]
            next_score = _maximum_starts(starts[row + 1:, remaining])
            if next_score >= 0 and appearances + next_score == remaining_score:
                selected.append((slot, player_ids[column], appearances))
                available = remaining
                remaining_score = next_score
                break
    return selected
