"""홈과 팀 화면에서 같은 국가별 경기 선정 규칙을 사용해요."""
import json

from ..db import fetch_all_dict
from ...core.highlights import select_latest_matches, utc_datetime


def get_team_highlights(team_id: int, viewer_country: str) -> dict:
    rows = fetch_all_dict("""SELECT video_id,video_url,title,thumbnail_url,published_at,
        source_type,match_data,video_data,updated_at
        FROM team_highlights_cache WHERE team_id=%s AND match_key IS NOT NULL""", (team_id,))
    candidates = []
    for row in rows:
        match = row["match_data"]
        metadata = row["video_data"]
        if isinstance(match, (str, bytes)):
            match = json.loads(match)
        if isinstance(metadata, (str, bytes)):
            metadata = json.loads(metadata)
        candidates.append({**row, **metadata, "match": match, "published_at": utc_datetime(row["published_at"])})
    return {"team_id": team_id, "viewer_country": viewer_country.upper(),
            "updated_at": max((utc_datetime(r["updated_at"]) for r in rows), default=None),
            "items": select_latest_matches(candidates, viewer_country)}
