"""배포 전에 하이라이트 테이블과 실제 조회 응답을 쓰기 없이 확인해요."""
from one_touch_loader.core.highlights import load_catalog
from one_touch_loader.api.repos.highlights_repo import get_team_highlights
from one_touch_loader.api.schemas.highlights import TeamHighlightsResponse
from one_touch_loader.loaders.highlights_loader import YouTubeClient
from diagnostics.migrate_recent_relations import verify_schema
from one_touch_loader.core.db import get_conn


def check():
    with get_conn() as connection:
        verify_schema(connection, before=False)
    client = YouTubeClient()
    # 서버 IP 제한 등으로 로컬에서만 작동하는 키도 배포 전에 확인해요.
    clubs = load_catalog()["clubs"]
    channel_id = clubs[0]["channel_id"]
    channels = client.get("channels", part="id", id=channel_id)["items"]
    if not channels or channels[0]["id"] != channel_id:
        raise ValueError("YouTube official channel check failed")
    ready = 0
    for club in clubs:
        payload = TeamHighlightsResponse.model_validate(get_team_highlights(club["team_id"], "KR"))
        ready += len(payload.items) == 3
    print(f"Highlights read-only check: {len(clubs)} teams; KR latest-three ready={ready}")


if __name__ == "__main__":
    check()
