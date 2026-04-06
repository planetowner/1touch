import os
import html
import requests
from datetime import datetime

from one_touch_loader.core.db import fetch_all, execute

YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")


def safe_text(value):
    if not value:
        return ""
    return html.unescape(str(value)).strip()


def normalize_text(value):
    return safe_text(value).lower()


def split_csv(value):
    if not value:
        return []
    return [x.strip().lower() for x in str(value).split(",") if x.strip()]


def parse_yt_datetime(value):
    if not value:
        return None
    return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")


def yt_datetime_to_mysql(value):
    dt = parse_yt_datetime(value)
    if not dt:
        return None
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def pick_thumbnail(snippet):
    thumbs = snippet.get("thumbnails", {})
    if "high" in thumbs:
        return thumbs["high"].get("url")
    if "medium" in thumbs:
        return thumbs["medium"].get("url")
    if "default" in thumbs:
        return thumbs["default"].get("url")
    return None


def get_team_sources(team_ids=None):
    sql = """
        SELECT
            team_id,
            team_name,
            channel_id,
            channel_url,
            source_mode,
            include_title_keywords,
            exclude_title_keywords,
            notes,
            max_candidate_items
        FROM team_youtube_sources
        WHERE is_active = 1
    """
    params = ()

    if team_ids:
        placeholders = ",".join(["%s"] * len(team_ids))
        sql += f" AND team_id IN ({placeholders})"
        params = tuple(team_ids)

    sql += " ORDER BY team_id"

    rows = fetch_all(sql, params)
    out = []
    for r in rows:
        out.append({
            "team_id": int(r[0]),
            "team_name": r[1],
            "channel_id": r[2],
            "channel_url": r[3],
            "source_mode": r[4],
            "include_title_keywords": split_csv(r[5]),
            "exclude_title_keywords": split_csv(r[6]),
            "notes": r[7],
            "max_candidate_items": int(r[8] or 40),
        })
    return out


def get_team_playlists(team_id):
    rows = fetch_all("""
        SELECT playlist_name, playlist_id, playlist_url
        FROM team_youtube_playlists
        WHERE team_id = %s
          AND is_active = 1
        ORDER BY id
    """, (team_id,))
    return [
        {
            "playlist_name": r[0],
            "playlist_id": r[1],
            "playlist_url": r[2],
        }
        for r in rows
    ]


def get_uploads_playlist_id(channel_id):
    url = "https://www.googleapis.com/youtube/v3/channels"
    params = {
        "key": YOUTUBE_API_KEY,
        "part": "contentDetails",
        "id": channel_id,
    }
    resp = requests.get(url, params=params, timeout=30)
    resp.raise_for_status()
    data = resp.json()

    items = data.get("items", [])
    if not items:
        return None

    return items[0]["contentDetails"]["relatedPlaylists"]["uploads"]


def get_playlist_items(playlist_id, max_results=25):
    url = "https://www.googleapis.com/youtube/v3/playlistItems"
    params = {
        "key": YOUTUBE_API_KEY,
        "part": "snippet,contentDetails",
        "playlistId": playlist_id,
        "maxResults": max_results,
    }
    resp = requests.get(url, params=params, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    return data.get("items", [])


def build_candidate_from_item(item, source_type, source_ref):
    snippet = item.get("snippet", {})
    content = item.get("contentDetails", {})

    video_id = None
    if content.get("videoId"):
        video_id = content.get("videoId")
    elif snippet.get("resourceId", {}).get("videoId"):
        video_id = snippet.get("resourceId", {}).get("videoId")

    if not video_id:
        return None

    published_raw = content.get("videoPublishedAt") or snippet.get("publishedAt")

    return {
        "video_id": video_id,
        "video_url": f"https://www.youtube.com/watch?v={video_id}",
        "title": safe_text(snippet.get("title")),
        "description": safe_text(snippet.get("description")),
        "thumbnail_url": pick_thumbnail(snippet),
        "published_at_raw": published_raw,
        "published_at_dt": parse_yt_datetime(published_raw) if published_raw else None,
        "source_type": source_type,
        "source_ref": source_ref,
    }


def dedupe_by_video_id(candidates):
    out = []
    seen = set()

    for c in candidates:
        vid = c["video_id"]
        if vid in seen:
            continue
        seen.add(vid)
        out.append(c)

    return out


def collect_playlist_candidates(team_cfg):
    playlists = get_team_playlists(team_cfg["team_id"])
    all_candidates = []

    for pl in playlists:
        try:
            items = get_playlist_items(pl["playlist_id"], max_results=team_cfg["max_candidate_items"])
        except Exception as e:
            print(f"  playlist fetch error team={team_cfg['team_name']} playlist={pl['playlist_id']}: {e}")
            continue

        for item in items:
            candidate = build_candidate_from_item(item, "playlist", pl["playlist_id"])
            if candidate:
                all_candidates.append(candidate)

    return dedupe_by_video_id(all_candidates)


def collect_channel_rule_candidates(team_cfg):
    try:
        uploads_playlist_id = get_uploads_playlist_id(team_cfg["channel_id"])
    except Exception as e:
        print(f"  uploads playlist lookup error team={team_cfg['team_name']}: {e}")
        return []

    if not uploads_playlist_id:
        return []

    try:
        items = get_playlist_items(uploads_playlist_id, max_results=team_cfg["max_candidate_items"])
    except Exception as e:
        print(f"  uploads fetch error team={team_cfg['team_name']}: {e}")
        return []

    all_candidates = []
    for item in items:
        candidate = build_candidate_from_item(item, "channel_uploads", uploads_playlist_id)
        if candidate:
            all_candidates.append(candidate)

    return dedupe_by_video_id(all_candidates)


def matches_include_rules(title_text, include_keywords):
    if not include_keywords:
        return True

    for kw in include_keywords:
        if kw and kw in title_text:
            return True

    return False


def matches_exclude_rules(title_text, exclude_keywords):
    if not exclude_keywords:
        return True

    for kw in exclude_keywords:
        if kw and kw in title_text:
            return False

    return True


def passes_filters(candidate, team_cfg):
    title_l = normalize_text(candidate["title"])

    include_keywords = team_cfg["include_title_keywords"]
    exclude_keywords = team_cfg["exclude_title_keywords"]

    if not matches_include_rules(title_l, include_keywords):
        return False

    if not matches_exclude_rules(title_l, exclude_keywords):
        return False

    return True


def sort_candidates_latest(candidates):
    return sorted(
        candidates,
        key=lambda x: x["published_at_dt"] or datetime.min,
        reverse=True,
    )


def save_top3(team_id, candidates):
    execute("DELETE FROM team_highlights_cache WHERE team_id = %s", (team_id,))

    for idx, c in enumerate(candidates[:3], start=1):
        execute("""
            INSERT INTO team_highlights_cache (
                team_id,
                video_id,
                video_url,
                title,
                thumbnail_url,
                published_at,
                source_type,
                source_ref,
                rank_order,
                created_at,
                updated_at
            ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW(),NOW())
            ON DUPLICATE KEY UPDATE
                video_url = VALUES(video_url),
                title = VALUES(title),
                thumbnail_url = VALUES(thumbnail_url),
                published_at = VALUES(published_at),
                source_type = VALUES(source_type),
                source_ref = VALUES(source_ref),
                rank_order = VALUES(rank_order),
                updated_at = NOW()
        """, (
            team_id,
            c["video_id"],
            c["video_url"],
            c["title"],
            c["thumbnail_url"],
            yt_datetime_to_mysql(c["published_at_raw"]),
            c["source_type"],
            c["source_ref"],
            idx,
        ))


def refresh_highlights(team_ids=None):
    if not YOUTUBE_API_KEY:
        raise RuntimeError("YOUTUBE_API_KEY is missing")

    team_sources = get_team_sources(team_ids)

    for team_cfg in team_sources:
        print(f"Processing {team_cfg['team_name']}")

        if team_cfg["source_mode"] == "playlists":
            candidates = collect_playlist_candidates(team_cfg)
        elif team_cfg["source_mode"] == "channel_rules":
            candidates = collect_channel_rule_candidates(team_cfg)
        else:
            print(f"  unsupported source_mode: {team_cfg['source_mode']}")
            continue

        if not candidates:
            print("  no candidates collected")
            execute("DELETE FROM team_highlights_cache WHERE team_id = %s", (team_cfg["team_id"],))
            continue

        filtered = [c for c in candidates if passes_filters(c, team_cfg)]
        filtered = sort_candidates_latest(filtered)

        print(f"  candidates collected: {len(candidates)}")
        print(f"  candidates after filtering: {len(filtered)}")

        if not filtered:
            for c in candidates[:10]:
                print(f"    candidate: {c['title']} ({c['published_at_raw']})")
            execute("DELETE FROM team_highlights_cache WHERE team_id = %s", (team_cfg["team_id"],))
            continue

        top3 = filtered[:3]
        save_top3(team_cfg["team_id"], top3)

        for idx, c in enumerate(top3, start=1):
            print(f"  saved rank {idx} -> {c['title']} ({c['published_at_raw']}, {c['source_type']})")

        print("Done")