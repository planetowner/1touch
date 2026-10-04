"""과거 대화와 실시간 메시지에 같은 익명 표시 규칙을 적용해요."""
import secrets
import string

from .community_periods import public_row


SUFFIX_ALPHABET = string.ascii_uppercase + string.digits


def new_nickname(players: list[dict[str, str]]) -> dict[str, str]:
    player = secrets.choice(players)
    suffix = "".join(secrets.choice(SUFFIX_ALPHABET) for _ in range(4))
    return {f"nickname_{language}": f"{player[f'short_{language}']}_{suffix}" for language in ("en", "ko")}


def public_chat_message(row: dict, viewer_id: int) -> dict:
    # 계정 ID·이름·사진은 응답에 포함하지 않아요. 내 메시지 여부만 서버에서 계산해요.
    deleted = row["user_id"] is None
    if not deleted and (not row["nickname_en"] or not row["nickname_ko"]):
        raise RuntimeError("Existing chat authors must be assigned nicknames before serving chat")
    return public_row({
        "message_id": row["message_id"],
        "fixture_id": row["fixture_id"],
        "nickname_en": None if deleted else row["nickname_en"],
        "nickname_ko": None if deleted else row["nickname_ko"],
        "is_mine": row["user_id"] == viewer_id,
        "author_deleted": deleted,
        "text": row["text"],
        "created_at": row["created_at"],
    })
