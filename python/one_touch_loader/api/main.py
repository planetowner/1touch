from __future__ import annotations

import os

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from mysql.connector import Error as MySQLError

from .db import fetch_one_dict
from .routes.home import router as home_router
from .routes.teams import router as teams_router
from .routes.competitions import router as competitions_router
from .routes.fixtures import router as fixtures_router
from .routes.posts import router as posts_router
from .routes.players import router as players_router


def create_app() -> FastAPI:
    app = FastAPI(
        title="1touch API",
        version="0.1.0",
        openapi_url="/openapi.json",
        docs_url="/docs",
    )

    # 운영에서는 실제 웹 프런트엔드 주소만 허용해요. 모바일 앱은 CORS 설정이 필요 없어요.
    origins = [value.strip() for value in os.getenv("API_CORS_ORIGINS", "*").split(",") if value.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials="*" not in origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/v1/health")
    def health():
        return {"ok": True}

    @app.get("/v1/ready", include_in_schema=False)
    def ready():
        # 프로세스가 살아 있어도 DB를 읽지 못하면 배포 완료로 처리하지 않아요.
        try:
            fetch_one_dict("SELECT 1 AS ok")
        except MySQLError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc
        return {"ok": True}

    app.include_router(home_router, prefix="/v1", tags=["home"])
    app.include_router(teams_router, prefix="/v1", tags=["teams"])
    app.include_router(competitions_router, prefix="/v1", tags=["competitions"])
    app.include_router(fixtures_router, prefix="/v1", tags=["fixtures"])
    app.include_router(posts_router, prefix="/v1", tags=["posts"])
    app.include_router(players_router, prefix="/v1", tags=["players"])

    return app


app = create_app()
