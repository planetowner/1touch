"""커뮤니티와 경기 채팅의 홈 최애팀 접근 규칙을 공유해요."""
from __future__ import annotations

from fastapi import HTTPException


def require_favorite_team_access(
    favorite_team_id: int | None, allowed_team_ids: tuple[int, ...]
) -> None:
    # 커뮤니티는 해당 팀 하나, 경기 채팅은 경기의 홈·원정 팀을 전달해요.
    # 팔로우한 다른 팀은 권한을 주지 않아요. 사용자와 대상 팀 ID는 서버가 DB에서 읽어요.
    # 읽기도 같은 제한을 적용하므로 본문이나 채팅 기록을 반환하기 전에 검사해요.
    if favorite_team_id is None or favorite_team_id not in allowed_team_ids:
        raise HTTPException(status_code=403, detail="Access requires a matching home favorite team")
