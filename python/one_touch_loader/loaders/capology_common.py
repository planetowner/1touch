from __future__ import annotations

import atexit
import json
import re
import socket
import subprocess
import unicodedata
from html import unescape
from pathlib import Path
from time import monotonic, sleep
from typing import Dict, List, Optional, Set, Tuple
from urllib.request import urlopen

from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait

from ..core.db import fetch_all
from .team_squad_members_loader import (
    BIG5_COMPETITION_IDS,
    MIN_SEASON_START_YEAR,
)


CAPOLOGY_BASE_URL = "https://www.capology.com"
CAPOLOGY_LEAGUES = {
    8: ("uk", "premier-league"),
    82: ("de", "1-bundesliga"),
    301: ("fr", "ligue-1"),
    384: ("it", "serie-a"),
    564: ("es", "la-liga"),
}
CAPOLOGY_CHROME_PATH = Path(
    r"C:\Program Files\Google\Chrome\Application\chrome.exe"
)
CLOUDFLARE_VERIFICATION_WAIT_SECONDS = 300
CAPOLOGY_POSITION_GROUP_IDS = {
    "GK": 24,
    "CB": 25,
    "LB": 25,
    "RB": 25,
    "LWB": 25,
    "RWB": 25,
    "DM": 26,
    "CM": 26,
    "AM": 26,
    "LM": 26,
    "RM": 26,
    "ST": 27,
    "CF": 27,
    "SS": 27,
    "LW": 27,
    "RW": 27,
}
CAPOLOGY_GENERAL_POSITION_GROUP_IDS = {
    "K": 24,
    "D": 25,
    "M": 26,
    "F": 27,
}
CAPOLOGY_DIAGNOSTICS_DIRECTORY = (
    Path(__file__).resolve().parents[3] / "logs" / "diagnostics"
)
CAPOLOGY_CHROME_PROFILE_DIRECTORY = (
    CAPOLOGY_DIAGNOSTICS_DIRECTORY / "capology_chrome_profile"
)

# 같은 선수의 시즌별 명단 슬러그는 DB에 저장할 대표 선수 페이지 슬러그로 통일해요.
VERIFIED_CAPOLOGY_PLAYER_SLUG_ALIASES = {
    # Diouf의 이전·현재 팀 명단은 38350을 쓰지만 선수 링크는 404예요.
    # 공식 West Ham→Brentford 이적, 명단의 이름·국적·나이를 대조해 기존 38349에 연결해요.
    # 급여는 해당 팀·시즌의 원문 값만 쓰며, 이전 팀 급여로 보충하지 않아요.
    # https://www.brentfordfc.com/en/news/article/first-team-brentford-el-hadji-malick-diouf-west-ham-united-transfer
    "el-hadji-malick-diouf-38350": "el-hadji-malick-diouf-38349",
    # 말리 국적 Adama Traoré는 사용자가 임의로 adama-traore-34878을 대표로 결정했어요.
    "adama-traore-34855": "adama-traore-34878",
    # 과거 명단의 긴 슬러그는 404라 현재 열리는 선수 페이지 슬러그를 사용해요.
    "noel-aseko-nkili-38678": "noel-aseko-38678",
}

SQL_SELECT_TARGET_OBSERVATIONS = """
SELECT
  seasons.competition_id,
  seasons.season_id,
  seasons.name,
  squad.team_id,
  teams.name,
  players.player_id,
  players.display_name,
  players.full_name,
  players.date_of_birth,
  countries.name,
  COALESCE(squad.position_group_id, positions.position_group_id),
  seasons.is_current
FROM team_squad_members AS squad
JOIN seasons
  ON seasons.season_id = squad.season_id
JOIN teams
  ON teams.team_id = squad.team_id
JOIN players
  ON players.player_id = squad.player_id
LEFT JOIN countries
  ON countries.country_id = players.nationality_id
LEFT JOIN positions
  ON positions.position_id = players.position_id
WHERE seasons.competition_id IN (8,82,301,384,564)
  AND CAST(LEFT(seasons.name, 4) AS UNSIGNED) >= %s
ORDER BY
  seasons.name,
  seasons.competition_id,
  squad.team_id,
  players.player_id
"""


def _normalize_identity_text(value: str) -> str:
    translated = value.casefold().translate(
        str.maketrans(
            {
                "æ": "ae",
                "ð": "d",
                "đ": "dj",
                "ł": "l",
                "ø": "o",
                "œ": "oe",
                "þ": "th",
                "ß": "ss",
                "'": "",
                "’": "",
                "­": "",
            }
        )
    )
    decomposed = unicodedata.normalize("NFKD", translated)
    without_marks = "".join(
        character
        for character in decomposed
        if not unicodedata.combining(character)
    )
    return " ".join(re.sub(r"[^a-z0-9]+", " ", without_marks).split())


def _season_to_capology(season_name: str) -> str:
    match = re.fullmatch(r"(\d{4})/(\d{4})", season_name)
    if match is None:
        raise ValueError(f"Unsupported season name: {season_name!r}")
    if int(match.group(2)) != int(match.group(1)) + 1:
        raise ValueError(f"Unsupported season year range: {season_name!r}")
    return f"{match.group(1)}-{match.group(2)}"


def _capology_salary_url(
    team_slug: str,
    season_name: str,
    is_current: bool,
) -> str:
    if is_current:
        return f"{CAPOLOGY_BASE_URL}/club/{team_slug}/salaries/"
    season_path = _season_to_capology(season_name)
    return f"{CAPOLOGY_BASE_URL}/club/{team_slug}/salaries/{season_path}/"


def _capology_league_salary_url(
    competition_id: int,
    season_name: str,
    is_current: bool,
) -> str:
    country_path, league_path = CAPOLOGY_LEAGUES[competition_id]
    base_url = f"{CAPOLOGY_BASE_URL}/{country_path}/{league_path}/salaries/"
    if is_current:
        return base_url
    return f"{base_url}{_season_to_capology(season_name)}/"


def _parse_object_fields(object_text: str) -> Dict[str, str]:
    fields: Dict[str, str] = {}
    for line in object_text.splitlines():
        match = re.match(
            r"\s*(['\"])(?P<key>[A-Za-z0-9_]+)\1\s*:\s*(?P<value>.*?),?\s*$",
            line,
        )
        if match:
            fields[match.group("key")] = match.group("value")
    return fields


def _parse_string(value: str) -> str:
    match = re.fullmatch(r"(['\"])(.*?)\1", value.strip())
    if match is None:
        raise ValueError(f"Unsupported Capology string expression: {value}")
    return match.group(2)


def _parse_optional_string(fields: Dict[str, str], field_name: str) -> Optional[str]:
    value = fields.get(field_name)
    if value is None or value.strip() in {"null", "'n/a'", '"n/a"'}:
        return None
    parsed = _parse_string(value).strip()
    return parsed or None


def _parse_optional_age(fields: Dict[str, str]) -> Optional[int]:
    value = fields.get("age")
    if value is None or value.strip() in {"null", "'n/a'", '"n/a"'}:
        return None
    match = re.fullmatch(r'Math\.round\(["\'](?P<age>\d+)["\']\)', value.strip())
    if match is None:
        match = re.fullmatch(r'["\'](?P<age>\d+)["\']', value.strip())
    if match is None:
        raise ValueError(f"Unsupported Capology age expression: {value}")
    return int(match.group("age"))


def _parse_optional_money(
    fields: Dict[str, str],
    field_name: str,
) -> Optional[int]:
    value = fields.get(field_name)
    if value is None or value.strip() in {"'-'", '"-"'}:
        return None
    match = re.search(
        r'accounting\.formatMoney\("(?P<numerator>\d+)"'
        r'(?:/(?P<divisor>\d+))?\s*,',
        value,
    )
    if match is None:
        raise ValueError(
            f"Unsupported Capology money expression for {field_name}: {value}"
        )
    numerator = int(match.group("numerator"))
    divisor = int(match.group("divisor") or "1")
    return (numerator + divisor // 2) // divisor


def _canonical_capology_player_id(external_player_id: str) -> str:
    return VERIFIED_CAPOLOGY_PLAYER_SLUG_ALIASES.get(
        external_player_id,
        external_player_id,
    )


def _capology_position_group_id(
    position: Optional[str],
    detailed_position: Optional[str],
) -> Optional[int]:
    if detailed_position:
        detailed_group_id = CAPOLOGY_POSITION_GROUP_IDS.get(
            detailed_position.upper()
        )
        if detailed_group_id is not None:
            return detailed_group_id
    if position:
        return CAPOLOGY_GENERAL_POSITION_GROUP_IDS.get(position.upper())
    return None


def _parse_capology_salary_page(
    html: str,
    expected_season_name: str,
) -> List[Dict[str, object]]:
    title_match = re.search(
        r"<title>(.*?)</title>",
        html,
        flags=re.DOTALL | re.IGNORECASE,
    )
    if title_match is None:
        raise ValueError("Capology response has no title")
    title = " ".join(unescape(title_match.group(1)).split())
    season_match = re.search(r"\b(\d{4})-(\d{4})\b", title)
    if season_match is None:
        raise ValueError(f"Capology title has no season: {title!r}")
    actual_season_name = f"{season_match.group(1)}/{season_match.group(2)}"
    if actual_season_name != expected_season_name:
        raise ValueError(
            "Capology returned a different season: "
            f"expected={expected_season_name!r}, actual={actual_season_name!r}"
        )

    data_match = re.search(
        r"var\s+data\s*=\s*\[(?P<data>.*?)\]\s*;?\s*"
        r"(?:var\s+data_payroll\s*=|\$\(document\)\.ready)",
        html,
        flags=re.DOTALL,
    )
    if data_match is None:
        raise ValueError("Capology response has no player data array")

    players_by_external_id: Dict[str, Dict[str, object]] = {}
    for object_text in re.findall(
        r"\{\s*(.*?)\s*\},",
        data_match.group("data"),
        flags=re.DOTALL,
    ):
        fields = _parse_object_fields(object_text)
        name_expression = fields.get("name")
        if name_expression is None:
            raise ValueError("Capology player row has no name")
        name_html = _parse_string(name_expression)
        path_match = re.search(r"href=['\"](?P<path>[^'\"]+)", name_html)
        if path_match is None:
            raise ValueError(f"Capology player name has no path: {name_html}")
        player_path = path_match.group("path")
        player_id_match = re.fullmatch(
            r"/player/(?P<player_id>[a-z0-9-]+-\d+)/",
            player_path,
        )
        if player_id_match is None:
            raise ValueError(f"Unsupported Capology player path: {player_path}")

        external_player_id = player_id_match.group("player_id")
        player_name = " ".join(
            unescape(re.sub(r"<[^>]+>", "", name_html)).split()
        )
        position = _parse_optional_string(fields, "position")
        detailed_position = _parse_optional_string(fields, "position_detail")
        source_player = {
            "external_player_id": external_player_id,
            "name": player_name,
            "normalized_name": _normalize_identity_text(player_name),
            "age": _parse_optional_age(fields),
            "country": _parse_optional_string(fields, "country"),
            "position_group_id": _capology_position_group_id(
                position,
                detailed_position,
            ),
            # 화면 기본 통화와 관계없이 Capology가 제공한 EUR 고정 주급을 사용해요.
            "estimated_weekly_gross_eur": _parse_optional_money(
                fields,
                "weekly_gross_eur",
            ),
        }
        existing = players_by_external_id.get(external_player_id)
        if existing is not None and existing != source_player:
            raise ValueError(
                "Capology page repeats a player ID with different data: "
                f"external_player_id={external_player_id}"
            )
        players_by_external_id[external_player_id] = source_player

    if not players_by_external_id:
        raise ValueError("Capology page contains no player rows")
    return list(players_by_external_id.values())


def _load_target_observations(
    season_name: Optional[str] = None,
    competition_id: Optional[int] = None,
) -> List[Dict[str, object]]:
    if (season_name is None) != (competition_id is None):
        raise ValueError("season_name and competition_id must be provided together")
    if season_name is not None:
        start_year = int(_season_to_capology(season_name)[:4])
        if start_year < MIN_SEASON_START_YEAR:
            raise ValueError(
                f"Season {season_name!r} is before the supported minimum 2017/2018"
            )
        if competition_id not in BIG5_COMPETITION_IDS:
            raise ValueError(
                f"Unsupported Big 5 competition_id={competition_id}. "
                f"Allowed ids: {list(BIG5_COMPETITION_IDS)}"
            )

    rows = fetch_all(SQL_SELECT_TARGET_OBSERVATIONS, (MIN_SEASON_START_YEAR,))
    observations = [
        {
            "competition_id": int(row[0]),
            "season_id": int(row[1]),
            "season_name": str(row[2]),
            "team_id": int(row[3]),
            "team_name": str(row[4]),
            "player_id": int(row[5]),
            "display_name": str(row[6]),
            "full_name": str(row[7]),
            "date_of_birth": row[8],
            "country": str(row[9]) if row[9] is not None else None,
            "position_group_id": int(row[10]) if row[10] is not None else None,
            "is_current": bool(row[11]),
        }
        for row in rows
        if season_name is None
        or (str(row[2]) == season_name and int(row[0]) == competition_id)
    ]
    if not observations:
        if season_name is None:
            raise ValueError(
                "team_squad_members contains no Big 5 players from 2017/2018 onward"
            )
        raise ValueError(
            "team_squad_members contains no players for "
            f"season_name={season_name!r}, competition_id={competition_id}"
        )
    return observations


def _observation_name_keys(observation: Dict[str, object]) -> Set[str]:
    return {
        normalized
        for normalized in (
            _normalize_identity_text(str(observation["display_name"])),
            _normalize_identity_text(str(observation["full_name"])),
        )
        if normalized
    }


def _find_available_browser_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.bind(("127.0.0.1", 0))
        return int(server.getsockname()[1])


def _wait_for_cloudflare_verification(port: int, source_url: str) -> None:
    deadline = monotonic() + CLOUDFLARE_VERIFICATION_WAIT_SECONDS
    targets_url = f"http://127.0.0.1:{port}/json"
    while monotonic() < deadline:
        try:
            with urlopen(targets_url, timeout=1) as response:
                targets = json.load(response)
            for target in targets:
                if (
                    target.get("type") == "page"
                    and target.get("url") == source_url
                    and "Just a moment" not in str(target.get("title"))
                ):
                    return
        except OSError:
            pass
        sleep(1)
    raise TimeoutError("Capology Cloudflare verification did not finish")


def _capology_page_is_ready(driver: webdriver.Chrome) -> bool:
    title = driver.title
    # Real Sociedad 캡챠 대기 중 제목이 None으로 와서 중단됐어요. 준비 전 상태로 기다려요.
    return (
        title is not None
        and "Just a moment" not in title
        and driver.execute_script("return document.readyState") == "complete"
    )


def _capology_salary_page_is_ready(driver: webdriver.Chrome) -> bool:
    return _capology_page_is_ready(driver) and "var data = [" in driver.page_source


class _CapologyBrowserSession:
    def __init__(self) -> None:
        if not CAPOLOGY_CHROME_PATH.is_file():
            raise FileNotFoundError(
                f"Chrome was not found: {CAPOLOGY_CHROME_PATH}"
            )

        initial_url = f"{CAPOLOGY_BASE_URL}/"
        CAPOLOGY_CHROME_PROFILE_DIRECTORY.mkdir(parents=True, exist_ok=True)
        self._port = _find_available_browser_port()
        self._driver: Optional[webdriver.Chrome] = None
        self._chrome_process = subprocess.Popen(
            [
                str(CAPOLOGY_CHROME_PATH),
                f"--remote-debugging-port={self._port}",
                f"--user-data-dir={CAPOLOGY_CHROME_PROFILE_DIRECTORY}",
                "--no-first-run",
                "--no-default-browser-check",
                initial_url,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # 적재를 Ctrl+C로 중단해도 전용 Chrome을 함께 닫아요.
        atexit.register(self.close)
        try:
            print(
                "[capology] Chrome에서 'Verify you are human'이 보이면 "
                "직접 체크하세요. 최대 5분 동안 기다립니다.",
                flush=True,
            )
            _wait_for_cloudflare_verification(self._port, initial_url)

            # 처음부터 WebDriver로 열면 검증이 반복돼 일반 Chrome에서 통과한 세션에 연결해요.
            options = webdriver.ChromeOptions()
            options.add_experimental_option(
                "debuggerAddress",
                f"127.0.0.1:{self._port}",
            )
            self._driver = webdriver.Chrome(options=options)
        except Exception:
            self.close()
            raise

    def fetch(self, url: str, *, require_player_data: bool = True) -> Tuple[str, str]:
        if self._driver is None:
            raise RuntimeError("Capology browser session is closed")
        if self._driver.current_url != url:
            self._driver.get(url)
        ready = (
            _capology_salary_page_is_ready
            if require_player_data
            else _capology_page_is_ready
        )
        WebDriverWait(
            self._driver,
            CLOUDFLARE_VERIFICATION_WAIT_SECONDS,
        ).until(ready)
        return self._driver.page_source, self._driver.current_url

    def close(self) -> None:
        if self._driver is not None:
            self._driver.quit()
            self._driver = None
        if self._chrome_process.poll() is None:
            self._chrome_process.terminate()
            self._chrome_process.wait(timeout=10)
