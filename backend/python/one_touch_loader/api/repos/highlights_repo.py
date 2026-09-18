"""홈과 팀 화면에서 같은 국가별 경기 선정 규칙을 사용해요."""
from ..db import fetch_all_dict
from ...core.highlights import select_latest_matches, utc_datetime
from ...core.highlight_storage import HIGHLIGHT_SELECT, candidate_from_row


def get_team_highlights(team_id: int, viewer_country: str) -> dict:
    rows = fetch_all_dict(HIGHLIGHT_SELECT, (team_id,))
    candidates = [candidate_from_row(row) for row in rows]
    return {"team_id": team_id, "viewer_country": viewer_country.upper(),
            "updated_at": max((utc_datetime(r["checked_at"]) for r in rows), default=None),
            "items": select_latest_matches(candidates, viewer_country)}
