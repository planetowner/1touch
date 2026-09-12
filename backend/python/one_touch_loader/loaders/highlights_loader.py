from __future__ import annotations

import html
import os
from datetime import datetime
from typing import Dict, List, Optional, Tuple

import requests

from one_touch_loader.core.db import execute, fetch_all, transaction


# =========================================================
# 상수
# =========================================================

YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")

YOUTUBE_API_BASE = "https://www.googleapis.com/youtube/v3"
HTTP_TIMEOUT_SECONDS = 30

# team_youtube_sources 스키마를 확인한 결과 두 값만 있고, 둘 다 NOT NULL이에요.
VALID_SOURCE_MODES = frozenset({"playlists", "channel_rules"})

# YouTube API v3 playlistItems 응답을 확인했어요. 모든 영상에는 default, medium,
# high가 있고 HD 원본에만 standard와 maxres가 있어요. API가 준 썸네일 가운데
# 해상도가 가장 높은 것을 우선해요.
THUMBNAIL_PRIORITY: Tuple[str, ...] = ("maxres", "standard", "high", "medium", "default")

# YouTube API 시각은 "2026-06-19T14:00:30Z" 같은 RFC 3339 UTC 형식이에요.
YOUTUBE_DATETIME_FORMAT = "%Y-%m-%dT%H:%M:%SZ"

TOP_N_HIGHLIGHTS = 3


# =========================================================
# 값을 엄격하게 확인하는 도우미
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
# DB 조회
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
# YouTube API 호출
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
# 후보 만들기
# =========================================================

def _pick_thumbnail_url(thumbnails: Dict) -> str:
    """API가 반환한 썸네일 가운데 해상도가 가장 높은 URL을 골라요.

    v3 API에서 'default'는 항상 오는 것을 확인했어요. 따라서 반복문은 최소한
    default 크기를 찾아요.
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
    YouTube playlistItems 응답 항목 하나를 하이라이트 후보로 만들어요.

    비공개·삭제 영상은 None을 반환하고 건너뛰어요. 하이라이트로 쓸 수 없고,
    API도 아래 필드를 주지 않기 때문이에요. 제목은 "Private video" 또는
    "Deleted video"로 와요.

    v3 API(part=snippet,contentDetails)에서 확인한 규칙이에요.
      - 재생 가능한 영상에는 snippet.resourceId.videoId와 contentDetails.videoId가
        모두 있고 값도 같아요. 삭제 영상에는 없어요.
      - snippet.publishedAt은 항목이 재생목록에 추가된 시각이에요.
      - contentDetails.videoPublishedAt은 영상이 YouTube에 올라온 시각이에요.
        채널이 재생목록에 다시 넣은 시각보다 영상의 최신성이 중요하므로 이 값을 써요.
        비공개·삭제 영상에는 없어요.
      - snippet.thumbnails에는 최소한 default, medium, high가 있어요.
        API가 준 값 가운데 해상도가 가장 높은 것을 골라요.
    """
    snippet = _require_dict(item["snippet"], "playlistItem.snippet")
    content = _require_dict(item["contentDetails"], "playlistItem.contentDetails")

    # 비공개·삭제 영상에는 videoId나 videoPublishedAt이 없을 수 있어요.
    # 어느 재생목록에든 생길 수 있으므로 오류를 내지 않고 해당 영상만 건너뛰어요.
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
# 팀별 후보 수집
# =========================================================

def _collect_playlist_candidates(team_cfg: Dict) -> List[Dict]:
    playlists = _load_team_playlists(team_cfg["team_id"])
    max_items = team_cfg["max_candidate_items"]
    candidates: List[Dict] = []

    for playlist in playlists:
        playlist_id = playlist["playlist_id"]
        items = _fetch_playlist_items(playlist_id, max_results=max_items)

        for item in items:
            candidate = _build_candidate_from_playlist_item(
                item,
                source_type="playlist",
                source_ref=playlist_id,
            )
            if candidate is not None:
                candidates.append(candidate)

    return _dedupe_by_video_id(candidates)


def _collect_channel_rule_candidates(team_cfg: Dict) -> List[Dict]:
    channel_id = team_cfg["channel_id"]
    max_items = team_cfg["max_candidate_items"]

    uploads_playlist_id = _fetch_uploads_playlist_id(channel_id)
    items = _fetch_playlist_items(uploads_playlist_id, max_results=max_items)

    candidates: List[Dict] = []

    for item in items:
        candidate = _build_candidate_from_playlist_item(
            item,
            source_type="channel_uploads",
            source_ref=uploads_playlist_id,
        )
        if candidate is not None:
            candidates.append(candidate)

    return _dedupe_by_video_id(candidates)


# =========================================================
# 필터링과 정렬
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
# 저장
# =========================================================

def _replace_team_highlights(team_id: int, top: List[Dict]) -> None:
    """한 팀의 캐시 행을 한 트랜잭션에서 바꿔요.

    DELETE와 executemany(INSERT)를 한 트랜잭션에서 실행해요. 쓰는 중에 실패하면
    이전 캐시를 그대로 두고, 성공하면 새 캐시 전체를 커밋해요.
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
# 외부에서 쓰는 함수
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
            candidates = _collect_playlist_candidates(team_cfg)
        else:
            candidates = _collect_channel_rule_candidates(team_cfg)

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
