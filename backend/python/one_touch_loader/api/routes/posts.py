from typing import Literal
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field
from ..deps import get_user_id
from ..repos import posts_repo
from ..services.community_periods import PostPeriod

router = APIRouter()
Category = Literal["general", "analysis", "news"]


class DraftBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    category: Category = "general"
    title: str = Field(default="", max_length=200)
    body: str = Field(default="", max_length=10000)
    attachment_ids: list[int] = Field(default_factory=list, max_length=10)


class PostBody(DraftBody):
    # 제목·본문·첨부 규칙은 같고, 게시할 때만 제목이 반드시 필요해요.
    title: str = Field(min_length=1, max_length=200)


class CreatePostBody(PostBody):
    team_id: int = Field(gt=0)


class CreateDraftBody(DraftBody):
    team_id: int = Field(gt=0)


@router.get("/post-drafts")
def drafts(limit: int = Query(default=50, ge=1, le=100), offset: int = Query(default=0, ge=0),
           user_id: int = Depends(get_user_id)):
    return {"items": posts_repo.list_drafts(user_id, limit, offset), "limit": limit, "offset": offset}


@router.get("/post-drafts/{post_id}")
def draft(post_id: int, user_id: int = Depends(get_user_id)):
    return posts_repo.get_draft(user_id, post_id)


@router.post("/post-drafts", status_code=201)
def create_draft(body: CreateDraftBody, user_id: int = Depends(get_user_id)):
    post_id = posts_repo.create_post(user_id=user_id, draft=True, **body.model_dump())
    return posts_repo.get_draft(user_id, post_id)


@router.put("/post-drafts/{post_id}")
def save_draft(post_id: int, body: DraftBody, user_id: int = Depends(get_user_id)):
    posts_repo.update_post(user_id, post_id, draft=True, **body.model_dump())
    return posts_repo.get_draft(user_id, post_id)


@router.post("/post-drafts/{post_id}/publish")
def publish_draft(post_id: int, user_id: int = Depends(get_user_id)):
    return {"post_id": posts_repo.publish_draft(user_id, post_id)}


@router.delete("/post-drafts/{post_id}")
def delete_draft(post_id: int, user_id: int = Depends(get_user_id)):
    posts_repo.delete_draft(user_id, post_id)
    return {"ok": True}


class CommentBody(BaseModel):
    body: str = Field(min_length=1, max_length=5000)
    reply_to_id: int | None = Field(default=None, gt=0)


class EditCommentBody(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    body: str = Field(min_length=1, max_length=5000)


class ReportBody(BaseModel):
    reason: str = Field(min_length=1, max_length=500)


@router.get("/posts")
def posts(team_id: int = Query(gt=0), category: Category | None = None,
          sort: posts_repo.PostSort = posts_repo.PostSort.newest, period: PostPeriod = PostPeriod.all_time,
          limit: int = Query(default=50, ge=1, le=100), offset: int = Query(default=0, ge=0),
          timezone: str | None = Query(default=None, max_length=64, description="현재 기기의 IANA 시간대. 기간 필터 사용 시 앱이 자동 전달해요."),
          user_id: int = Depends(get_user_id)):
    return {"items": posts_repo.list_posts(user_id, team_id, category, sort, period, limit, offset, timezone),
            "limit": limit, "offset": offset}


@router.get("/posts/{post_id}")
def post(post_id: int, user_id: int = Depends(get_user_id)):
    return posts_repo.get_post(user_id, post_id)


@router.post("/posts", status_code=201)
def create_post(body: CreatePostBody, user_id: int = Depends(get_user_id)):
    return {"post_id": posts_repo.create_post(user_id=user_id, **body.model_dump())}


@router.put("/posts/{post_id}")
def update_post(post_id: int, body: PostBody, user_id: int = Depends(get_user_id)):
    posts_repo.update_post(user_id, post_id, **body.model_dump())
    return {"ok": True}


@router.delete("/posts/{post_id}")
def delete_post(post_id: int, user_id: int = Depends(get_user_id)):
    posts_repo.delete_post(user_id, post_id)
    return {"ok": True}


@router.put("/comments/{comment_id}")
def edit_comment(comment_id: int, body: EditCommentBody, user_id: int = Depends(get_user_id)):
    posts_repo.change_comment(user_id, comment_id, body.body)
    return {"ok": True}


@router.delete("/comments/{comment_id}")
def delete_comment(comment_id: int, user_id: int = Depends(get_user_id)):
    posts_repo.change_comment(user_id, comment_id, None)
    return {"ok": True}


@router.get("/posts/{post_id}/comments")
def comments(post_id: int, after_id: int = Query(default=0, ge=0),
             limit: int = Query(default=50, ge=1, le=100), user_id: int = Depends(get_user_id)):
    return {"items": posts_repo.list_comments(user_id, post_id, after_id, limit)}


@router.post("/posts/{post_id}/comments", status_code=201)
def create_comment(post_id: int, body: CommentBody, user_id: int = Depends(get_user_id)):
    return {"comment_id": posts_repo.create_comment(user_id, post_id, body.body, body.reply_to_id)}


# PUT·DELETE를 반복해도 좋아요 관계는 하나예요. 동일한 규칙을 게시물과 댓글에 적용해요.
@router.put("/posts/{target_id}/like")
def like_post(target_id: int, user_id: int = Depends(get_user_id)):
    posts_repo.set_like(user_id, "post", target_id, True)
    return {"ok": True}


@router.delete("/posts/{target_id}/like")
def unlike_post(target_id: int, user_id: int = Depends(get_user_id)):
    posts_repo.set_like(user_id, "post", target_id, False)
    return {"ok": True}


@router.put("/comments/{target_id}/like")
def like_comment(target_id: int, user_id: int = Depends(get_user_id)):
    posts_repo.set_like(user_id, "comment", target_id, True)
    return {"ok": True}


@router.delete("/comments/{target_id}/like")
def unlike_comment(target_id: int, user_id: int = Depends(get_user_id)):
    posts_repo.set_like(user_id, "comment", target_id, False)
    return {"ok": True}


@router.post("/posts/{target_id}/report")
def report_post(target_id: int, body: ReportBody, user_id: int = Depends(get_user_id)):
    posts_repo.report_content(user_id, "post", target_id, body.reason)
    return {"ok": True}


@router.post("/comments/{target_id}/report")
def report_comment(target_id: int, body: ReportBody, user_id: int = Depends(get_user_id)):
    posts_repo.report_content(user_id, "comment", target_id, body.reason)
    return {"ok": True}
