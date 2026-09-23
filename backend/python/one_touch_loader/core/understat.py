"""xG와 슈팅이 같은 Understat 원본을 사용하게 해요."""

from __future__ import annotations

import re
import json
from pathlib import Path

import requests


# Understat가 제공하는 Big 5 리그예요. 시즌은 별도 ID 없이 시작 연도를 사용해요.
UNDERSTAT_LEAGUES = {
    8: "EPL", 82: "Bundesliga", 301: "Ligue_1", 384: "Serie_A", 564: "La_liga",
}


def season_start_year(season_name: str) -> int:
    match = re.fullmatch(r"(\d{4})/(\d{4})", season_name)
    if match is None or int(match[2]) != int(match[1]) + 1:
        raise ValueError(f"Expected season YYYY/YYYY: {season_name!r}")
    return int(match[1])


class UnderstatClient:
    def __init__(self, *, cache_directory: Path | None = None):
        self.cache_directory = cache_directory
        self.session = requests.Session()
        # 현재 사이트와 soccerdata 1.9.1은 쿠키를 받은 뒤 JSON을 요청해요.
        response = self.session.get("https://understat.com/", timeout=30)
        response.raise_for_status()
        self.session.headers["X-Requested-With"] = "XMLHttpRequest"

    def get_season(self, competition_id: int, season_name: str) -> dict:
        league = UNDERSTAT_LEAGUES[competition_id]
        year = season_start_year(season_name)
        return self._get(f"getLeagueData/{league}/{year}")

    def get_match(self, match_id: str) -> dict:
        return self._get(f"getMatchData/{match_id}")

    def _get(self, path: str) -> dict:
        # ID 연결과 xG 적재가 같은 실행의 원본을 공유해요. 실행이 끝나면 임시 파일도 지워요.
        cache = self.cache_directory / (path.replace('/', '_') + '.json') if self.cache_directory else None
        if cache is not None and cache.exists():
            return json.loads(cache.read_text(encoding='utf-8'))
        response = self.session.get(f"https://understat.com/{path}", timeout=30)
        response.raise_for_status()
        payload = response.json()
        if cache is not None:
            cache.write_text(json.dumps(payload, ensure_ascii=False), encoding='utf-8')
        return payload

    def close(self):
        self.session.close()
