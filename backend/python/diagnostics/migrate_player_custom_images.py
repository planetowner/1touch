"""--apply를 직접 실행한 경우에만 선수 사진 보존 컬럼을 추가해요."""
import argparse
from pathlib import Path

from one_touch_loader.core.db import fetch_all


def verify_schema(*, before):
    columns = fetch_all("""SELECT column_type,is_nullable,column_default FROM information_schema.columns
        WHERE table_schema=DATABASE() AND table_name='players' AND column_name='image_is_custom'""")
    if not columns and before:
        print("Pending: players.image_is_custom (existing image URLs will be preserved)")
        return False
    if columns != [("tinyint(1)", "NO", "0")]:
        raise ValueError("Unexpected players.image_is_custom schema")
    print("Player custom-image schema ready")
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if verify_schema(before=True) or not args.apply:
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(name="player_custom_images", tables=("players",),
                  sql_paths=(Path(__file__).resolve().parents[1]
                             / "one_touch_loader/sql/migrate_player_custom_images.sql",),
                  verify_schema=verify_schema)


if __name__ == "__main__":
    main()
