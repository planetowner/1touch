from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Dict, List, Optional, Set, Tuple

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
    AND f.competition_type = 'league'
    AND f.league_id IN (8,82,301,384,564)

  UNION

  SELECT f.away_team_id AS team_id
  FROM fixtures f
  JOIN seasons s ON s.season_id = f.season_id
  WHERE s.is_current = 1
    AND f.competition_type = 'league'
    AND f.league_id IN (8,82,301,384,564)
) t
WHERE team_id IS NOT NULL
ORDER BY team_id
"""

# ---------------------------------------------------------------------------
# SQL: transfer_windows
# ---------------------------------------------------------------------------

SQL_RESOLVE_FLAGGED_LATEST_WINDOW = """
SELECT
  id,
  season_year,
  window_name,
  start_date,
  end_date,
  effective_start_date,
  effective_end_date,
  latest_detection_source
FROM transfer_windows
WHERE is_latest = 1
LIMIT 2
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
# Strict helpers
# ---------------------------------------------------------------------------

def _require_int(value, field_name: str) -> int:
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer field: {field_name}={value!r}")

    return value


def _require_optional_int(value, field_name: str) -> Optional[int]:
    if value is None:
        return None

    if type(value) is not int:
        raise ValueError(f"Invalid optional integer field: {field_name}={value!r}")

    return value


def _require_non_empty_str(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string field: {field_name}={value!r}")

    return value.strip()


def _require_optional_str(value, field_name: str) -> Optional[str]:
    if value is None:
        return None

    if not isinstance(value, str):
        raise ValueError(f"Invalid optional string field: {field_name}={value!r}")

    return value


def _require_dict(value, field_name: str) -> Dict:
    if not isinstance(value, dict):
        raise ValueError(f"Missing or invalid object field: {field_name}={value!r}")

    return value


def _date_from_db(value, field_name: str) -> date:
    if isinstance(value, datetime):
        return value.date()

    if type(value) is date:
        return value

    raise ValueError(f"Missing or invalid DB date field: {field_name}={value!r}")


def _require_transfer_date_for_filter(value, transfer_id: int) -> date:
    # Verified against a deadline-week sample (2,203 transfers, 457 Big5-related):
    # Sportmonks always populates transfer.date. It is required, not optional —
    # a null-date transfer must surface, not be silently dropped from the
    # window filter (which would lose a Big5 transfer the user should see).
    if not isinstance(value, str) or not value.strip():
        raise ValueError(
            f"Missing or invalid transfer date for transfer_id={transfer_id}: {value!r}"
        )

    return date.fromisoformat(value)


def _require_transfer_date_str(value, transfer_id: int) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(
            f"Missing or invalid transfer date for transfer_id={transfer_id}: {value!r}"
        )

    date.fromisoformat(value)
    return value


def _is_big5_related_transfer(transfer: Dict, big5_team_ids: Set[int]) -> bool:
    from_team_id = _require_int(
        transfer["from_team_id"],
        "transfer.from_team_id",
    )
    to_team_id = _require_optional_int(
        transfer["to_team_id"],
        "transfer.to_team_id",
    )

    return from_team_id in big5_team_ids or to_team_id in big5_team_ids


def _required_team_name_from_object(
    team_obj: Dict,
    expected_team_id: int,
    object_field_name: str,
) -> str:
    team_obj = _require_dict(team_obj, object_field_name)
    object_team_id = _require_int(team_obj["id"], f"{object_field_name}.id")

    if object_team_id != expected_team_id:
        raise ValueError(
            f"Team id mismatch for {object_field_name}: "
            f"expected={expected_team_id!r}, object.id={object_team_id!r}"
        )

    return _require_non_empty_str(team_obj["name"], f"{object_field_name}.name")


def _optional_team_name_from_object(
    team_obj,
    expected_team_id: Optional[int],
    object_field_name: str,
) -> Optional[str]:
    if expected_team_id is None:
        if team_obj is not None:
            raise ValueError(
                f"{object_field_name} object exists but expected team id is None: "
                f"{team_obj!r}"
            )

        return None

    if team_obj is None:
        raise ValueError(
            f"{object_field_name} is None but expected team id is {expected_team_id!r}"
        )

    return _required_team_name_from_object(
        team_obj,
        expected_team_id,
        object_field_name,
    )


# ---------------------------------------------------------------------------
# Team scope
# ---------------------------------------------------------------------------

def get_current_big5_domestic_team_ids() -> List[int]:
    rows = fetch_all(SQL_SELECT_CURRENT_TEAM_IDS)
    return [_require_int(row[0], "current_big5_team_id") for row in rows]


# ---------------------------------------------------------------------------
# Window resolution
# ---------------------------------------------------------------------------

def resolve_latest_window() -> Optional[Dict]:
    """
    DB에 저장된 latest/effective window만 읽는다.
    Sportmonks API를 호출하지 않는다.
    """
    # is_latest=1 has only a plain index, no uniqueness constraint, so check
    # cardinality explicitly: 0 -> None, 1 -> it, >=2 -> surface as an error.
    rows = fetch_all(SQL_RESOLVE_FLAGGED_LATEST_WINDOW)

    if not rows:
        return None

    if len(rows) > 1:
        raise ValueError(
            f"transfer_windows has multiple is_latest=1 rows: "
            f"{[int(r[0]) for r in rows]}"
        )

    (
        window_id,
        season_year,
        window_name,
        start_date,
        end_date,
        effective_start_date,
        effective_end_date,
        detection_source,
    ) = rows[0]

    if effective_start_date is None:
        raise ValueError(
            "Latest transfer window is missing effective_start_date. "
            "Run transfers refresh-current to detect and persist it."
        )

    if effective_end_date is None:
        raise ValueError(
            "Latest transfer window is missing effective_end_date. "
            "Run transfers refresh-current to detect and persist it."
        )

    if detection_source is None:
        raise ValueError(
            "Latest transfer window is missing latest_detection_source. "
            "Run transfers refresh-current to detect and persist it."
        )

    return {
        "id": _require_int(window_id, "transfer_windows.id"),
        "season_year": _require_int(season_year, "transfer_windows.season_year"),
        "window_name": _require_non_empty_str(
            window_name,
            "transfer_windows.window_name",
        ),
        "start_date": _date_from_db(start_date, "transfer_windows.start_date"),
        "end_date": _date_from_db(end_date, "transfer_windows.end_date"),
        "effective_start_date": _date_from_db(
            effective_start_date,
            "transfer_windows.effective_start_date",
        ),
        "effective_end_date": _date_from_db(
            effective_end_date,
            "transfer_windows.effective_end_date",
        ),
        "detection_source": _require_non_empty_str(
            detection_source,
            "transfer_windows.latest_detection_source",
        ),
    }


# ---------------------------------------------------------------------------
# Filter & normalize
# ---------------------------------------------------------------------------

def _filter_by_window(
    transfers: List[Dict],
    window: Dict,
    big5_team_ids: Set[int],
) -> List[Dict]:
    effective_start_date = _date_from_db(
        window["effective_start_date"],
        "window.effective_start_date",
    )
    effective_end_date = _date_from_db(
        window["effective_end_date"],
        "window.effective_end_date",
    )

    filtered: List[Dict] = []

    for transfer in transfers:
        transfer_id = _require_int(transfer["id"], "transfer.id")

        transfer_date = _require_transfer_date_for_filter(
            transfer["date"],
            transfer_id,
        )

        if not (effective_start_date <= transfer_date <= effective_end_date):
            continue

        if not _is_big5_related_transfer(transfer, big5_team_ids):
            continue

        filtered.append(transfer)

    return filtered


def _normalize_transfer_rows(
    transfers: List[Dict],
    window_id: int,
) -> List[Tuple]:
    rows: List[Tuple] = []

    for transfer in transfers:
        transfer_id = _require_int(transfer["id"], "transfer.id")
        player_id = _require_int(transfer["player_id"], "transfer.player_id")
        from_team_id = _require_int(transfer["from_team_id"], "transfer.from_team_id")
        to_team_id = _require_optional_int(transfer["to_team_id"], "transfer.to_team_id")
        type_id = _require_int(transfer["type_id"], "transfer.type_id")
        amount = _require_optional_int(transfer["amount"], "transfer.amount")
        transfer_date = _require_transfer_date_str(transfer["date"], transfer_id)

        player = _require_dict(transfer["player"], "transfer.player")
        type_obj = _require_dict(transfer["type"], "transfer.type")

        player_id_from_player = _require_int(player["id"], "transfer.player.id")
        type_id_from_type = _require_int(type_obj["id"], "transfer.type.id")

        if player_id_from_player != player_id:
            raise ValueError(
                f"Player id mismatch for transfer_id={transfer_id}: "
                f"transfer.player_id={player_id!r}, player.id={player_id_from_player!r}"
            )

        if type_id_from_type != type_id:
            raise ValueError(
                f"Type id mismatch for transfer_id={transfer_id}: "
                f"transfer.type_id={type_id!r}, type.id={type_id_from_type!r}"
            )

        from_team_name = _required_team_name_from_object(
            transfer["fromteam"],
            from_team_id,
            "transfer.fromteam",
        )

        to_team_name = _optional_team_name_from_object(
            transfer["toteam"],
            to_team_id,
            "transfer.toteam",
        )

        rows.append(
            (
                transfer_id,
                player_id,
                _require_non_empty_str(
                    player["display_name"],
                    "transfer.player.display_name",
                ),
                _require_optional_str(
                    player["image_path"],
                    "transfer.player.image_path",
                ),
                from_team_id,
                from_team_name,
                to_team_id,
                to_team_name,
                type_id,
                _require_non_empty_str(type_obj["name"], "transfer.type.name"),
                amount,
                transfer_date,
                window_id,
            )
        )

    return rows


# ---------------------------------------------------------------------------
# Shared refresh implementation
# ---------------------------------------------------------------------------

def _iter_date_chunks(
    start_date: date,
    end_date: date,
    *,
    max_days: int = 31,
):
    if end_date < start_date:
        raise ValueError(
            f"Invalid date range: start_date={start_date}, end_date={end_date}"
        )

    current = start_date

    while current <= end_date:
        chunk_end = min(
            current + timedelta(days=max_days - 1),
            end_date,
        )

        yield current, chunk_end

        current = chunk_end + timedelta(days=1)


def _load_transfers_for_window(
    *,
    sm: SportmonksClient,
    window: Dict,
) -> List[Dict]:
    effective_start_date = _date_from_db(
        window["effective_start_date"],
        "window.effective_start_date",
    )
    effective_end_date = _date_from_db(
        window["effective_end_date"],
        "window.effective_end_date",
    )

    transfers: List[Dict] = []
    seen_transfer_ids: Set[int] = set()

    for chunk_start, chunk_end in _iter_date_chunks(
        effective_start_date,
        effective_end_date,
    ):
        chunk_rows = list(
            sm.iter_transfers_between_dates(
                chunk_start,
                chunk_end,
            )
        )

        print(
            f"[transfers] between {chunk_start} ~ {chunk_end}: "
            f"fetched={len(chunk_rows)}"
        )

        for transfer in chunk_rows:
            transfer_id = _require_int(transfer["id"], "transfer.id")

            if transfer_id in seen_transfer_ids:
                continue

            seen_transfer_ids.add(transfer_id)
            transfers.append(transfer)

    print(f"[transfers] window fetched total={len(transfers)}")

    return transfers


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def refresh_team_transfers(team_id: int) -> None:
    """
    단일 Big5 current domestic team의 latest transfer window 데이터를 적재.
    transfers/teams/{team_id} 전체 이력을 쓰지 않는다.
    """
    sm = SportmonksClient()
    big5_team_ids = set(get_current_big5_domestic_team_ids())

    if team_id not in big5_team_ids:
        raise ValueError(
            f"team_id={team_id} is not a Big5 current domestic team."
        )

    window = resolve_latest_window()

    if window is None:
        raise ValueError(
            "No transfer window found (transfer_windows has no is_latest=1 row). "
            "Seed transfer_windows or run transfers refresh-current first."
        )

    all_transfers = _load_transfers_for_window(
        sm=sm,
        window=window,
    )

    transfers = _filter_by_window(
        all_transfers,
        window,
        {team_id},
    )

    rows = _normalize_transfer_rows(
        transfers,
        _require_int(window["id"], "window.id"),
    )

    if rows:
        upsert_many(SQL_UPSERT_TRANSFER, rows)

    print(
        f"[transfers] team {team_id}: "
        f"filtered={len(transfers)} upserted={len(rows)}"
    )


def refresh_current_transfers(team_ids: Optional[List[int]] = None) -> None:
    """
    Big5 current domestic teams 또는 지정된 Big5 팀들의 latest transfer window 데이터를 적재.

    transfers/teams/{team_id} 전체 이력을 쓰지 않는다.
    transfer_windows.effective_start_date ~ effective_end_date를
    31일 단위로 쪼개서 transfers/between/{start}/{end}로 가져온다.
    """
    sm = SportmonksClient()
    big5_team_ids = set(get_current_big5_domestic_team_ids())

    if not big5_team_ids:
        raise ValueError("No Big5 current domestic team ids found.")

    if team_ids is None:
        target_team_ids = big5_team_ids
    else:
        invalid_ids = sorted(set(team_ids) - big5_team_ids)

        if invalid_ids:
            raise ValueError(
                f"These team_ids are not Big5 current domestic teams: {invalid_ids}"
            )

        target_team_ids = set(team_ids)

    window = resolve_latest_window()

    if window is None:
        raise ValueError(
            "No transfer window found (transfer_windows has no is_latest=1 row). "
            "Seed transfer_windows first."
        )

    print(
        f"[transfers] latest window: "
        f"{window['season_year']} {window['window_name']} "
        f"official=({window['start_date']} ~ {window['end_date']}) "
        f"effective=({window['effective_start_date']} ~ {window['effective_end_date']}) "
        f"source={window['detection_source']}"
    )

    all_transfers = _load_transfers_for_window(
        sm=sm,
        window=window,
    )

    transfers = _filter_by_window(
        all_transfers,
        window,
        target_team_ids,
    )

    rows = _normalize_transfer_rows(
        transfers,
        _require_int(window["id"], "window.id"),
    )

    if rows:
        upsert_many(SQL_UPSERT_TRANSFER, rows)

    print(
        f"[transfers] refresh-current done: "
        f"target_teams={len(target_team_ids)} "
        f"filtered={len(transfers)} "
        f"upserted={len(rows)}"
    )