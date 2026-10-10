"""커뮤니티 조회와 참여, 경기 채팅의 접근 규칙을 관리해요."""
from __future__ import annotations

from fastapi import HTTPException


def require_favorite_team_access(
    favorite_team_id: int | None, allowed_team_ids: tuple[int, ...]
) -> None:
    # 커뮤니티 참여는 최애팀만 허용해요. 사용자와 대상 팀 ID는 서버가 DB에서 읽어요.
    if favorite_team_id is None or favorite_team_id not in allowed_team_ids:
        raise HTTPException(status_code=403, detail="Access requires a matching home favorite team")


def require_followed_team_access(
    followed_team_ids: list[int], allowed_team_ids: tuple[int, ...]
) -> None:
    # 채팅 조회·전송·신고는 팔로우한 팀 중 하나가 출전하면 허용해요.
    if not any(team_id in allowed_team_ids for team_id in followed_team_ids):
        raise HTTPException(status_code=403, detail="Chat requires following a participating team")


def community_read_team_ids(
    favorite_team_id: int | None, followed_team_ids: list[int]
) -> tuple[int, ...]:
    # 다른 팔로우 팀은 조회만 허용해요. 작성·좋아요 권한과 경기 채팅에는 적용하지 않아요.
    if favorite_team_id is None:
        raise HTTPException(status_code=403, detail="Community viewing requires a followed team")
    return tuple(dict.fromkeys((favorite_team_id, *followed_team_ids)))


def require_community_read_access(
    favorite_team_id: int | None, followed_team_ids: list[int], team_id: int
) -> None:
    if team_id not in community_read_team_ids(favorite_team_id, followed_team_ids):
        raise HTTPException(status_code=403, detail="Community viewing requires a followed team")
