"""홈·팀·경기 화면에서 같은 공식 영상 선정 규칙을 사용해요."""
from ..db import fetch_all_dict
from ...core.highlights import select_latest_matches, utc_datetime
from ...core.highlight_storage import HIGHLIGHT_SELECT, FIXTURE_HIGHLIGHT_SELECT, candidate_from_row


def get_team_highlights(team_id: int, viewer_country: str) -> dict:
    return {"team_id": team_id, **_read_highlights(HIGHLIGHT_SELECT, team_id, viewer_country, 3)}


def get_fixture_highlights(fixture_id: int, viewer_country: str | None = None) -> dict:
    # 최근 3경기를 먼저 고르면 과거 경기 영상이 빠져요. 경기 ID로 후보부터 좁혀요.
    return {"fixture_id": fixture_id,
            **_read_highlights(FIXTURE_HIGHLIGHT_SELECT, fixture_id, viewer_country, 1)}


def _read_highlights(sql: str, identifier: int, viewer_country: str | None, limit: int) -> dict:
    rows = fetch_all_dict(sql, (identifier,))
    candidates = [candidate_from_row(row) for row in rows]
    return {"viewer_country": viewer_country.upper() if viewer_country is not None else None,
            "updated_at": max((utc_datetime(r["checked_at"]) for r in rows), default=None),
            "items": select_latest_matches(candidates, viewer_country, limit)}
