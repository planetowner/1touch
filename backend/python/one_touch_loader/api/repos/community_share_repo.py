"""공유 웹에서는 게시된 글의 제목·본문·이미지만 공개해요."""
from ..db import fetch_all_dict, fetch_one_dict


def get_shared_post(post_id: int) -> dict | None:
    # 앱의 로그인·팔로우 권한과 달리 공유 웹은 비회원 조회를 허용해요.
    # 페이지와 이미지 요청이 이 검사를 함께 써서 숨김·삭제 후 이미지도 공개하지 않아요.
    post = fetch_one_dict("""SELECT post_id,title,body FROM posts
        WHERE post_id=%s AND state='active'""", (post_id,))
    if post is None:
        return None
    post["images"] = fetch_all_dict("""SELECT attachment_id,object_key,content_type,byte_size
        FROM post_attachments WHERE post_id=%s AND object_key IS NOT NULL
        AND content_type LIKE %s ORDER BY position""", (post_id, "image/%"))
    return post
