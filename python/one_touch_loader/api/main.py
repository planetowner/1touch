from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routes.home import router as home_router
from .routes.teams import router as teams_router
from .routes.leagues import router as leagues_router
from .routes.fixtures import router as fixtures_router
from .routes.posts import router as posts_router


def create_app() -> FastAPI:
    app = FastAPI(
        title="1touch API",
        version="0.1.0",
        openapi_url="/openapi.json",
        docs_url="/docs",
    )

    # 개발 편의용 CORS (배포 시 제한 권장)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/v1/health")
    def health():
        return {"ok": True}

    app.include_router(home_router, prefix="/v1", tags=["home"])
    app.include_router(teams_router, prefix="/v1", tags=["teams"])
    app.include_router(leagues_router, prefix="/v1", tags=["leagues"])
    app.include_router(fixtures_router, prefix="/v1", tags=["fixtures"])
    app.include_router(posts_router, prefix="/v1", tags=["posts"])

    return app


app = create_app()
