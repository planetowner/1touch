"""커뮤니티 조회와 참여, 경기 채팅의 접근 규칙을 관리해요."""
from __future__ import annotations

from fastapi import HTTPException


def require_favorite_team_access(
    favorite_team_id: int | None, allowed_team_ids: tuple[int, ...]
) -> None:
    # 커뮤니티는 해당 팀 하나, 경기 채팅은 경기의 홈·원정 팀을 전달해요.
    # 팔로우한 다른 팀은 권한을 주지 않아요. 사용자와 대상 팀 ID는 서버가 DB에서 읽어요.
    # 커뮤니티 참여와 경기 채팅은 최애팀 권한을 유지해요.
    if favorite_team_id is None or favorite_team_id not in allowed_team_ids:
        raise HTTPException(status_code=403, detail="Access requires a matching home favorite team")


def require_community_read_access(
    favorite_team_id: int | None, followed_team_ids: list[int], team_id: int
) -> None:
    # 다른 팔로우 팀은 조회만 허용해요. 작성·좋아요 권한과 경기 채팅에는 적용하지 않아요.
    if favorite_team_id is None or (team_id != favorite_team_id and team_id not in followed_team_ids):
        raise HTTPException(status_code=403, detail="Community viewing requires a followed team")
