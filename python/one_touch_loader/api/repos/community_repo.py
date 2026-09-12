"""커뮤니티 안내와 홈 최애팀 회원 수를 조회해요."""
from ..db import fetch_one_dict, transaction
from .moderation_repo import require_admin
from .posts_repo import community_user
from .users_repo import lock_user


def read_rules(language: str) -> dict | None:
    # 운영자가 아직 등록하지 않았다면 임의 규칙을 채우지 않고 미등록으로 반환해요.
    return fetch_one_dict("SELECT body FROM community_rules WHERE language=%s", (language,))


def get_rules(user_id: int, team_id: int, language: str) -> dict | None:
    community_user(user_id, team_id)
    return read_rules(language)


def count_followers(user_id: int, team_id: int) -> int:
    community_user(user_id, team_id)
    # 커뮤니티 참여 기준과 같게 홈 최애팀만 세요. 다른 팔로우 팀이나 차단 여부는 집계에 반영하지 않아요.
    return fetch_one_dict("SELECT COUNT(*) AS total FROM users WHERE favorite_team_id=%s", (team_id,))["total"]


def set_rules(admin_id: int, body: str, language: str) -> None:
    require_admin(admin_id)
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, admin_id)
        # 팀별 복사본 없이 언어마다 한 본문을 공유해요. 다른 언어의 문구는 덮어쓰지 않아요.
        cur.execute("""INSERT INTO community_rules (language,body) VALUES (%s,%s)
            ON DUPLICATE KEY UPDATE body=%s""", (language, body, body))
