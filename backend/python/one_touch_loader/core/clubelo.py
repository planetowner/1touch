"""ClubElo 공개 페이지에서 팀 식별자와 날짜별 Elo를 읽어요."""

from __future__ import annotations

import json
import math
import re
from datetime import date, datetime
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup, SoupStrainer


BASE_URL = "https://clubelo.com/"
RANKING_URL = urljoin(BASE_URL, "Ranking")


def _country_clubs(soup, countries=None):
    """현재 전력 수집과 과거 이력용 팀 목록 검증이 같은 표 해석을 사용해요."""
    clubs, found = [], set()
    for header in soup.select(".accordion-header a"):
        country = header.get("href", "").strip("/")
        if not re.fullmatch(r"[A-Z]{3}", country) or (countries is not None and country not in countries):
            continue
        found.add(country)
        table = header.find_next("table")
        if table is None:
            raise ValueError(f"ClubElo club table missing: {country}")
        for row in table.find_all("tr"):
            # 닫는 태그가 없는 실제 구분 행에서도 중첩된 팀 행을 두 번 읽지 않아요.
            cells = row.find_all("td", recursive=False)
            if len(cells) != 2:
                continue
            name = cells[0].select_one(".Ast")
            if name is None:
                continue
            link = name.find_parent("a")
            slug = None
            if link:
                url = urlparse(urljoin(BASE_URL, link["href"]))
                slug = url.path.strip("/")
                if url.netloc != "clubelo.com" or not re.fullmatch(r"[A-Za-z0-9_-]+", slug):
                    raise ValueError("Unexpected ClubElo team link")
            raw = cells[1].get_text(strip=True)
            # 일부 하위 리그 행에는 p 표시가 붙어요. 숫자와 원본 표시를 구분해 보존해요.
            rating = re.fullmatch(r"(-?\d+(?:\.\d+)?)(p)?", raw)
            if rating is None:
                raise ValueError(f"Invalid ClubElo Ranking rating: {country}/{name.get_text(strip=True)}")
            clubs.append({"external_team_id": slug, "name": name.get_text(strip=True),
                          "country": country, "elo": float(rating[1]), "rating_marker": rating[2]})
    if countries is not None and set(countries) - found:
        raise ValueError(f"ClubElo country directory missing: {sorted(set(countries) - found)}")
    return clubs


def parse_ranking(html: str) -> dict:
    """Ranking의 국가별 표에서 상세 페이지가 없는 팀도 읽어요."""
    soup = BeautifulSoup(html, "html.parser")
    stamps = re.findall(r"Page created on (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.", soup.get_text())
    if len(stamps) != 1:
        raise ValueError("Expected one ClubElo Ranking publication date")
    published = datetime.strptime(stamps[0], "%Y-%m-%d %H:%M:%S")
    clubs = _country_clubs(soup)
    if not clubs:
        raise ValueError("ClubElo Ranking contains no clubs")
    return {"date": published.date().isoformat(), "published_at": stamps[0], "clubs": clubs}


def ranking_ratings(snapshot: dict, mapping: dict[str, int]) -> dict[int, float]:
    """검증한 링크 ID 또는 국가·원본 이름으로만 연결해요. 유사 이름은 추측하지 않아요."""
    result = {}
    for identifier, team_id in mapping.items():
        if identifier.startswith("ranking:"):
            _, country, name = identifier.split(":", 2)
            matches = [r for r in snapshot["clubs"] if (r["country"], r["name"]) == (country, name)]
        else:
            matches = [r for r in snapshot["clubs"] if r["external_team_id"]
                       and r["external_team_id"].casefold() == identifier.casefold()]
        # Guadalajara처럼 같은 국가에 같은 이름이 두 번 있는 실제 행은 자동 선택하지 않아요.
        if len(matches) != 1:
            raise ValueError(f"Expected one ClubElo Ranking row for {identifier}, found {len(matches)}")
        if team_id in result:
            raise ValueError(f"Duplicate ClubElo team mapping: {team_id}")
        if matches[0]["rating_marker"]:
            raise ValueError(f"Unverified ClubElo rating marker for {identifier}")
        result[team_id] = matches[0]["elo"]
    return result


def parse_directory(html: str, countries: tuple[str, ...]) -> list[dict]:
    soup = BeautifulSoup(html, "html.parser")
    clubs = {}
    for row in _country_clubs(soup, countries):
        slug = row['external_team_id']
        if slug is None:
            continue
        if row['rating_marker']:
            raise ValueError(f"Unverified ClubElo rating marker for {slug}")
        club = {key: value for key, value in row.items() if key != 'rating_marker'}
        club['url'] = urljoin(BASE_URL, slug)
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
        # 정기 갱신은 Ranking 표를, 명시적인 과거 이력 수집은 팀 상세 페이지를 사용해요.
        # ClubElo는 Probability 초기 전력 기준이며, 추후 검증한 자체 모델로 교체할 예정이에요.
        response = self.session.get(urljoin(BASE_URL, slug), timeout=30)
        response.raise_for_status()
        if slug and not urlparse(response.url).path.strip("/"):
            raise ValueError(f"ClubElo redirected to the homepage: {slug}")
        return response.text

    def close(self):
        self.session.close()
