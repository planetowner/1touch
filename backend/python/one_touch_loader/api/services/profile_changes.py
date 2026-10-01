"""공개 이름과 최애팀에 같은 14일 변경 횟수 규칙을 적용해요."""
from datetime import datetime, timedelta

CHANGE_WINDOW = timedelta(days=14)
MAX_CHANGES = 2


class ProfileChangeLimitError(ValueError):
    def __init__(self, available_at: datetime):
        self.available_at = available_at
        super().__init__(f"You can change this {MAX_CHANGES} times in {CHANGE_WINDOW.days} days")

    def detail(self) -> dict:
        # 닉네임과 최애팀의 제한 안내도 실제 검증에 쓰는 값을 함께 내려줘요.
        return {"message": str(self), "available_at": self.available_at.isoformat() + "Z",
                "max_changes": MAX_CHANGES, "window_days": CHANGE_WINDOW.days}


def check_change_limit(cur, user_id: int, change_type: str, now: datetime) -> None:
    # 호출부가 사용자 행을 잠근 뒤 확인하므로 동시 요청도 같은 횟수를 봐요.
    cur.execute("""SELECT changed_at FROM user_profile_changes
        WHERE user_id=%s AND change_type=%s AND changed_at>%s
        ORDER BY changed_at DESC, change_id DESC LIMIT %s""",
        (user_id, change_type, now - CHANGE_WINDOW, MAX_CHANGES))
    recent = cur.fetchall()
    if len(recent) == MAX_CHANGES:
        raise ProfileChangeLimitError(recent[-1]["changed_at"] + CHANGE_WINDOW)


def record_change(cur, user_id: int, change_type: str, now: datetime) -> None:
    cur.execute("INSERT INTO user_profile_changes (user_id,change_type,changed_at) VALUES (%s,%s,%s)",
                (user_id, change_type, now))
