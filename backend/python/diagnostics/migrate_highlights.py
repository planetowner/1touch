"""이전 캐시 구조의 최초 설치용이에요. 현재 점검은 migrate_recent_relations --verify를 써요."""
from pathlib import Path
import argparse
from one_touch_loader.core.db import fetch_all

ADDED = [("match_key", "varchar(100)"), ("match_data", "json"), ("video_data", "json")]


def verify_schema(*, before):
    columns = fetch_all("""SELECT column_name,column_type FROM information_schema.columns
        WHERE table_schema=DATABASE() AND table_name='team_highlights_cache' ORDER BY ordinal_position""")
    if not columns or columns[:3] != [("id", "bigint"), ("team_id", "bigint"), ("video_id", "varchar(50)")]:
        raise ValueError("Unexpected highlights cache schema")
    present = [(name, kind) for name, kind in columns if name in {c[0] for c in ADDED}]
    if present != ADDED and (not before or present):
        raise ValueError("Unexpected or partially migrated highlights columns")
    print(f"Highlights schema: migrated={present == ADDED}")
    return present == ADDED


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if verify_schema(before=True) or not args.apply:
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(name="highlights", tables=("team_youtube_sources", "team_youtube_playlists", "team_highlights_cache"),
                  sql_paths=(Path(__file__).resolve().parents[1] / "one_touch_loader/sql/youtube_highlights/004_verified_match_cache.sql",),
                  verify_schema=verify_schema)


if __name__ == "__main__":
    main()
