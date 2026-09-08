from __future__ import annotations

from collections import defaultdict
from datetime import date
from typing import DefaultDict, Dict, List, Optional, Set, Tuple

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient
from .team_squad_members_loader import (
    load_squad_scope,
    reconstruct_team_season_squad,
)


SQL_INSERT_PLAYER = """
INSERT INTO players (
  player_id,
  display_name,
  full_name,
  position_id,
  nationality_id,
  date_of_birth,
  height_cm,
  weight_kg,
  image_path
)
VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
"""

SQL_UPSERT_PLAYER = SQL_INSERT_PLAYER + """
ON DUPLICATE KEY UPDATE
  display_name   = VALUES(display_name),
  full_name      = VALUES(full_name),
  position_id    = VALUES(position_id),
  nationality_id = VALUES(nationality_id),
  date_of_birth  = VALUES(date_of_birth),
  height_cm      = VALUES(height_cm),
  weight_kg      = VALUES(weight_kg),
  image_path     = VALUES(image_path)
"""

SQL_UPSERT_SPORTMONKS_PLAYER_ID = """
INSERT INTO player_external_ids (
  player_id,
  provider,
  external_player_id
)
VALUES (%s,'sportmonks',%s)
ON DUPLICATE KEY UPDATE
  external_player_id = VALUES(external_player_id)
"""

SQL_SELECT_POSITION_IDS = "SELECT position_id FROM positions ORDER BY position_id"
SQL_SELECT_COUNTRY_IDS = "SELECT country_id FROM countries ORDER BY country_id"

SPORTMONKS_NON_PLAYING_DETAILED_POSITION_IDS = {221, 226, 227}
# Sportmonks가 일부 선수 이름에 다른 선수 정보를 보내서 확정한 이름으로 바꿔요.
SPORTMONKS_PLAYER_DISPLAY_NAME_OVERRIDES = {
    1101: "Robbie Brady",
    1384: "Billy Sharp",
    4764: "Roberto Pereyra",
    33587: "Jeremy Dudziak",
    34777: "Saulo Decarli",
    95661: "Gaëtan Charbonnier",
    129225: "Simone Verdi",
    169484: "Aleksandr Kokorin",
    186345: "Yoel Rodríguez",
    186733: "Germán Pezzella",
    3526289: "Brice Tutu",
    37612429: "Matteo Fiorenza",
}
SPORTMONKS_PLAYER_FULL_NAME_OVERRIDES = {
    186733: "Germán Alejo Pezzella",
    6974589: "Nazim Babaï",
    7745874: "Iker Álvarez de Eulate Molné",
    29720457: "Hugo Burcio García",
    37316544: "Pedro Alemañ Serna",
    37607269: "Jacopo Grossi",
    37615677: "Amine Salama",
    37676379: "Vicent Abril Sanz",
}
def _audit_optional_int(value, field_name: str) -> Optional[int]:
    if value is None:
        return None
    if type(value) is not int:
        raise ValueError(f"Invalid integer: {field_name}={value!r}")
    return value


def _audit_optional_string(value, field_name: str) -> Optional[str]:
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError(f"Invalid string: {field_name}={value!r}")
    return value


def _audit_squad_observation(
    item,
    scope: Dict[str, object],
    index: int,
) -> Dict[str, object]:
    if not isinstance(item, dict):
        raise ValueError(f"Invalid squad item: squad[{index}]={item!r}")

    player_id = item.get("player_id")
    if type(player_id) is not int:
        raise ValueError(f"Invalid player_id: squad[{index}].player_id={player_id!r}")

    player = item.get("player")
    if not isinstance(player, dict):
        raise ValueError(f"Invalid player object: squad[{index}].player={player!r}")

    position_id = item.get("detailed_position_id")
    if position_id is None:
        position_id = player.get("detailed_position_id")

    return {
        "player_id": player_id,
        "common_name": _audit_optional_string(
            player.get("common_name"), f"squad[{index}].player.common_name"
        ),
        "firstname": _audit_optional_string(
            player.get("firstname"), f"squad[{index}].player.firstname"
        ),
        "lastname": _audit_optional_string(
            player.get("lastname"), f"squad[{index}].player.lastname"
        ),
        "full_name": _audit_optional_string(
            player.get("name"), f"squad[{index}].player.name"
        ),
        "display_name": _audit_optional_string(
            player.get("display_name"), f"squad[{index}].player.display_name"
        ),
        "position_id": _audit_optional_int(
            position_id, f"squad[{index}].Sportmonks detailed_position_id"
        ),
        "position_group_id": _audit_optional_int(
            item.get("position_id"), f"squad[{index}].position_id"
        ),
        "nationality_id": _audit_optional_int(
            player.get("nationality_id"), f"squad[{index}].player.nationality_id"
        ),
        "date_of_birth": _audit_optional_string(
            player.get("date_of_birth"), f"squad[{index}].player.date_of_birth"
        ),
        "height_cm": _audit_optional_int(
            player.get("height"), f"squad[{index}].player.height"
        ),
        "weight_kg": _audit_optional_int(
            player.get("weight"), f"squad[{index}].player.weight"
        ),
        "image_path": _audit_optional_string(
            player.get("image_path"), f"squad[{index}].player.image_path"
        ),
        "scope": {
            "competition_id": scope["competition_id"],
            "season_id": scope["season_id"],
            "season_name": scope["season_name"],
            "is_current": scope["is_current"],
            "team_id": scope["team_id"],
            "team_name": scope["team_name"],
        },
    }


def _audit_direct_player_profile(
    raw_player,
    requested_player_id: int,
) -> Dict[str, object]:
    if not isinstance(raw_player, dict):
        raise ValueError(f"Invalid player response: {raw_player!r}")
    return {
        "player_id": requested_player_id,
        "common_name": _audit_optional_string(
            raw_player.get("common_name"), "player.common_name"
        ),
        "firstname": _audit_optional_string(
            raw_player.get("firstname"), "player.firstname"
        ),
        "lastname": _audit_optional_string(
            raw_player.get("lastname"), "player.lastname"
        ),
        "full_name": _audit_optional_string(
            raw_player.get("name"), "player.name"
        ),
        "display_name": _audit_optional_string(
            raw_player.get("display_name"), "player.display_name"
        ),
        "position_id": _audit_optional_int(
            raw_player.get("detailed_position_id"),
            "player.detailed_position_id",
        ),
        "position_group_id": _audit_optional_int(
            raw_player.get("position_id"), "player.position_id"
        ),
        "nationality_id": _audit_optional_int(
            raw_player.get("nationality_id"), "player.nationality_id"
        ),
        "date_of_birth": _audit_optional_string(
            raw_player.get("date_of_birth"), "player.date_of_birth"
        ),
        "height_cm": _audit_optional_int(
            raw_player.get("height"), "player.height"
        ),
        "weight_kg": _audit_optional_int(
            raw_player.get("weight"), "player.weight"
        ),
        "image_path": _audit_optional_string(
            raw_player.get("image_path"), "player.image_path"
        ),
    }


def _required_profile_string(
    profile: Dict[str, object],
    field_name: str,
) -> str:
    value = profile.get(field_name)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(
            f"Missing or invalid player profile string: {field_name}={value!r}"
        )
    return value.strip()


def _merge_embedded_player_profiles(
    player_id: int,
    profiles: List[Dict[str, object]],
) -> Dict[str, object]:
    if not profiles:
        raise ValueError(f"Missing embedded squad profile: player_id={player_id}")

    merged: Dict[str, object] = {"player_id": player_id}
    fields = (
        "full_name",
        "display_name",
        "nationality_id",
        "date_of_birth",
        "height_cm",
        "weight_kg",
        "image_path",
    )
    for field_name in fields:
        merged[field_name] = next(
            (
                profile[field_name]
                for profile in profiles
                if profile.get(field_name) is not None
            ),
            None,
        )

    # 전체 스쿼드 감사에서 한 선수의 non-null 세부 포지션 ID는 모든 출현에서 같았어요.
    merged["position_id"] = next(
        (
            int(profile["position_id"])
            for profile in profiles
            if profile.get("position_id") is not None
        ),
        None,
    )
    return merged


def _resolve_player_position_id(
    primary_profile: Dict[str, object],
    embedded_profiles: List[Dict[str, object]],
    known_position_ids: Set[int],
    primary_source: str,
) -> Tuple[Optional[int], str]:
    primary_position_id = primary_profile.get("position_id")
    if (
        type(primary_position_id) is int
        and primary_position_id in known_position_ids
    ):
        return primary_position_id, primary_source

    embedded_position_id = next(
        (
            int(profile["position_id"])
            for profile in embedded_profiles
            if type(profile.get("position_id")) is int
            and int(profile["position_id"]) in known_position_ids
        ),
        None,
    )
    if embedded_position_id is not None:
        return embedded_position_id, "squad_profile"

    # 라인업과 선수 시즌 통계에는 일반 포지션만 있어 세부 포지션을 확정할 수 없어요.
    # formation_field를 세부 포지션으로 바꾸는 추측도 하지 않고 NULL로 남겨요.
    return None, "unavailable"


def _build_player_row(
    primary_profile: Dict[str, object],
    embedded_profiles: List[Dict[str, object]],
    known_position_ids: Set[int],
    primary_source: str,
) -> Tuple[Tuple, Dict[str, object]]:
    player_id = primary_profile.get("player_id")
    if type(player_id) is not int:
        raise ValueError(f"Missing or invalid player_id: {player_id!r}")

    full_name = _required_profile_string(primary_profile, "full_name")
    display_name = _required_profile_string(primary_profile, "display_name")
    provider_detailed_position_id = primary_profile.get("position_id")
    corrected_display_name = False

    overridden_full_name = SPORTMONKS_PLAYER_FULL_NAME_OVERRIDES.get(player_id)
    if overridden_full_name is not None:
        full_name = overridden_full_name

    overridden_display_name = SPORTMONKS_PLAYER_DISPLAY_NAME_OVERRIDES.get(player_id)
    if overridden_display_name is not None:
        corrected_display_name = display_name != overridden_display_name
        display_name = overridden_display_name
    # Sportmonks 일부 과거 선수는 이름 필드 대부분은 선수 본인인데 display_name과
    # detailed_position_id만 코치·스태프 값으로 섞여 와요. 다른 사람 이름이 화면에
    # 노출되지 않도록 이 세 값에서는 검증된 full_name을 display_name으로 써요.
    elif provider_detailed_position_id in SPORTMONKS_NON_PLAYING_DETAILED_POSITION_IDS:
        corrected_display_name = display_name != full_name
        display_name = full_name

    position_id, position_source = _resolve_player_position_id(
        primary_profile,
        embedded_profiles,
        known_position_ids,
        primary_source,
    )
    row = (
        player_id,
        display_name,
        full_name,
        position_id,
        primary_profile.get("nationality_id"),
        primary_profile.get("date_of_birth"),
        primary_profile.get("height_cm"),
        primary_profile.get("weight_kg"),
        primary_profile.get("image_path"),
    )
    return row, {
        "profile_source": primary_source,
        "position_source": position_source,
        "corrected_display_name": corrected_display_name,
    }


def _write_player_rows(cursor, player_rows: List[Tuple], *, update_existing: bool) -> None:
    external_id_rows = [(row[0], str(row[0])) for row in player_rows]
    if player_rows:
        cursor.executemany(SQL_UPSERT_PLAYER if update_existing else SQL_INSERT_PLAYER, player_rows)
        cursor.executemany(SQL_UPSERT_SPORTMONKS_PLAYER_ID, external_id_rows)


def _upsert_player_rows(player_rows: List[Tuple]) -> int:
    with transaction() as connection:
        with connection.cursor() as cursor:
            _write_player_rows(cursor, player_rows, update_existing=True)

    return len(player_rows)


def insert_missing_player_profiles(cursor, profiles: Dict[int, Dict]) -> int:
    if not profiles:
        return 0
    placeholders = ",".join("%s" for _ in profiles)
    cursor.execute(
        f"SELECT player_id FROM players WHERE player_id IN ({placeholders})",
        tuple(profiles),
    )
    existing_ids = {row[0] for row in cursor.fetchall()}
    missing_ids = profiles.keys() - existing_ids
    if not missing_ids:
        return 0
    cursor.execute(SQL_SELECT_POSITION_IDS)
    known_position_ids = {row[0] for row in cursor.fetchall()}
    # 기존 선수 27393의 스쿼드 보완 포지션이 라인업 프로필에서는 NULL이었어요.
    # 경기 수집은 누락 선수만 추가하고, 기존 프로필 갱신은 players 로더가 맡아요.
    # FA컵 19645311의 누락 선수 20명은 단건·내장 프로필의 저장 필드가 같았어요.
    player_rows = [
        _build_player_row(
            _audit_direct_player_profile(profiles[player_id], player_id),
            [],
            known_position_ids,
            "fixture_profile",
        )[0]
        for player_id in sorted(missing_ids)
    ]
    _write_player_rows(cursor, player_rows, update_existing=False)
    return len(player_rows)


def _collect_scope(
    season_name: Optional[str] = None,
    competition_id: Optional[int] = None,
) -> Dict[str, object]:
    scope = load_squad_scope(
        season_name=season_name,
        competition_id=competition_id,
    )
    sm = SportmonksClient()
    today = date.today()
    transfers_by_team: Dict[int, List[Dict]] = {}
    completed: List[Dict[str, object]] = []
    scope_failures: List[Dict[str, object]] = []
    embedded_profiles_by_player: DefaultDict[
        int, List[Dict[str, object]]
    ] = defaultdict(list)

    for index, scope_item in enumerate(scope, start=1):
        team_id = int(scope_item["team_id"])
        season_id = int(scope_item["season_id"])
        try:
            if team_id not in transfers_by_team:
                transfers_by_team[team_id] = list(
                    sm.iter_transfers_by_team(team_id)
                )

            reconstructed_squad, result = reconstruct_team_season_squad(
                sm,
                scope_item,
                transfers_by_team[team_id],
                today,
            )
            team_profiles: List[Dict[str, object]] = []
            for squad_index, squad_item in enumerate(reconstructed_squad):
                profile = _audit_squad_observation(
                    squad_item,
                    scope_item,
                    squad_index,
                )
                team_profiles.append(profile)

            for profile in team_profiles:
                embedded_profiles_by_player[int(profile["player_id"])].append(
                    profile
                )
            result["selected_players"] = len(team_profiles)
            completed.append(result)
            # PowerShell CP949 로그가 유니코드 팀명 때문에 중단되지 않도록 ID만 표시해요.
            print(
                f"[players {index}/{len(scope)}] "
                f"{scope_item['season_name']} team_id={team_id}: "
                f"mode={result['mode']} raw={result['raw_squad_members']} "
                f"selected={len(team_profiles)}"
            )
        except ValueError as exc:
            failure = {
                **scope_item,
                "error_type": type(exc).__name__,
                "error": str(exc),
            }
            scope_failures.append(failure)
            print(
                f"[players {index}/{len(scope)}] "
                f"{scope_item['season_name']} team_id={team_id}: "
                f"ERROR {type(exc).__name__}: {exc}"
            )

    known_position_ids = {
        int(row[0]) for row in fetch_all(SQL_SELECT_POSITION_IDS)
    }
    if not known_position_ids:
        raise ValueError("positions table is empty")

    player_rows: List[Tuple] = []
    player_failures: List[Dict[str, object]] = []
    profile_source_counts: DefaultDict[str, int] = defaultdict(int)
    position_source_counts: DefaultDict[str, int] = defaultdict(int)
    corrected_display_names = 0
    player_ids = sorted(embedded_profiles_by_player)

    # 복원된 스쿼드는 적재할 선수 ID를 고르는 기준이에요. 선수 기본 정보는 시즌별
    # 스쿼드 값에 고정하지 않고 고유 player_id의 단건 프로필을 기준으로 저장해요.
    for index, player_id in enumerate(player_ids, start=1):
        embedded_profiles = embedded_profiles_by_player[player_id]
        try:
            raw_player = sm.get_player_or_none(player_id)
            if raw_player is None:
                primary_profile = _merge_embedded_player_profiles(
                    player_id,
                    embedded_profiles,
                )
                primary_source = "squad_profile"
            else:
                primary_profile = _audit_direct_player_profile(
                    raw_player,
                    player_id,
                )
                primary_source = "player_endpoint"

            player_row, resolution = _build_player_row(
                primary_profile,
                embedded_profiles,
                known_position_ids,
                primary_source,
            )
            player_rows.append(player_row)
            profile_source_counts[str(resolution["profile_source"])] += 1
            position_source_counts[str(resolution["position_source"])] += 1
            corrected_display_names += int(
                bool(resolution["corrected_display_name"])
            )

            if (
                primary_source == "squad_profile"
                or index == 1
                or index % 100 == 0
                or index == len(player_ids)
            ):
                print(
                    f"[player profiles {index}/{len(player_ids)}] "
                    f"player_id={player_id} profile={primary_source} "
                    f"position={resolution['position_source']}"
                )
        except ValueError as exc:
            player_failures.append(
                {
                    "player_id": player_id,
                    "error_type": type(exc).__name__,
                    "error": str(exc),
                }
            )
            print(
                f"[player profiles {index}/{len(player_ids)}] "
                f"player_id={player_id} ERROR {type(exc).__name__}: {exc}"
            )

    upserted_player_rows = _upsert_player_rows(player_rows)

    summary: Dict[str, object] = {
        "requested_team_seasons": len(scope),
        "loaded_team_seasons": len(completed),
        "failed_team_seasons": len(scope_failures),
        "unique_players": len(player_ids),
        "upserted_player_rows": upserted_player_rows,
        "failed_players": len(player_failures),
        "profile_source_counts": dict(sorted(profile_source_counts.items())),
        "position_source_counts": dict(sorted(position_source_counts.items())),
        "corrected_display_names": corrected_display_names,
        "failures": scope_failures,
        "player_failures": player_failures,
    }
    print(
        "[players] completed "
        f"loaded={summary['loaded_team_seasons']}/"
        f"{summary['requested_team_seasons']} "
        f"failed={summary['failed_team_seasons']} "
        f"unique_players={summary['unique_players']} "
        f"upserted={summary['upserted_player_rows']} "
        f"player_failures={summary['failed_players']} "
        f"profile_sources={summary['profile_source_counts']} "
        f"position_sources={summary['position_source_counts']} "
        f"corrected_display_names={summary['corrected_display_names']}"
    )

    if scope_failures or player_failures:
        scope_samples = "; ".join(
            f"{failure['season_name']} team={failure['team_id']}: "
            f"{failure['error_type']}"
            for failure in scope_failures[:5]
        )
        player_samples = "; ".join(
            f"player={failure['player_id']}: {failure['error_type']}"
            for failure in player_failures[:5]
        )
        raise RuntimeError(
            "Player load completed with failures; failed rows were not modified. "
            f"team_seasons={len(scope_failures)} players={len(player_failures)} "
            f"team_samples={scope_samples or '-'} "
            f"player_samples={player_samples or '-'}"
        )

    return summary


def collect_all_players() -> Dict[str, object]:
    """2017/2018 이후 5대 리그의 복원된 스쿼드 선수만 저장해요."""
    return _collect_scope()


def collect_players_for_competition_season(
    season_name: str,
    competition_id: int,
) -> Dict[str, object]:
    """선택한 5대 리그·시즌의 복원된 스쿼드 선수만 저장해요."""
    return _collect_scope(
        season_name=season_name,
        competition_id=competition_id,
    )
