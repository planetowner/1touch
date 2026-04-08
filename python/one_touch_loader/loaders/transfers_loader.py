from __future__ import annotations

from datetime import date, timedelta
from typing import Dict, List, Optional, Tuple

from ..core.db import fetch_all, upsert_many
from ..core.sportmonks import SportmonksClient


# ---------------------------------------------------------------------------
# SQL: common
# ---------------------------------------------------------------------------

SQL_SELECT_CURRENT_TEAM_IDS = """
SELECT DISTINCT team_id
FROM (
  SELECT f.home_team_id AS team_id
  FROM fixtures f
  JOIN seasons s ON s.season_id = f.season_id
  WHERE s.is_current = 1

  UNION

  SELECT f.away_team_id AS team_id
  FROM fixtures f
  JOIN seasons s ON s.season_id = f.season_id
  WHERE s.is_current = 1
) t
WHERE team_id IS NOT NULL
ORDER BY team_id
"""

# ---------------------------------------------------------------------------
# SQL: transfer_windows
# ---------------------------------------------------------------------------

SQL_RESOLVE_LATEST_WINDOW = """
SELECT id, season_year, window_name, start_date, end_date
FROM transfer_windows
WHERE start_date <= CURDATE()
ORDER BY start_date DESC
LIMIT 1
"""

SQL_UPDATE_LATEST_FLAGS = """
UPDATE transfer_windows
SET is_latest = IF(id = %s, 1, 0),
    is_active = IF(CURDATE() BETWEEN start_date AND end_date, 1, 0)
"""

# ---------------------------------------------------------------------------
# SQL: team_transfers
# ---------------------------------------------------------------------------

SQL_UPSERT_TRANSFER = """
INSERT INTO team_transfers (
  transfer_id, player_id, player_name, player_image,
  from_team_id, from_team_name, to_team_id, to_team_name,
  type_id, type_name, amount, transfer_date, window_id
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  player_name    = VALUES(player_name),
  player_image   = VALUES(player_image),
  from_team_id   = VALUES(from_team_id),
  from_team_name = VALUES(from_team_name),
  to_team_id     = VALUES(to_team_id),
  to_team_name   = VALUES(to_team_name),
  type_id        = VALUES(type_id),
  type_name      = VALUES(type_name),
  amount         = VALUES(amount),
  transfer_date  = VALUES(transfer_date),
  window_id      = VALUES(window_id)
"""

# ---------------------------------------------------------------------------
# SQL: team_squad (별도 적재용 — 추후 선수 목록 등에 활용)
# ---------------------------------------------------------------------------

SQL_UPSERT_SQUAD = """
INSERT INTO team_squad (
  team_id, player_id, player_name, transfer_id,
  position_id, position_name, jersey_number,
  start_date, end_date
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  player_name   = VALUES(player_name),
  transfer_id   = VALUES(transfer_id),
  position_id   = VALUES(position_id),
  position_name = VALUES(position_name),
  jersey_number = VALUES(jersey_number),
  start_date    = VALUES(start_date),
  end_date      = VALUES(end_date)
"""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _safe_int(v) -> Optional[int]:
    try:
        return int(v) if v is not None else None
    except Exception:
        return None


def _player_name(player: Dict) -> Optional[str]:
    if not player:
        return None
    return (
        player.get("display_name")
        or player.get("common_name")
        or player.get("name")
    )


def _player_image(player: Dict) -> Optional[str]:
    if not player:
        return None
    return player.get("image_path")


# ---------------------------------------------------------------------------
# Window resolution
# ---------------------------------------------------------------------------

def resolve_latest_window() -> Optional[Dict]:
    """
    start_date <= 오늘 인 윈도우 중 가장 최근 것을 latest로 설정.
    아직 시작하지 않은 미래 윈도우는 제외.
    """
    row = fetch_all(SQL_RESOLVE_LATEST_WINDOW)
    if not row:
        return None
    wid, season_year, window_name, start_date, end_date = row[0]

    upsert_many(SQL_UPDATE_LATEST_FLAGS, [(wid,)])

    return {
        "id": wid,
        "season_year": season_year,
        "window_name": window_name,
        "start_date": start_date,
        "end_date": end_date,
    }


# ---------------------------------------------------------------------------
# Filter & Normalize
# ---------------------------------------------------------------------------

def _filter_by_window(transfers: List[Dict], window: Dict) -> List[Dict]:
    """윈도우 기간 ±7일 이내의 이적만 필터링."""
    margin = timedelta(days=7)
    win_start = window["start_date"] - margin
    win_end = window["end_date"] + margin
    filtered = []
    for t in transfers:
        raw = t.get("date")
        if not raw:
            continue
        try:
            td = date.fromisoformat(str(raw)[:10])
        except (ValueError, TypeError):
            continue
        if win_start <= td <= win_end:
            filtered.append(t)
    return filtered


def _normalize_transfer_rows(
    transfers: List[Dict],
    window_id: int,
) -> List[Tuple]:
    rows: List[Tuple] = []
    for t in transfers:
        tid = _safe_int(t.get("id"))
        if tid is None:
            continue

        player = t.get("player") or {}
        from_team = t.get("fromteam") or t.get("fromTeam") or {}
        to_team = t.get("toteam") or t.get("toTeam") or {}
        type_obj = t.get("type") or {}

        rows.append((
            tid,
            _safe_int(t.get("player_id")),
            _player_name(player),
            _player_image(player),
            _safe_int(t.get("from_team_id")),
            from_team.get("name"),
            _safe_int(t.get("to_team_id")),
            to_team.get("name"),
            _safe_int(t.get("type_id")),
            type_obj.get("name"),
            _safe_int(t.get("amount")),
            t.get("date"),
            window_id,
        ))
    return rows


def _normalize_squad_rows(team_id: int, squad: List[Dict]) -> List[Tuple]:
    rows: List[Tuple] = []
    for s in squad:
        player_id = _safe_int(s.get("player_id"))
        if player_id is None:
            continue

        player = s.get("player") or {}
        position = s.get("position") or {}

        rows.append((
            team_id,
            player_id,
            _player_name(player),
            _safe_int(s.get("transfer_id")),
            _safe_int(position.get("id") if position else s.get("position_id")),
            position.get("name"),
            _safe_int(s.get("jersey_number")),
            s.get("start") or s.get("start_date"),
            s.get("end") or s.get("end_date"),
        ))
    return rows


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def refresh_team_transfers(team_id: int, window: Optional[Dict] = None) -> None:
    """
    단일 팀의 transfer 데이터를 fetch 후 latest window 기간으로 필터링하여 upsert.
    """
    if window is None:
        window = resolve_latest_window()
    if window is None:
        print(f"[transfers] team {team_id}: SKIP - no transfer window configured")
        return

    sm = SportmonksClient()
    all_transfers = list(sm.iter_transfers_by_team(team_id))
    transfers = _filter_by_window(all_transfers, window)

    rows = _normalize_transfer_rows(transfers, window["id"])
    if rows:
        upsert_many(SQL_UPSERT_TRANSFER, rows)

    print(
        f"[transfers] team {team_id}: "
        f"fetched={len(all_transfers)} filtered={len(transfers)} upserted={len(rows)}"
    )


def refresh_team_squad(team_id: int) -> None:
    """단일 팀의 squad만 별도 적재."""
    sm = SportmonksClient()
    squad = sm.get_team_squad(team_id)

    if not squad:
        print(f"[squad] team {team_id}: empty response from API")
        return

    rows = _normalize_squad_rows(team_id, squad)
    if rows:
        upsert_many(SQL_UPSERT_SQUAD, rows)

    print(f"[squad] team {team_id}: fetched={len(squad)} normalized={len(rows)}")


def refresh_current_transfers(team_ids: Optional[List[int]] = None) -> None:
    """
    Big5 전체 또는 지정된 팀들의 transfer 데이터를 일괄 적재.
    latest window 기간의 이적만 로드.
    """
    window = resolve_latest_window()
    if not window:
        print("[transfers] ERROR: no transfer window found. Seed transfer_windows first.")
        return

    print(
        f"[transfers] latest window: "
        f"{window['season_year']} {window['window_name']} "
        f"({window['start_date']} ~ {window['end_date']})"
    )

    ids = team_ids or [int(row[0]) for row in fetch_all(SQL_SELECT_CURRENT_TEAM_IDS)]
    total = 0

    for tid in ids:
        refresh_team_transfers(tid, window=window)
        total += 1

    print(f"[transfers] refresh-current done: teams={total}")
