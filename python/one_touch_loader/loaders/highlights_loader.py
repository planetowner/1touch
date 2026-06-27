from __future__ import annotations

import html
import os
from datetime import datetime
from typing import Dict, List, Optional, Tuple

import requests

from one_touch_loader.core.db import execute, fetch_all, transaction


# =========================================================
# Constants
# =========================================================

YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")

YOUTUBE_API_BASE = "https://www.googleapis.com/youtube/v3"
HTTP_TIMEOUT_SECONDS = 30

# Verified against team_youtube_sources schema (DB scan): exactly these two
# values appear, NOT NULL.
VALID_SOURCE_MODES = frozenset({"playlists", "channel_rules"})

# Verified against YouTube API v3 playlistItems response:
# every video carries default/medium/high; standard/maxres only for HD source.
# Priority picks the highest-resolution thumbnail that the API returned.
THUMBNAIL_PRIORITY: Tuple[str, ...] = ("maxres", "standard", "high", "medium", "default")

# YouTube API returns timestamps in RFC 3339 UTC form, e.g. "2026-06-19T14:00:30Z".
YOUTUBE_DATETIME_FORMAT = "%Y-%m-%dT%H:%M:%SZ"

TOP_N_HIGHLIGHTS = 3


# =========================================================
# Strict helpers
# =========================================================

def _require_int(value, field_name: str) -> int:
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer field: {field_name}={value!r}")

    return value


def _require_non_empty_str(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string field: {field_name}={value!r}")

    return value.strip()


def _require_optional_str(value, field_name: str) -> Optional[str]:
    if value is None:
        return None

    if not isinstance(value, str):
        raise ValueError(f"Invalid optional string field: {field_name}={value!r}")

    return value


def _require_dict(value, field_name: str) -> Dict:
    if not isinstance(value, dict):
        raise ValueError(f"Missing or invalid object field: {field_name}={value!r}")

    return value


def _require_source_mode(value: str) -> str:
    if value not in VALID_SOURCE_MODES:
        raise ValueError(
            f"Unsupported source_mode {value!r}. "
            f"Expected one of {sorted(VALID_SOURCE_MODES)}."
        )

    return value


def _parse_youtube_datetime(value: str) -> datetime:
    return datetime.strptime(value, YOUTUBE_DATETIME_FORMAT)


def _normalize_text(value: str) -> str:
    return html.unescape(value).strip()


def _split_keywords_csv(value: Optional[str]) -> List[str]:
    if value is None:
        return []

    return [token.strip().lower() for token in value.split(",") if token.strip()]


# =========================================================
# DB readers
# =========================================================

def _load_team_sources(team_ids: Optional[List[int]]) -> List[Dict]:
    sql = """
    SELECT
        team_id, team_name, channel_id, channel_url, source_mode,
        include_title_keywords, exclude_title_keywords,
        max_candidate_items
    FROM team_youtube_sources
    WHERE is_active = 1
    """

    params: Tuple = ()

    if team_ids:
        placeholders = ",".join(["%s"] * len(team_ids))
        sql += f" AND team_id IN ({placeholders})"
        params = tuple(team_ids)

    sql += " ORDER BY team_id"

    rows = fetch_all(sql, params)
    sources: List[Dict] = []

    for row in rows:
        sources.append(
            {
                "team_id": _require_int(row[0], "team_youtube_sources.team_id"),
                "team_name": _require_non_empty_str(row[1], "team_youtube_sources.team_name"),
                "channel_id": _require_non_empty_str(row[2], "team_youtube_sources.channel_id"),
                "channel_url": _require_optional_str(row[3], "team_youtube_sources.channel_url"),
                "source_mode": _require_source_mode(
                    _require_non_empty_str(row[4], "team_youtube_sources.source_mode")
                ),
                "include_title_keywords": _split_keywords_csv(row[5]),
                "exclude_title_keywords": _split_keywords_csv(row[6]),
                "max_candidate_items": _require_int(
                    row[7],
                    "team_youtube_sources.max_candidate_items",
                ),
            }
        )

    return sources


def _load_team_playlists(team_id: int) -> List[Dict]:
    rows = fetch_all(
        """
        SELECT playlist_name, playlist_id, playlist_url
        FROM team_youtube_playlists
        WHERE team_id = %s
          AND is_active = 1
        ORDER BY id
        """,
        (team_id,),
    )

    playlists: List[Dict] = []

    for row in rows:
        playlists.append(
            {
                "playlist_name": _require_optional_str(
                    row[0],
                    "team_youtube_playlists.playlist_name",
                ),
                "playlist_id": _require_non_empty_str(
                    row[1],
                    "team_youtube_playlists.playlist_id",
                ),
                "playlist_url": _require_optional_str(
                    row[2],
                    "team_youtube_playlists.playlist_url",
                ),
            }
        )

    return playlists


# =========================================================
# YouTube API
# =========================================================

def _yt_get(path: str, params: Dict) -> Dict:
    if not YOUTUBE_API_KEY:
        raise RuntimeError("YOUTUBE_API_KEY is missing")

    full_params = {"key": YOUTUBE_API_KEY, **params}
    response = requests.get(
        f"{YOUTUBE_API_BASE}/{path}",
        params=full_params,
        timeout=HTTP_TIMEOUT_SECONDS,
    )
    response.raise_for_status()

    return response.json()


def _fetch_uploads_playlist_id(channel_id: str) -> str:
    data = _yt_get(
        "channels",
        {"part": "contentDetails", "id": channel_id},
    )

    return _require_non_empty_str(
        data["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"],
        "channels.contentDetails.relatedPlaylists.uploads",
    )


def _fetch_playlist_items(playlist_id: str, max_results: int) -> List[Dict]:
    data = _yt_get(
        "playlistItems",
        {
            "part": "snippet,contentDetails",
            "playlistId": playlist_id,
            "maxResults": max_results,
        },
    )

    return data["items"]


# =========================================================
# Candidate construction
# =========================================================

def _pick_thumbnail_url(thumbnails: Dict) -> str:
    """Return the highest-resolution thumbnail URL the API returned.

    Verified against the v3 API: 'default' is always present, so the loop
    is guaranteed to hit at least that size.
    """
    for size in THUMBNAIL_PRIORITY:
        if size in thumbnails:
            return _require_non_empty_str(
                thumbnails[size]["url"],
                f"thumbnails.{size}.url",
            )


def _build_candidate_from_playlist_item(
    item: Dict,
    *,
    source_type: str,
    source_ref: str,
) -> Optional[Dict]:
    """
    Build a single candidate from a YouTube playlistItems response item.

    Returns None for private or deleted videos, which we skip rather than
    treat as an error: such items are unusable as highlights and the API
    omits the fields below for them (the item's title shows up as
    "Private video" / "Deleted video").

    Verified against the v3 API (part=snippet,contentDetails):
      - snippet.resourceId.videoId and contentDetails.videoId are both present
        and equal for playable videos, but absent for deleted ones.
      - snippet.publishedAt = when this item was added to the playlist.
      - contentDetails.videoPublishedAt = when the video itself was uploaded
        to YouTube. We use this one because users care about video recency,
        not when the channel re-added it to a playlist. Absent for
        private/deleted videos.
      - snippet.thumbnails always has at least default/medium/high; we pick
        the highest-resolution size that the API returned.
    """
    snippet = _require_dict(item["snippet"], "playlistItem.snippet")
    content = _require_dict(item["contentDetails"], "playlistItem.contentDetails")

    # Private/deleted videos omit videoId and/or videoPublishedAt. They can
    # appear in any playlist at any time, so skip them instead of crashing.
    video_id = content.get("videoId")
    published_at_raw = content.get("videoPublishedAt")
    if not video_id or not published_at_raw:
        return None

    video_id = _require_non_empty_str(video_id, "contentDetails.videoId")

    published_at_dt = _parse_youtube_datetime(
        _require_non_empty_str(
            published_at_raw,
            "contentDetails.videoPublishedAt",
        )
    )

    title = _normalize_text(snippet["title"])
    thumbnails = _require_dict(snippet["thumbnails"], "snippet.thumbnails")

    return {
        "video_id": video_id,
        "video_url": f"https://www.youtube.com/watch?v={video_id}",
        "title": title,
        "thumbnail_url": _pick_thumbnail_url(thumbnails),
        "published_at_dt": published_at_dt,
        "source_type": source_type,
        "source_ref": source_ref,
    }


def _dedupe_by_video_id(candidates: List[Dict]) -> List[Dict]:
    seen: set = set()
    result: List[Dict] = []

    for candidate in candidates:
        video_id = candidate["video_id"]

        if video_id in seen:
            continue

        seen.add(video_id)
        result.append(candidate)

    return result


# =========================================================
# Per-team candidate collection
# =========================================================

def _collect_playlist_candidates(team_cfg: Dict) -> Tuple[List[Dict], bool]:
    """Returns (candidates, had_failure).

    `had_failure=True` when any playlist fetch raised — the caller must NOT
    treat the partial result as authoritative, since some playlists may have
    contributed highlights that are now missing from `candidates`.
    """
    playlists = _load_team_playlists(team_cfg["team_id"])
    max_items = team_cfg["max_candidate_items"]
    candidates: List[Dict] = []
    had_failure = False

    for playlist in playlists:
        playlist_id = playlist["playlist_id"]

        try:
            items = _fetch_playlist_items(playlist_id, max_results=max_items)
        except requests.RequestException as error:
            print(
                f"  [highlights] playlist fetch error "
                f"team={team_cfg['team_name']!r} playlist_id={playlist_id!r}: {error}"
            )
            had_failure = True
            continue

        for item in items:
            candidate = _build_candidate_from_playlist_item(
                item,
                source_type="playlist",
                source_ref=playlist_id,
            )
            if candidate is not None:
                candidates.append(candidate)

    return _dedupe_by_video_id(candidates), had_failure


def _collect_channel_rule_candidates(team_cfg: Dict) -> Tuple[List[Dict], bool]:
    """Returns (candidates, had_failure). See _collect_playlist_candidates."""
    channel_id = team_cfg["channel_id"]
    max_items = team_cfg["max_candidate_items"]

    try:
        uploads_playlist_id = _fetch_uploads_playlist_id(channel_id)
    except requests.RequestException as error:
        print(
            f"  [highlights] uploads playlist lookup error "
            f"team={team_cfg['team_name']!r}: {error}"
        )
        return [], True

    try:
        items = _fetch_playlist_items(uploads_playlist_id, max_results=max_items)
    except requests.RequestException as error:
        print(
            f"  [highlights] uploads fetch error team={team_cfg['team_name']!r}: {error}"
        )
        return [], True

    candidates: List[Dict] = []

    for item in items:
        candidate = _build_candidate_from_playlist_item(
            item,
            source_type="channel_uploads",
            source_ref=uploads_playlist_id,
        )
        if candidate is not None:
            candidates.append(candidate)

    return _dedupe_by_video_id(candidates), False


# =========================================================
# Filtering & sorting
# =========================================================

def _passes_keyword_filters(candidate: Dict, team_cfg: Dict) -> bool:
    title_lower = candidate["title"].lower()
    includes = team_cfg["include_title_keywords"]
    excludes = team_cfg["exclude_title_keywords"]

    if includes and not any(kw in title_lower for kw in includes):
        return False

    if excludes and any(kw in title_lower for kw in excludes):
        return False

    return True


def _sort_candidates_latest_first(candidates: List[Dict]) -> List[Dict]:
    return sorted(candidates, key=lambda c: c["published_at_dt"], reverse=True)


# =========================================================
# Persistence
# =========================================================

def _replace_team_highlights(team_id: int, top: List[Dict]) -> None:
    """Atomically replace one team's cache rows.

    DELETE + executemany(INSERT) run in a single transaction so a mid-write
    failure either leaves the previous cache intact or commits the new one.
    """
    insert_rows = [
        (
            team_id,
            candidate["video_id"],
            candidate["video_url"],
            candidate["title"],
            candidate["thumbnail_url"],
            candidate["published_at_dt"].strftime("%Y-%m-%d %H:%M:%S"),
            candidate["source_type"],
            candidate["source_ref"],
            rank_order,
        )
        for rank_order, candidate in enumerate(top, start=1)
    ]

    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM team_highlights_cache WHERE team_id = %s",
                (team_id,),
            )

            if insert_rows:
                cur.executemany(
                    """
                    INSERT INTO team_highlights_cache (
                        team_id, video_id, video_url, title, thumbnail_url,
                        published_at, source_type, source_ref, rank_order,
                        created_at, updated_at
                    ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW(),NOW())
                    """,
                    insert_rows,
                )


# =========================================================
# Public API
# =========================================================

def refresh_highlights(team_ids: Optional[List[int]] = None) -> None:
    if not YOUTUBE_API_KEY:
        raise RuntimeError("YOUTUBE_API_KEY is missing")

    team_sources = _load_team_sources(team_ids)

    for team_cfg in team_sources:
        team_id = team_cfg["team_id"]
        team_name = team_cfg["team_name"]
        source_mode = team_cfg["source_mode"]

        print(f"[highlights] processing team={team_name!r} source_mode={source_mode!r}")

        if source_mode == "playlists":
            candidates, had_failure = _collect_playlist_candidates(team_cfg)
        elif source_mode == "channel_rules":
            candidates, had_failure = _collect_channel_rule_candidates(team_cfg)
        else:
            raise AssertionError(f"Unreachable source_mode={source_mode!r}")

        if had_failure:
            print(
                f"  [highlights] one or more YouTube fetches failed; "
                f"keeping existing cache for team {team_id}"
            )
            continue

        if not candidates:
            print(f"  [highlights] no candidates collected; clearing cache")
            execute(
                "DELETE FROM team_highlights_cache WHERE team_id = %s",
                (team_id,),
            )
            continue

        filtered = [c for c in candidates if _passes_keyword_filters(c, team_cfg)]
        filtered = _sort_candidates_latest_first(filtered)

        print(
            f"  [highlights] collected={len(candidates)} filtered={len(filtered)}"
        )

        if not filtered:
            for c in candidates[:10]:
                print(
                    f"    rejected: {c['title']!r} "
                    f"({c['published_at_dt'].isoformat()})"
                )
            execute(
                "DELETE FROM team_highlights_cache WHERE team_id = %s",
                (team_id,),
            )
            continue

        top = filtered[:TOP_N_HIGHLIGHTS]
        _replace_team_highlights(team_id, top)

        for rank_order, candidate in enumerate(top, start=1):
            print(
                f"  [highlights] saved rank {rank_order}: "
                f"{candidate['title']!r} "
                f"({candidate['published_at_dt'].isoformat()}, {candidate['source_type']})"
            )

    print("[highlights] refresh done")
