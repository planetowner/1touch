import os
from urllib.parse import urlencode
import requests
from dotenv import load_dotenv

load_dotenv()

SM_BASE_URL = os.getenv("SPORTMONKS_API_BASE_URL", "").rstrip("/")
SM_TOKEN = os.getenv("SPORTMONKS_API_TOKEN", "")

if not SM_BASE_URL or not SM_TOKEN:
    raise RuntimeError("SPORTMONKS_API_BASE_URL / SPORTMONKS_API_TOKEN is missing in .env")

class SportmonksClient:
    """
    Sportmonks v3 client.
    Auth: put token string in Authorization header (NOT Bearer).
    """
    def __init__(self, base_url: str = SM_BASE_URL, token: str = SM_TOKEN):
        self.base_url = base_url
        self.session = requests.Session()
        # v3 인증: Authorization 헤더에 토큰 문자열 자체
        self.session.headers.update({"Authorization": token})

    def _full_url(self, path: str) -> str:
        path = path.lstrip("/")
        return f"{self.base_url}/{path}"

    def get(self, path: str, params: dict | None = None) -> dict:
        url = self._full_url(path)
        resp = self.session.get(url, params=params or {}, timeout=30)
        resp.raise_for_status()
        return resp.json()

    def get_paginated(self, path: str, params: dict | None = None):
        """API v3 pagination: use &page=N while meta.has_more is True."""
        page = 1
        params = dict(params or {})
        while True:
            params["page"] = page
            data = self.get(path, params=params)
            for row in data.get("data", []):
                yield row
            meta = data.get("meta") or {}
            has_more = meta.get("has_more")
            if not has_more:
                break
            page += 1

sm = SportmonksClient()
