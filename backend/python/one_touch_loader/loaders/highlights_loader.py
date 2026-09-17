"""공식 영상의 경기별 후보를 저장해요. 국가별 최근 3개 선정은 조회할 때 해요."""
from __future__ import annotations

from collections import Counter
from datetime import date, datetime, timedelta, timezone
import json
import os
from pathlib import Path
import requests

from one_touch_loader.core.db import fetch_all, transaction
from one_touch_loader.core.highlight_fixtures import from_dfb_html, from_sportmonks
from one_touch_loader.core.highlights import load_catalog, match_video, normalize_video, select_latest_matches, utc_datetime
from one_touch_loader.core.sportmonks import SportmonksClient


class YouTubeClient:
    def __init__(self):
        self.key = os.environ.get("YOUTUBE_API_KEY")
        if not self.key:
            raise RuntimeError("YOUTUBE_API_KEY is missing")

    def get(self, endpoint, **params):
        try:
            response = requests.get(f"https://www.googleapis.com/youtube/v3/{endpoint}",
                                    params={"key": self.key, **params}, timeout=30)
        except requests.RequestException:
            # 요청 URL과 함께 비밀키가 오류에 출력되지 않게 해요.
            raise RuntimeError(f"YouTube {endpoint} request failed") from None
        if response.status_code != 200:
            raise RuntimeError(f"YouTube {endpoint}: HTTP {response.status_code}")
        return response.json()

    def playlist(self, playlist_id, since, *, uploads=False):
        result, token = [], None
        while True:
            page = self.get("playlistItems", part="snippet,contentDetails", playlistId=playlist_id,
                            maxResults=50, **({"pageToken": token} if token else {}))
            items = page["items"]
            result.extend(i for i in items if i["contentDetails"].get("videoPublishedAt", "") >= since)
            token = page.get("nextPageToken")
            if not token:
                return result
            # 업로드 목록은 최신순이에요. 구단이 정렬하는 일반 재생목록은 끝까지 읽어요.
            if uploads and items and all(i["contentDetails"].get("videoPublishedAt", "9999") < since for i in items):
                return result

    def videos(self, video_ids):
        result = []
        ids = sorted(set(video_ids))
        for start in range(0, len(ids), 50):
            page = self.get("videos", part="snippet,contentDetails,status,player", maxWidth=640,
                            id=",".join(ids[start:start + 50]))
            for item in page["items"]:
                video = normalize_video(item)
                if video is not None:
                    result.append(video)
        return result


def collect_matches(clubs, catalog, to_date):
    client = SportmonksClient()
    since = date.fromisoformat(catalog["from_date"])
    matches = {}
    for index, club in enumerate(clubs, 1):
        for fixture in client.iter_team_fixtures_between_dates(
                club["team_id"], since, to_date, "participants;state;scores;league"):
            match = from_sportmonks(fixture, catalog["season_name"])
            if match:
                matches[match["match_key"]] = match
        print(f"[highlights fixtures {index}/{len(clubs)}] {club['team_name']}", flush=True)
    if any(club["league_id"] == 82 for club in clubs):
        for source in catalog["external_fixture_sources"]:
            response = requests.get(source["url"], timeout=30)
            response.raise_for_status()
            for match in from_dfb_html(response.text, source, catalog["dfb_team_names"]):
                if since <= utc_datetime(match["starting_at"]).date() <= to_date:
                    matches[match["match_key"]] = match
    team_ids = {club["team_id"] for club in clubs}
    return [m for m in matches.values() if team_ids & {m["home"].get("team_id"), m["away"].get("team_id")}]


def collect_candidates(clubs, catalog, matches, youtube, *, since=None, saved_ids=None):
    since = since or catalog["from_date"]
    saved_ids = saved_ids or {}
    competition_keys = {m["competition_key"] for m in matches}
    sources = [*clubs, *(s for s in catalog["competitions"] if competition_keys & set(s["competition_keys"]))]
    items_by_channel, highlights_by_channel = {}, {}
    for index, source in enumerate(sources, 1):
        items = youtube.playlist(source["uploads_playlist_id"], since, uploads=True)
        # 지난번에 경기 영상으로 확인한 ID도 메타데이터를 다시 읽어 삭제·국가 제한을 반영해요.
        highlight_ids = set(saved_ids.get(source["channel_id"], []))
        for playlist in source["playlists"]:
            # 나중에 재생목록에 추가된 기존 영상도 있어요. 목록은 시즌 범위를 다시 대조해요.
            extra = youtube.playlist(playlist["playlist_id"], catalog["from_date"])
            items.extend(extra)
            highlight_ids.update(v["contentDetails"]["videoId"] for v in extra)
        items_by_channel[source["channel_id"]] = {v["contentDetails"]["videoId"] for v in items} | highlight_ids
        highlights_by_channel[source["channel_id"]] = highlight_ids
        print(f"[highlights channels {index}/{len(sources)}] {source['channel_name']}", flush=True)
    ids = set().union(*items_by_channel.values()) if sources else set()
    by_channel = {}
    for video in youtube.videos(ids):
        by_channel.setdefault(video["channel_id"], []).append(video)
    candidates = {club["team_id"]: {} for club in clubs}
    reasons, ambiguous = Counter(), []
    for source in sources:
        for video in by_channel.get(source["channel_id"], []):
            match, reason = match_video(video, matches, source, catalog["aliases"],
                                        highlights_by_channel[source["channel_id"]])
            reasons[reason] += 1
            if reason == "ambiguous_match":
                ambiguous.append({"video_id": video["video_id"], "title": video["title"]})
            if not match:
                continue
            target_ids = [source["team_id"]] if source["kind"] == "club" else [match["home"].get("team_id"), match["away"].get("team_id")]
            value = {**video, "match": match, "source_type": source["kind"]}
            value.pop("description")
            for team_id in target_ids:
                if team_id in candidates:
                    candidates[team_id][video["video_id"]] = value
    return {key: list(value.values()) for key, value in candidates.items()}, dict(reasons), ambiguous


def save_candidates(clubs, candidates, checked_at):
    # 3개로 잘라 저장하면 국가 제한을 적용할 때 대안이 사라져요. 검증한 후보를 함께 저장해요.
    with transaction() as connection:
        with connection.cursor() as cursor:
            for club in clubs:
                team_id = club["team_id"]
                cursor.execute("""INSERT INTO team_youtube_sources
                    (team_id,team_name,channel_id,channel_url,source_mode,max_candidate_items,is_active,created_at,updated_at)
                    VALUES (%s,%s,%s,%s,'verified_matches',50,1,%s,%s)
                    ON DUPLICATE KEY UPDATE team_name=VALUES(team_name),channel_id=VALUES(channel_id),
                      channel_url=VALUES(channel_url),source_mode=VALUES(source_mode),
                      include_title_keywords=NULL,exclude_title_keywords=NULL,is_active=1,updated_at=VALUES(updated_at)""",
                    (team_id, club["team_name"], club["channel_id"], club["channel_url"], checked_at, checked_at))
                cursor.execute("UPDATE team_youtube_playlists SET is_active=0 WHERE team_id=%s", (team_id,))
                for playlist in club["playlists"]:
                    cursor.execute("""INSERT INTO team_youtube_playlists
                        (team_id,playlist_name,playlist_id,playlist_url,is_active,created_at,updated_at)
                        VALUES (%s,%s,%s,%s,1,UTC_TIMESTAMP(),UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE
                        playlist_name=VALUES(playlist_name),playlist_url=VALUES(playlist_url),is_active=1,updated_at=UTC_TIMESTAMP()""",
                        (team_id, playlist["name"], playlist["playlist_id"], f"https://www.youtube.com/playlist?list={playlist['playlist_id']}"))
                cursor.execute("DELETE FROM team_highlights_cache WHERE team_id=%s", (team_id,))
                rows = []
                for rank, video in enumerate(candidates[team_id], 1):
                    metadata = {key: video[key] for key in ("channel_id", "channel_name", "duration_seconds", "region_restriction", "embeddable", "is_extended")}
                    rows.append((team_id, video["video_id"], video["video_url"], video["title"], video["thumbnail_url"],
                                 utc_datetime(video["published_at"]).replace(tzinfo=None), video["source_type"], video["channel_id"], rank,
                                 video["match"]["match_key"], json.dumps(video["match"], ensure_ascii=False), json.dumps(metadata, ensure_ascii=False),
                                 checked_at, checked_at))
                if rows:
                    cursor.executemany("""INSERT INTO team_highlights_cache
                        (team_id,video_id,video_url,title,thumbnail_url,published_at,source_type,source_ref,rank_order,
                         match_key,match_data,video_data,created_at,updated_at)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""", rows)


def load_saved_sources(clubs):
    placeholders = ",".join("%s" for _ in clubs)
    params = tuple(c["team_id"] for c in clubs)
    previous = fetch_all(f"""SELECT team_id,updated_at FROM team_youtube_sources
        WHERE source_mode='verified_matches' AND team_id IN ({placeholders})""", params)
    if len(previous) != len(clubs):
        return None, {}
    saved = fetch_all(f"""SELECT source_ref,video_id FROM team_highlights_cache
        WHERE team_id IN ({placeholders}) AND match_key IS NOT NULL""", params)
    ids = {}
    for channel_id, video_id in saved:
        ids.setdefault(channel_id, set()).add(video_id)
    # 업로드 시점에는 경기 결과·영상 처리가 늦을 수 있어 최근 7일을 다시 대조해요.
    since = (min(utc_datetime(row[1]) for row in previous) - timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")
    return since, ids


def refresh_highlights(team_ids=None, *, apply=False, report_dir=None, full_scan=False):
    catalog = load_catalog()
    clubs = [c for c in catalog["clubs"] if not team_ids or c["team_id"] in team_ids]
    if team_ids and set(team_ids) != {c["team_id"] for c in clubs}:
        raise ValueError("Team is not in the verified 2026/27 Big Five source catalog")
    # 시작 시각을 저장해야 수집 중 올라온 영상도 다음 실행에서 빠짐없이 다시 확인해요.
    checked_at = datetime.now(timezone.utc)
    since, saved_ids = (None, {}) if full_scan else load_saved_sources(clubs)
    matches = collect_matches(clubs, catalog, checked_at.date())
    candidates, reasons, ambiguous = collect_candidates(clubs, catalog, matches, YouTubeClient(), since=since, saved_ids=saved_ids)
    report = {"checked_at": checked_at.isoformat(), "apply": apply, "reasons": reasons,
              "ambiguous_excluded": ambiguous, "teams": []}
    for club in clubs:
        team_id = club["team_id"]
        report["teams"].append({"team_id": team_id, "team_name": club["team_name"],
                                "candidates": candidates[team_id], "regions": {
                                    country: select_latest_matches(candidates[team_id], country) for country in ("KR", "JP", "US", "GB")}})
    folder = Path(report_dir) if report_dir else Path(__file__).resolve().parents[3] / "logs/highlights" / checked_at.strftime("%Y%m%dT%H%M%S%fZ")
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    if apply:
        save_candidates(clubs, candidates, checked_at.replace(tzinfo=None))
    print(f"Highlights: teams={len(clubs)}, candidates={sum(map(len, candidates.values()))}, apply={apply}")
    print(f"Report: {folder / 'report.json'}")
    return report


def run_cli(arguments):
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["refresh"])
    parser.add_argument("team_ids", nargs="?", help="comma-separated team IDs; omit for all 96")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="save verified candidates and sources")
    mode.add_argument("--check", action="store_true", help="read sources and create a local report only (default)")
    parser.add_argument("--report-dir")
    parser.add_argument("--full-scan", action="store_true", help="rescan the season instead of only new uploads and saved candidates")
    args = parser.parse_args(arguments)
    ids = [int(value) for value in args.team_ids.split(",")] if args.team_ids else None
    return refresh_highlights(ids, apply=args.apply, report_dir=args.report_dir, full_scan=args.full_scan)
