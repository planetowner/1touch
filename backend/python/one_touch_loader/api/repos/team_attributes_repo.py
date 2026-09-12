from __future__ import annotations

from datetime import datetime, timezone

from ..db import fetch_all_dict, fetch_one_dict


# 기존 뷰가 활성 모델 선택·소수 둘째 자리 반올림·미산출 항목의 NULL을 함께 처리해요.
_SCOPE_SQL = """
FROM v_team_attribute_display_scores v
JOIN seasons s ON s.season_id = v.season_id
WHERE v.team_id = %s
  AND s.competition_id IN (8, 82, 301, 384, 564)
"""


def get_team_attributes(team_id: int, season_id: int) -> dict | None:
    row = fetch_one_dict(
        """
        SELECT v.team_id, v.team_name, v.model_id,
               s.competition_id, s.season_id, s.name AS season_name, s.is_current,
               v.possession_build_up, v.attacking_threat, v.chance_creation,
               v.finishing, v.defending,
               UNIX_TIMESTAMP(v.attributes_updated_at) AS attributes_updated_at_epoch
        """ + _SCOPE_SQL + " AND v.season_id = %s",
        (team_id, season_id),
    )
    if row is None:
        return None
    # 운영 DB 세션은 현지 시간대를 써요. 같은 갱신 시각을 앱에 UTC로 전달해요.
    row["attributes_updated_at"] = datetime.fromtimestamp(
        float(row.pop("attributes_updated_at_epoch")), tz=timezone.utc,
    )
    return row


def list_team_attribute_seasons(team_id: int) -> list[dict]:
    # 한 영역이라도 계산된 시즌을 제공해 부분 데이터가 있는 과거 시즌도 선택할 수 있어요.
    return fetch_all_dict(
        """
        SELECT s.competition_id, s.season_id, s.name AS season_name, s.is_current
        """ + _SCOPE_SQL + " ORDER BY s.name DESC, s.season_id DESC",
        (team_id,),
    )
