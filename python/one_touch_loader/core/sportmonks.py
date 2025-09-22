import os, time, random
import requests
from typing import Dict, Iterable, List, Optional
from dotenv import load_dotenv

load_dotenv()

class SportmonksClient:
    """
    Sportmonks Football API v3 전용 클라이언트.
    인증: Authorization 헤더에 토큰 '문자열 자체' (Bearer 아님)
    """

    def __init__(self, api_base: Optional[str] = None, token: Optional[str] = None, timeout: int = 25):
        self.base = (api_base or os.getenv("SPORTMONKS_API_BASE_URL", "")).rstrip("/")
        self.token = token or os.getenv("SPORTMONKS_API_TOKEN")
        if not self.base:
            raise ValueError("SPORTMONKS_API_BASE_URL is required")
        if not self.token:
            raise ValueError("SPORTMONKS_API_TOKEN is required")
        self.timeout = timeout
        self._session = requests.Session()

    def _get(self, path: str, params: Optional[Dict] = None, max_retries: int = 6) -> Dict:
        url = f"{self.base}/{path.lstrip('/')}"
        headers = {"Accept": "application/json", "Authorization": self.token}
        backoff = 1.0
        last_exc = None
        for attempt in range(max_retries):
            resp = self._session.get(url, headers=headers, params=params or {}, timeout=self.timeout)
            if resp.status_code == 429:
                retry_after = resp.headers.get("Retry-After")
                try:
                    sleep_sec = float(retry_after) if retry_after is not None else backoff
                except Exception:
                    sleep_sec = backoff
                time.sleep(max(0.5, min(sleep_sec, 120.0)) + random.uniform(0, 0.5))
                backoff = min(backoff * 2, 120.0)
                continue
            try:
                resp.raise_for_status()
            except requests.HTTPError as e:
                last_exc = e
                if 500 <= resp.status_code < 600 and attempt < max_retries - 1:
                    time.sleep(backoff + random.uniform(0, 0.25))
                    backoff = min(backoff * 2, 60.0)
                    continue
                raise
            return resp.json()
        if last_exc:
            raise last_exc
        raise requests.HTTPError(f"GET failed after {max_retries} retries: {url}")

    # ----- Leagues/Seasons -----
    def search_leagues(self, query: str) -> List[Dict]:
        return self._get(f"leagues/search/{query}").get("data", [])

    def get_league(self, league_id: int) -> dict:
        return self._get(f"leagues/{league_id}").get("data", {}) or {}

    def get_league_with_seasons(self, league_id: int) -> Dict:
        return self._get(f"leagues/{league_id}", params={"include": "seasons"}).get("data", {})

    # ----- Teams -----
    def iter_teams_by_season(self, season_id: int, per_page: int = 50) -> Iterable[Dict]:
        page = 1
        while True:
            obj = self._get(f"teams/seasons/{season_id}", params={"per_page": per_page, "page": page})
            items = obj.get("data", [])
            if not items:
                break
            for t in items:
                yield t
            meta = obj.get("meta") or {}
            has_more = obj.get("has_more", meta.get("has_more"))
            if not has_more:
                break
            page += 1

    # ----- Fixtures (season-wide, with includes & pagination) -----
    def iter_fixtures_by_season(self, season_id: int, per_page: int = 100,
                                include: str = "participants;state;scores;round;stage;group") -> Iterable[dict]:
        page = 1
        while True:
            obj = self._get("fixtures", params={
                "filters": f"fixtureSeasons:{season_id}",
                "per_page": per_page,
                "page": page,
                "include": include
            })
            rows = obj.get("data", [])
            if not rows:
                break
            for r in rows:
                yield r
            pag = obj.get("pagination") or obj.get("meta") or {}
            has_more = pag.get("has_more") or pag.get("has_more_pages")
            if not has_more:
                break
            page += 1


    # ----- States -----
    def get_states_map(self) -> Dict[int, str]:
        data = self._get("states")
        states = data.get("data", [])
        out: Dict[int, str] = {}
        for s in states:
            sid = s.get("id")
            code = s.get("code") or s.get("state") or s.get("name")
            if isinstance(sid, int) and isinstance(code, str):
                out[sid] = code.strip().upper()
        return out
