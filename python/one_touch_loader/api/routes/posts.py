from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field

from ..deps import get_user_id
from ..repos.users_repo import ensure_user
from ..repos.posts_repo import list_posts, create_post, report_post

router = APIRouter()


class CreatePostBody(BaseModel):
    category: str = Field(default="general", description="general|analysis|news")
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(min_length=1, max_length=10000)
    media_url: str | None = None


class ReportPostBody(BaseModel):
    reason: str = Field(min_length=1, max_length=500)


@router.get("/posts")
def get_posts(
    category: str | None = Query(default=None),
    sort: str = Query(default="newest", description="newest|popular|best"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    user_id: int = Depends(get_user_id),
):
    ensure_user(user_id)
    rows = list_posts(category=category, sort=sort, limit=limit, offset=offset)
    return {"items": rows, "limit": limit, "offset": offset}


@router.post("/posts")
def post_create(body: CreatePostBody, user_id: int = Depends(get_user_id)):
    ensure_user(user_id)
    post_id = create_post(
        user_id=user_id,
        category=body.category,
        title=body.title,
        body=body.body,
        media_url=body.media_url,
    )
    return {"ok": True, "post_id": post_id}


@router.post("/posts/{post_id}/report")
def post_report(post_id: int, body: ReportPostBody, user_id: int = Depends(get_user_id)):
    ensure_user(user_id)
    report_post(user_id=user_id, post_id=post_id, reason=body.reason)
    return {"ok": True, "message": "Thanks for your report"}
