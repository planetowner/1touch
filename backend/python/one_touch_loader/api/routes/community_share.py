"""공유 페이지, 공개 이미지, 앱과 도메인의 연결 정보를 제공해요."""
from html import escape
from pathlib import Path
import re
from string import Template

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse

from ..repos.community_share_repo import get_shared_post
from ..services.auth_security import required_setting
from ..services.media_storage import private_content

router = APIRouter()
PUBLIC_ORIGIN = "https://1touch.football"
PAGE = Template((Path(__file__).resolve().parents[1] / "templates" / "community_share.html").read_text(encoding="utf-8"))


@router.get("/community/{post_id:int}", response_class=HTMLResponse)
def shared_post(post_id: int):
    post = get_shared_post(post_id)
    status = 200 if post else 404
    if post is None:
        post = {"title": "게시글을 찾을 수 없어요", "body": "삭제되었거나 공개되지 않은 게시글이에요.", "images": []}
    canonical = f"{PUBLIC_ORIGIN}/community/{post_id}"
    image_urls = [f"{canonical}/images/{item['attachment_id']}" for item in post["images"]]
    description = " ".join(post["body"].split())
    if len(description) > 160:
        description = description[:159] + "…"
    # 제목·본문은 HTML이 아닌 글자로 표시해요. 메타 태그의 따옴표도 함께 처리해요.
    content = PAGE.substitute(
        title=escape(post["title"]),
        body=escape(post["body"]),
        description=escape(description),
        canonical=canonical,
        image=image_urls[0] if image_urls else f"{PUBLIC_ORIGIN}/assets/1touch-wordmark.jpg",
        images="".join(
            f'<img src="{url}" alt="게시글 첨부 이미지 {index}" loading="lazy" decoding="async">'
            for index, url in enumerate(image_urls, 1)
        ),
    )
    # 수정·숨김·삭제 결과를 다음 조회에 반영하도록 브라우저에 본문을 저장하지 않아요.
    return HTMLResponse(content, status_code=status, headers={"Cache-Control": "no-store"})


@router.get("/community/{post_id:int}/images/{attachment_id:int}")
def shared_image(post_id: int, attachment_id: int):
    post = get_shared_post(post_id)
    if post is not None:
        for item in post["images"]:
            if item["attachment_id"] == attachment_id:
                # 원본 R2 주소를 노출하지 않고 기존 파일 전송·캐시 정책을 사용해요.
                return private_content(item)
    raise HTTPException(404, "Shared image not found")


@router.get("/.well-known/apple-app-site-association")
def apple_app_site_association():
    return {"applinks": {"details": [{
        # 로컬 서명 팀과 저장소의 기본 팀이 달라, 배포 앱의 식별자를 서버에서 받아요.
        "appIDs": [required_setting("IOS_APP_LINK_APP_ID")],
        "components": [
            {"/": "/community/*/*", "exclude": True},
            {"/": "/community/*"},
        ],
    }]}}


@router.get("/.well-known/assetlinks.json")
def android_asset_links():
    # Play 배포 시 업로드 키가 아닌 앱 서명 인증서의 SHA-256을 설정해요.
    fingerprints = [value.strip().upper() for value in required_setting("ANDROID_APP_LINK_SHA256_FINGERPRINTS").split(",")]
    if any(re.fullmatch(r"(?:[0-9A-F]{2}:){31}[0-9A-F]{2}", value) is None for value in fingerprints):
        raise HTTPException(503, "ANDROID_APP_LINK_SHA256_FINGERPRINTS must contain SHA-256 certificate fingerprints")
    return [{
        "relation": ["delegate_permission/common.handle_all_urls"],
        "target": {
            "namespace": "android_app",
            "package_name": "com.onetouch.football",
            "sha256_cert_fingerprints": fingerprints,
        },
    }]
