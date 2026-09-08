"""전역 ``teams`` 마스터를 한 가지 분명한 규칙으로 수집해요.

CLI 사용법::

# 지원하는 모든 대회의 2017/2018 이후 전체 시즌을 수집해요.
    python -m one_touch_loader.cli teams all

    # 정확한 시즌 이름과 competition_id 하나를 골라 수집해요.
    python -m one_touch_loader.cli teams "2025/2026" 8
    python -m one_touch_loader.cli teams "2024/2025" 570

수집 규칙은 다음과 같아요.

* 사용자는 season_id가 아닌 시즌 이름을 입력해요. 로더는 선택한 대회 안에서 이름이
  정확히 같은 공급자 season_id를 찾아요. 같은 이름이 없으면 실패하며, 가까운 시즌이나
  현재 시즌을 추측하지 않아요.
* 일반 대회는 ``teams/seasons/{season_id}``가 반환한 실제 팀을 모두 수집해요.
  placeholder는 제외해요.
* FA컵(24)과 카라바오컵(27)은 같은 시즌 프리미어리그(8) 팀이 포함된 경기만 봐요.
  코파 이탈리아(390)는 세리에 A(384), 코파 델 레이(570)는 라리가(564)를 기준으로 해요.
* 네 컵대회는 기준 리그 팀 가운데 컵에 참가한 팀(n)과, 확인된 과거·예정 컵 경기에서
  만난 상대 팀(m)을 합쳐 중복 없이 수집해요. 기준 리그 팀과 무관한 경기는 제외해요.
* ``placeholder=true``는 아직 팀이 정해지지 않은 자리라 실제 구단이 아니에요.
  ``teams``에 넣지 않아요. 공급자가 실제 팀으로 바꾸거나 새 경기를 공개한 뒤 다시
  실행하면 그 팀을 수집해요.
* 이 모듈은 ``teams``만 써요. ``team_seasons``를 쓰지 않고, 대회·시즌·경기·유럽대항전·
  컵대회 로더를 자동으로 실행하지 않아요.
* ``teams all``은 한 시즌·한 대회 수집을 정해진 순서대로 반복할 뿐이에요.
  별도의 bootstrap 동작은 없어요.
"""

from __future__ import annotations

from typing import Dict, List, Optional, Set, Tuple

from ..core.db import upsert_many
from ..core.sportmonks import SportmonksClient


# 지원 범위를 코드에 명시해요. 공급자 응답만 보고 대회를 자동으로 늘리지 않아요.
SUPPORTED_COMPETITION_IDS = (2, 5, 8, 24, 27, 82, 301, 384, 390, 564, 570, 2286)
MIN_SEASON_START_YEAR = 2017

# 아래 컵대회는 같은 이름의 시즌에서 대응하는 자국 리그 팀이 포함된 경기만 수집해요.
CUP_BASE_COMPETITION_IDS = {
    24: 8,
    27: 8,
    390: 384,
    570: 564,
}

SQL_UPSERT_TEAM = """
INSERT INTO teams (team_id, name, short_code, image_path)
VALUES (%s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  short_code = VALUES(short_code),
  image_path = VALUES(image_path)
"""

TeamRow = Tuple[int, str, Optional[str], Optional[str]]
SeasonCache = Dict[int, Dict[str, Dict]]


def _require_non_empty_string(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string field: {field_name}")
    return value.strip()


def _optional_string(value, field_name: str) -> Optional[str]:
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError(f"Invalid optional string field: {field_name}")
    return value


def _is_placeholder(team: Dict, field_name: str) -> bool:
    value = team.get("placeholder")
    if type(value) is not bool:
        raise ValueError(f"Missing or invalid boolean field: {field_name}.placeholder")
    return value


def _team_row(team: Dict, field_name: str) -> TeamRow:
    if not isinstance(team, dict):
        raise ValueError(f"Expected object: {field_name}")

    team_id = team.get("id")
    if type(team_id) is not int:
        raise ValueError(f"Missing or invalid integer field: {field_name}.id")

    return (
        team_id,
        _require_non_empty_string(team.get("name"), f"{field_name}.name"),
        _optional_string(team.get("short_code"), f"{field_name}.short_code"),
        _optional_string(team.get("image_path"), f"{field_name}.image_path"),
    )


def _season_start_year(season_name: str) -> int:
    parts = season_name.split("/", 1)
    if len(parts) != 2:
        raise ValueError(f"Unsupported season name: {season_name!r}")

    try:
        start_year = int(parts[0])
        end_year = int(parts[1])
    except ValueError as exc:
        raise ValueError(f"Unsupported season name: {season_name!r}") from exc

    if end_year != start_year + 1:
        raise ValueError(f"Unsupported season name: {season_name!r}")
    return start_year


def _seasons_by_name(
    sm: SportmonksClient,
    competition_id: int,
    cache: SeasonCache,
) -> Dict[str, Dict]:
    cached = cache.get(competition_id)
    if cached is not None:
        return cached

    competition = sm.get_league_with_seasons(competition_id)
    seasons = competition.get("seasons")
    if not isinstance(seasons, list):
        raise ValueError(
            f"Expected seasons list for competition_id={competition_id}."
        )

    by_name: Dict[str, Dict] = {}
    for index, season in enumerate(seasons):
        if not isinstance(season, dict):
            raise ValueError(
                f"Expected season object: competition_id={competition_id}, "
                f"index={index}."
            )

        season_id = season.get("id")
        if type(season_id) is not int:
            raise ValueError(
                f"Invalid season id: competition_id={competition_id}, "
                f"index={index}, id={season_id!r}."
            )

        season_name = _require_non_empty_string(
            season.get("name"),
            f"competition[{competition_id}].seasons[{index}].name",
        )
        by_name[season_name] = season

    cache[competition_id] = by_name
    return by_name


def _resolve_season(
    sm: SportmonksClient,
    competition_id: int,
    season_name: str,
    cache: SeasonCache,
) -> Dict:
    seasons = _seasons_by_name(sm, competition_id, cache)
    season = seasons.get(season_name)
    if season is None:
        raise ValueError(
            f"Season {season_name!r} was not found for "
            f"competition_id={competition_id}."
        )
    return season


def _collect_all_season_participants(
    sm: SportmonksClient,
    season: Dict,
) -> Tuple[Dict[int, TeamRow], Dict[str, int | str]]:
    season_id = int(season["id"])
    rows_by_id: Dict[int, TeamRow] = {}
    provider_rows = 0
    placeholders = 0

    for index, team in enumerate(sm.iter_teams_by_season(season_id)):
        provider_rows += 1
        field_name = f"teams/seasons/{season_id}.data[{index}]"
        if _is_placeholder(team, field_name):
            placeholders += 1
            continue
        row = _team_row(team, field_name)
        rows_by_id[row[0]] = row

    return rows_by_id, {
        "collection_strategy": "season_participants",
        "provider_team_rows": provider_rows,
        "skipped_placeholders": placeholders,
    }


def _domestic_league_team_ids(
    sm: SportmonksClient,
    season: Dict,
) -> Tuple[Set[int], int]:
    season_id = int(season["id"])
    team_ids: Set[int] = set()
    placeholders = 0

    for index, team in enumerate(sm.iter_teams_by_season(season_id)):
        field_name = f"teams/seasons/{season_id}.data[{index}]"
        if _is_placeholder(team, field_name):
            placeholders += 1
            continue
        row = _team_row(team, field_name)
        team_ids.add(row[0])

    return team_ids, placeholders


def _collect_related_cup_fixture_teams(
    sm: SportmonksClient,
    cup_season: Dict,
    base_competition_id: int,
    base_season: Dict,
) -> Tuple[Dict[int, TeamRow], Dict[str, int | str]]:
    cup_season_id = int(cup_season["id"])
    base_team_ids, base_placeholders = _domestic_league_team_ids(
        sm,
        base_season,
    )
    rows_by_id: Dict[int, TeamRow] = {}
    fixture_rows = 0
    matched_fixture_rows = 0
    placeholder_participant_rows = 0

    for fixture in sm.iter_fixtures_by_season(
        cup_season_id,
        include="participants",
    ):
        fixture_rows += 1
        actual_rows: List[TeamRow] = []
        actual_team_ids: Set[int] = set()

        for participant_index, participant in enumerate(fixture["participants"]):
            field_name = (
                f"fixture[{fixture.get('id')!r}].participants[{participant_index}]"
            )
            if _is_placeholder(participant, field_name):
                placeholder_participant_rows += 1
                continue

            row = _team_row(participant, field_name)
            actual_rows.append(row)
            actual_team_ids.add(row[0])

    # 제품 규칙에 맞는 경기만 남겨요. 홈팀이나 원정팀 중 하나 이상이
    # 같은 이름의 시즌에 대응하는 자국 리그 소속이어야 해요.
        if not actual_team_ids.intersection(base_team_ids):
            continue

        matched_fixture_rows += 1
        for row in actual_rows:
            rows_by_id[row[0]] = row

    collected_ids = set(rows_by_id)
    selected_base_team_ids = collected_ids.intersection(base_team_ids)
    opponent_team_ids = collected_ids - base_team_ids

    return rows_by_id, {
        "collection_strategy": "domestic_cup_fixtures_related_to_base_league",
        "base_competition_id": base_competition_id,
        "base_league_team_count": len(base_team_ids),
        "base_league_skipped_placeholders": base_placeholders,
        "provider_fixture_rows": fixture_rows,
        "matched_fixture_rows": matched_fixture_rows,
        "selected_base_league_team_count": len(selected_base_team_ids),
        "opponent_team_count": len(opponent_team_ids),
        "skipped_placeholder_participant_rows": placeholder_participant_rows,
    }


def _collect_and_upsert(
    sm: SportmonksClient,
    cache: SeasonCache,
    season_name: str,
    competition_id: int,
) -> Dict[str, object]:
    """한 시즌·한 대회를 수집하는 기준 작업을 실행해요."""
    if competition_id not in SUPPORTED_COMPETITION_IDS:
        raise ValueError(
            f"Unsupported competition_id={competition_id}. "
            f"Allowed ids: {list(SUPPORTED_COMPETITION_IDS)}"
        )

    season_name = _require_non_empty_string(season_name, "season_name")
    season_start_year = _season_start_year(season_name)
    if season_start_year < MIN_SEASON_START_YEAR:
        raise ValueError(
            f"Season {season_name!r} is before the supported minimum "
            f"2017/2018."
        )
    season = _resolve_season(sm, competition_id, season_name, cache)

    base_competition_id = CUP_BASE_COMPETITION_IDS.get(competition_id)
    if base_competition_id is None:
        rows_by_id, details = _collect_all_season_participants(
            sm,
            season,
        )
    else:
        base_season = _resolve_season(
            sm,
            base_competition_id,
            season_name,
            cache,
        )
        rows_by_id, details = _collect_related_cup_fixture_teams(
            sm,
            season,
            base_competition_id,
            base_season,
        )

    rows = [rows_by_id[team_id] for team_id in sorted(rows_by_id)]
    if rows:
        upsert_many(SQL_UPSERT_TEAM, rows)

    result: Dict[str, object] = {
        "competition_id": competition_id,
        "season_name": season_name,
        "season_id": int(season["id"]),
        "upserted_team_count": len(rows),
    }
    result.update(details)

    print(
        f"[teams] competition_id={competition_id} "
        f"season={season_name} upserted={len(rows)}"
    )
    return result


def collect_teams_for_competition_season(
    season_name: str,
    competition_id: int,
) -> Dict[str, object]:
    """지원 대회 하나에서 이름이 정확히 같은 시즌의 팀을 수집해요."""
    return _collect_and_upsert(
        sm=SportmonksClient(),
        cache={},
        season_name=season_name,
        competition_id=competition_id,
    )


def collect_all_teams() -> Dict[str, object]:
    """2017/2018 이후에 실제로 존재하는 시즌·대회 조합마다 단일 수집을 반복해요.

    시즌 시작 연도순으로 실행하고, 같은 시즌에서는 위에 명시한 대회 순서를 따라요.
    과거에 아직 없던 대회는 조합을 억지로 만들지 않고 건너뛰어요.
    """
    sm = SportmonksClient()
    cache: SeasonCache = {}
    results: List[Dict[str, object]] = []
    competition_order = {
        competition_id: index
        for index, competition_id in enumerate(SUPPORTED_COMPETITION_IDS)
    }
    collection_scope: List[Tuple[int, int, str]] = []

    for competition_id in SUPPORTED_COMPETITION_IDS:
        seasons = _seasons_by_name(sm, competition_id, cache)
        for season_name in seasons:
            start_year = _season_start_year(season_name)
            if start_year >= MIN_SEASON_START_YEAR:
                collection_scope.append(
                    (start_year, competition_id, season_name)
                )

    collection_scope.sort(
        key=lambda item: (
            item[0],
            competition_order[item[1]],
            int(cache[item[1]][item[2]]["id"]),
        )
    )

    for _, competition_id, season_name in collection_scope:
        results.append(
            _collect_and_upsert(
                sm=sm,
                cache=cache,
                season_name=season_name,
                competition_id=competition_id,
            )
        )

    return {
        "mode": "all_seasons_all_competitions",
        "minimum_season_start_year": MIN_SEASON_START_YEAR,
        "competition_ids": list(SUPPORTED_COMPETITION_IDS),
        "collection_runs": len(results),
        "results": results,
    }
