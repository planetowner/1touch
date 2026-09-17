"""ClubElo 공개 페이지에서 팀 식별자와 날짜별 Elo를 읽어요."""

from __future__ import annotations

import json
import math
import re
from datetime import date
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup, SoupStrainer


BASE_URL = "https://clubelo.com/"


def parse_directory(html: str, countries: tuple[str, ...]) -> list[dict]:
    soup = BeautifulSoup(html, "html.parser")
    clubs = {}
    for country in countries:
        header = next((a for a in soup.select(".accordion-header a")
                       if a.get("href", "").strip("/") == country), None)
        if header is None:
            raise ValueError(f"ClubElo country directory missing: {country}")
        table = header.find_next("table")
        if table is None:
            raise ValueError(f"ClubElo club table missing: {country}")
        for row in table.find_all("tr"):
            # 공개 표의 일부 구분 행에는 닫는 태그가 없어요. 중첩된 행을 두 번 읽지 않아요.
            cells = row.find_all("td", recursive=False)
            if len(cells) != 2:
                continue
            name = cells[0].select_one("a .Ast")
            if name is None:
                continue
            link = name.find_parent("a")["href"]
            url = urljoin(BASE_URL, link)
            slug = urlparse(url).path.strip("/")
            if urlparse(url).netloc != "clubelo.com" or not re.fullmatch(r"[A-Za-z0-9-]+", slug):
                raise ValueError("Unexpected ClubElo team link")
            club = {"external_team_id": slug, "name": name.get_text(strip=True),
                    "country": country, "elo": float(cells[1].get_text(strip=True)), "url": url}
            if not math.isfinite(club["elo"]):
                raise ValueError(f"Invalid ClubElo rating: {slug}")
            if slug in clubs and clubs[slug] != club:
                raise ValueError(f"Conflicting ClubElo directory rows: {slug}")
            clubs[slug] = club
    return list(clubs.values())


def parse_history(html: str) -> list[dict]:
    soup = BeautifulSoup(html, "html.parser", parse_only=SoupStrainer("script"))
    histories = []
    for script in soup.find_all("script"):
        text = script.get_text()
        for marker in re.finditer(r"\bvar\s+vegaJson\s*=\s*", text):
            # 스크립트를 실행하지 않고, 차트에 들어 있는 JSON 값만 읽어요.
            spec, _ = json.JSONDecoder().raw_decode(text[marker.end():])
            for dataset in spec.get("datasets", {}).values():
                if dataset and all(isinstance(row, dict) and {"Date", "Elo"} <= row.keys()
                                   for row in dataset):
                    histories.append(dataset)
    if len(histories) != 1:
        raise ValueError("Expected one ClubElo dated Elo history")
    points = {}
    for row in histories[0]:
        day = date.fromisoformat(row["Date"][:10])
        value = float(row["Elo"])
        if not math.isfinite(value):
            raise ValueError(f"Invalid ClubElo Elo on {day}")
        point = {"date": day.isoformat(), "elo": value, "segment_id": row["segment_id"]}
        if day in points and points[day] != point:
            raise ValueError(f"Conflicting ClubElo history on {day}")
        points[day] = point
    return [points[day] for day in sorted(points)]


def parse_calculation_results(html: str) -> list[dict]:
    """팀 매칭 검증에 쓰는 최근 경기 날짜·홈/원정·상대·점수를 읽어요."""
    soup = BeautifulSoup(html, "html.parser", parse_only=SoupStrainer("table"))
    tables = [t for t in soup.find_all("table")
              if "Prior Δ" in t.get_text() and "New Elo" in t.get_text()]
    if len(tables) != 1:
        raise ValueError("Expected one ClubElo calculation table")
    results = []
    for row in tables[0].find_all("tr"):
        cells = row.find_all("td", recursive=False)
        if not cells:
            continue
        # Saint-Étienne–Rodez(2026-05-15)는 FT 열부터 없어요. 결과가 없는 행은 대조하지 않아요.
        if len(cells) == 6:
            continue
        day_link = cells[0].find("a", href=True)
        if len(cells) < 9 or day_link is None:
            raise ValueError("Incomplete ClubElo calculation row")
        day = date.fromisoformat(day_link["href"].strip("/"))
        side = cells[1].get_text(strip=True)
        score = re.fullmatch(r"(\d+)-(\d+)", cells[6].get_text(strip=True))
        opponent = [a for a in cells[2].find_all("a", href=True) if a.find("img") is None]
        if side not in {"H", "A", "N"} or score is None or len(opponent) > 1:
            raise ValueError(f"Unrecognized ClubElo result on {day}")
        # Calculation 표의 FT는 홈팀 기준이 아니라 이 페이지의 팀 기준이에요.
        results.append({"date": day.isoformat(), "side": side,
                        # Port Vale·Bolton처럼 이름만 있고 팀 링크가 없는 상대는 매칭에서 제외해요.
                        "opponent": opponent[0]["href"].strip("/") if opponent else None,
                        "goals_for": int(score[1]), "goals_against": int(score[2])})
    return results


def rating_before(history: list[dict], match_date: date) -> float | None:
    """경기 결과를 미리 학습하지 않도록 같은 날의 경기 후 Elo를 제외해요."""
    eligible = [point for point in history if date.fromisoformat(point["date"]) < match_date]
    if not eligible:
        return None
    return float(max(eligible, key=lambda point: point["date"])["elo"])


class ClubEloClient:
    def __init__(self):
        self.session = requests.Session()

    def get_html(self, slug: str = "") -> str:
        if slug and not re.fullmatch(r"[A-Za-z0-9-]+", slug):
            raise ValueError("Use a ClubElo team identifier from a verified page link")
        # 2026-09-17 API가 502를 반환해 공개 HTML을 사용해요.
        # API가 복구되면 실제 응답을 검증한 뒤 수집 경로를 API로 되돌려요.
        # ClubElo는 Probability 초기 전력 기준이며, 추후 검증한 자체 모델로 교체할 예정이에요.
        response = self.session.get(urljoin(BASE_URL, slug), timeout=30)
        response.raise_for_status()
        if slug and not urlparse(response.url).path.strip("/"):
            raise ValueError(f"ClubElo redirected to the homepage: {slug}")
        return response.text

    def close(self):
        self.session.close()
