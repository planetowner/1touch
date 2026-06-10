from __future__ import annotations

import json
from typing import Dict, List, Optional, Tuple

from ..core.db import fetch_all, upsert_many
from ..core.sportmonks import SportmonksClient


BIG5_LEAGUE_IDS = (8, 82, 301, 384, 564)


# =========================================================
# SQL
# =========================================================

SQL_SELECT_FIXTURE_META_BY_ID = """
SELECT
    f.fixture_id,
    f.season_id,
    f.league_id,
    f.home_team_id,
    f.away_team_id,
    f.status
FROM fixtures f
WHERE f.fixture_id = %s
"""

SQL_SELECT_FIXTURE_IDS_BY_SEASON = """
SELECT
    f.fixture_id
FROM fixtures f
WHERE f.season_id = %s
ORDER BY f.starting_at, f.fixture_id
"""

SQL_SELECT_FIXTURE_IDS_BY_SEASON_AND_STATUS = """
SELECT
    f.fixture_id
FROM fixtures f
WHERE f.season_id = %s
  AND f.status = %s
ORDER BY f.starting_at, f.fixture_id
"""

SQL_SELECT_CURRENT_BIG5_SEASON_IDS = """
SELECT s.season_id
FROM seasons s
WHERE s.is_current = 1
  AND s.league_id IN (8,82,301,384,564)
ORDER BY s.league_id, s.season_id
"""

SQL_UPSERT_FIXTURE_TEAM_STAT_RAW = """
INSERT INTO fixture_team_stats_raw (
  fixture_id,
  season_id,
  league_id,
  team_id,
  opponent_team_id,
  location,
  stat_type_id,
  stat_code,
  stat_name,
  stat_value_num,
  raw_data_json,
  collected_at
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW())
ON DUPLICATE KEY UPDATE
  season_id        = VALUES(season_id),
  league_id        = VALUES(league_id),
  opponent_team_id = VALUES(opponent_team_id),
  location         = VALUES(location),
  stat_type_id     = VALUES(stat_type_id),
  stat_name        = VALUES(stat_name),
  stat_value_num   = VALUES(stat_value_num),
  raw_data_json    = VALUES(raw_data_json),
  collected_at     = VALUES(collected_at)
"""


# =========================================================
# strict helpers
# =========================================================

def _require_int(value, field_name: str) -> int:
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer field: {field_name}={value!r}")

    return value


def _require_number(value, field_name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"Missing or invalid numeric field: {field_name}={value!r}")

    return float(value)


def _require_non_empty_str(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string field: {field_name}={value!r}")

    return value.strip()


def _require_dict(value, field_name: str) -> Dict:
    if not isinstance(value, dict):
        raise ValueError(f"Missing or invalid object field: {field_name}={value!r}")

    return value


def _require_list(value, field_name: str) -> List:
    if not isinstance(value, list):
        raise ValueError(f"Missing or invalid list field: {field_name}={value!r}")

    return value


def _require_location(value, field_name: str) -> str:
    value = _require_non_empty_str(value, field_name)

    if value not in {"home", "away"}:
        raise ValueError(f"Invalid location field: {field_name}={value!r}")

    return value


def _fixture_meta_from_row(row: Tuple) -> Dict:
    fixture_id, season_id, league_id, home_team_id, away_team_id, status = row

    return {
        "fixture_id": _require_int(fixture_id, "fixtures.fixture_id"),
        "season_id": _require_int(season_id, "fixtures.season_id"),
        "league_id": _require_int(league_id, "fixtures.league_id"),
        "home_team_id": _require_int(home_team_id, "fixtures.home_team_id"),
        "away_team_id": _require_int(away_team_id, "fixtures.away_team_id"),
        "status": _require_non_empty_str(status, "fixtures.status"),
    }


def _require_fixture_payload_matches_db(fixture_meta: Dict, fixture_payload: Dict) -> None:
    payload_fixture_id = _require_int(fixture_payload["id"], "fixture_payload.id")
    payload_season_id = _require_int(fixture_payload["season_id"], "fixture_payload.season_id")
    payload_league_id = _require_int(fixture_payload["league_id"], "fixture_payload.league_id")

    if payload_fixture_id != fixture_meta["fixture_id"]:
        raise ValueError(
            f"Fixture id mismatch: DB={fixture_meta['fixture_id']!r}, "
            f"payload={payload_fixture_id!r}"
        )

    if payload_season_id != fixture_meta["season_id"]:
        raise ValueError(
            f"Season id mismatch for fixture_id={fixture_meta['fixture_id']}: "
            f"DB={fixture_meta['season_id']!r}, payload={payload_season_id!r}"
        )

    if payload_league_id != fixture_meta["league_id"]:
        raise ValueError(
            f"League id mismatch for fixture_id={fixture_meta['fixture_id']}: "
            f"DB={fixture_meta['league_id']!r}, payload={payload_league_id!r}"
        )


def _participant_locations_from_payload(
    *,
    fixture_meta: Dict,
    fixture_payload: Dict,
) -> Dict[int, str]:
    participants = _require_list(
        fixture_payload["participants"],
        "fixture_payload.participants",
    )

    if len(participants) != 2:
        raise ValueError(
            f"Expected exactly 2 participants for fixture_id={fixture_meta['fixture_id']}, "
            f"got {len(participants)}"
        )

    locations_by_team_id: Dict[int, str] = {}

    for index, participant_raw in enumerate(participants):
        participant = _require_dict(
            participant_raw,
            f"fixture_payload.participants[{index}]",
        )

        participant_id = _require_int(
            participant["id"],
            f"fixture_payload.participants[{index}].id",
        )

        meta = _require_dict(
            participant["meta"],
            f"fixture_payload.participants[{index}].meta",
        )

        location = _require_location(
            meta["location"],
            f"fixture_payload.participants[{index}].meta.location",
        )

        if participant_id not in {
            fixture_meta["home_team_id"],
            fixture_meta["away_team_id"],
        }:
            raise ValueError(
                f"Participant id is not DB home/away team for "
                f"fixture_id={fixture_meta['fixture_id']}: participant_id={participant_id!r}, "
                f"home_team_id={fixture_meta['home_team_id']!r}, "
                f"away_team_id={fixture_meta['away_team_id']!r}"
            )

        expected_location = (
            "home"
            if participant_id == fixture_meta["home_team_id"]
            else "away"
        )

        if location != expected_location:
            raise ValueError(
                f"Participant location mismatch for fixture_id={fixture_meta['fixture_id']}: "
                f"participant_id={participant_id!r}, "
                f"payload_location={location!r}, expected_location={expected_location!r}"
            )

        locations_by_team_id[participant_id] = location

    if set(locations_by_team_id.keys()) != {
        fixture_meta["home_team_id"],
        fixture_meta["away_team_id"],
    }:
        raise ValueError(
            f"Participants do not exactly match DB home/away teams for "
            f"fixture_id={fixture_meta['fixture_id']}: "
            f"participants={sorted(locations_by_team_id.keys())}, "
            f"expected={sorted([fixture_meta['home_team_id'], fixture_meta['away_team_id']])}"
        )

    return locations_by_team_id


def _stat_value_from_data(data: Dict, fixture_id: int, stat_id: int) -> float:
    keys = set(data.keys())

    if keys != {"value"}:
        raise ValueError(
            f"Unexpected stat data keys for fixture_id={fixture_id}, "
            f"stat_id={stat_id}: keys={sorted(keys)}"
        )

    return _require_number(
        data["value"],
        f"fixture_payload.statistics[].data.value fixture_id={fixture_id} stat_id={stat_id}",
    )


def _normalize_rows_from_fixture_payload(
    fixture_meta_row: Tuple,
    fixture_payload: Dict,
) -> List[Tuple]:
    fixture_meta = _fixture_meta_from_row(fixture_meta_row)
    fixture_payload = _require_dict(fixture_payload, "fixture_payload")

    _require_fixture_payload_matches_db(fixture_meta, fixture_payload)
    _participant_locations_from_payload(
        fixture_meta=fixture_meta,
        fixture_payload=fixture_payload,
    )

    statistics = _require_list(
        fixture_payload["statistics"],
        "fixture_payload.statistics",
    )

    if not statistics:
        raise ValueError(
            f"No statistics returned for fixture_id={fixture_meta['fixture_id']}"
        )

    rows: List[Tuple] = []

    for index, stat_raw in enumerate(statistics):
        stat = _require_dict(
            stat_raw,
            f"fixture_payload.statistics[{index}]",
        )

        stat_id = _require_int(
            stat["id"],
            f"fixture_payload.statistics[{index}].id",
        )

        stat_fixture_id = _require_int(
            stat["fixture_id"],
            f"fixture_payload.statistics[{index}].fixture_id",
        )

        if stat_fixture_id != fixture_meta["fixture_id"]:
            raise ValueError(
                f"Statistic fixture_id mismatch: expected={fixture_meta['fixture_id']!r}, "
                f"got={stat_fixture_id!r}, stat_id={stat_id!r}"
            )

        participant_id = _require_int(
            stat["participant_id"],
            f"fixture_payload.statistics[{index}].participant_id",
        )

        if participant_id == fixture_meta["home_team_id"]:
            team_id = fixture_meta["home_team_id"]
            opponent_team_id = fixture_meta["away_team_id"]
            expected_location = "home"
        elif participant_id == fixture_meta["away_team_id"]:
            team_id = fixture_meta["away_team_id"]
            opponent_team_id = fixture_meta["home_team_id"]
            expected_location = "away"
        else:
            raise ValueError(
                f"Statistic participant_id is not DB home/away team for "
                f"fixture_id={fixture_meta['fixture_id']}: participant_id={participant_id!r}"
            )

        stat_location = _require_location(
            stat["location"],
            f"fixture_payload.statistics[{index}].location",
        )

        if stat_location != expected_location:
            raise ValueError(
                f"Statistic location mismatch for fixture_id={fixture_meta['fixture_id']}, "
                f"stat_id={stat_id}: payload_location={stat_location!r}, "
                f"expected_location={expected_location!r}"
            )

        stat_type_id = _require_int(
            stat["type_id"],
            f"fixture_payload.statistics[{index}].type_id",
        )

        type_obj = _require_dict(
            stat["type"],
            f"fixture_payload.statistics[{index}].type",
        )

        type_obj_id = _require_int(
            type_obj["id"],
            f"fixture_payload.statistics[{index}].type.id",
        )

        if type_obj_id != stat_type_id:
            raise ValueError(
                f"Statistic type id mismatch for fixture_id={fixture_meta['fixture_id']}, "
                f"stat_id={stat_id}: type_id={stat_type_id!r}, "
                f"type.id={type_obj_id!r}"
            )

        stat_code = _require_non_empty_str(
            type_obj["code"],
            f"fixture_payload.statistics[{index}].type.code",
        )

        stat_name = _require_non_empty_str(
            type_obj["name"],
            f"fixture_payload.statistics[{index}].type.name",
        )

        data = _require_dict(
            stat["data"],
            f"fixture_payload.statistics[{index}].data",
        )

        stat_value_num = _stat_value_from_data(
            data,
            fixture_meta["fixture_id"],
            stat_id,
        )

        rows.append(
            (
                fixture_meta["fixture_id"],
                fixture_meta["season_id"],
                fixture_meta["league_id"],
                team_id,
                opponent_team_id,
                stat_location,
                stat_type_id,
                stat_code,
                stat_name,
                stat_value_num,
                json.dumps(data, ensure_ascii=False, sort_keys=True),
            )
        )

    return rows


# =========================================================
# public functions
# =========================================================

def refresh_fixture_team_stats(fixture_id: int) -> None:
    fixture_rows = fetch_all(SQL_SELECT_FIXTURE_META_BY_ID, (fixture_id,))

    if not fixture_rows:
        raise ValueError(f"Fixture not found in DB: fixture_id={fixture_id}")

    fixture_meta = fixture_rows[0]

    sm = SportmonksClient()
    fixture_payload = sm.get_fixture_with_statistics(fixture_id)

    rows = _normalize_rows_from_fixture_payload(fixture_meta, fixture_payload)

    upsert_many(SQL_UPSERT_FIXTURE_TEAM_STAT_RAW, rows)

    print(
        f"[team-stats] fixture {fixture_id}: "
        f"normalized_rows={len(rows)}"
    )


def refresh_fixture_team_stats_for_season(
    season_id: int,
    only_status: Optional[str] = None,
) -> None:
    if only_status is None:
        fixture_rows = fetch_all(
            SQL_SELECT_FIXTURE_IDS_BY_SEASON,
            (season_id,),
        )
    else:
        fixture_rows = fetch_all(
            SQL_SELECT_FIXTURE_IDS_BY_SEASON_AND_STATUS,
            (season_id, only_status),
        )

    fixture_ids = [_require_int(row[0], "fixture_id") for row in fixture_rows]

    total = 0

    for fixture_id in fixture_ids:
        refresh_fixture_team_stats(fixture_id)
        total += 1

    print(
        f"[team-stats] season {season_id}: "
        f"fixtures_processed={total} "
        f"status_filter={only_status or 'ALL'}"
    )


def refresh_fixture_team_stats_for_current_seasons(
    only_status: Optional[str] = "past",
) -> None:
    season_rows = fetch_all(SQL_SELECT_CURRENT_BIG5_SEASON_IDS)
    season_ids = [_require_int(row[0], "current_big5_season_id") for row in season_rows]

    if not season_ids:
        raise RuntimeError("No current Big5 season IDs found.")

    total_seasons = 0

    for season_id in season_ids:
        refresh_fixture_team_stats_for_season(
            season_id,
            only_status=only_status,
        )
        total_seasons += 1

    print(
        f"[team-stats] current Big5 seasons refresh done: "
        f"seasons={total_seasons} status_filter={only_status or 'ALL'}"
    )