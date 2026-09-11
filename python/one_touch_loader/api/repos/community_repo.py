"""팀과 무관하게 한 번 저장하는 커뮤니티 공통 안내예요."""
from ..db import fetch_one_dict, transaction
from .moderation_repo import require_admin
from .posts_repo import community_user
from .users_repo import lock_user


def read_rules() -> dict | None:
    # 운영자가 아직 등록하지 않았다면 임의 규칙을 채우지 않고 미등록으로 반환해요.
    return fetch_one_dict("SELECT body FROM community_rules WHERE rules_id=1")


def get_rules(user_id: int, team_id: int) -> dict | None:
    community_user(user_id, team_id)
    return read_rules()


def set_rules(admin_id: int, body: str) -> None:
    require_admin(admin_id)
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, admin_id)
        cur.execute("""INSERT INTO community_rules (rules_id,body) VALUES (1,%s)
            ON DUPLICATE KEY UPDATE body=%s""", (body, body))
