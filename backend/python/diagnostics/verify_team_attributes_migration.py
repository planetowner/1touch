"""Attributes 정리 전후의 스키마와 보존 값을 읽기 전용으로 대조해요."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from one_touch_loader.core.db import get_conn
from one_touch_loader.loaders.team_attribute_common import ALL_FEATURES, FEATURE_GROUPS


FEATURES = "team_attribute_features"
OLD_FEATURES = "team_attribute_training_features"
MODELS = "team_attribute_regression_models"
WEIGHTS = "team_attribute_regression_weights"
SCORES = "team_attribute_group_scores"
VIEW = "v_team_attribute_display_scores"
KEEP_COLUMNS = {
    FEATURES: ["team_id", "season_id", "points_per_match", *ALL_FEATURES, "updated_at"],
    MODELS: ["id", "model_name", "model_version", "target_name", "training_scope",
             "normalization_scope", "regression_method", "alpha", "rows_used", "r2_score",
             "notes", "is_active", "created_at"],
    WEIGHTS: ["model_id", "attribute_group", "feature_name", "coefficient", "weight"],
    SCORES: ["model_id", "team_id", "season_id", "attribute_group", "display_score_0_100", "updated_at"],
}
DROP_COLUMNS = {
    FEATURES: ["id", "competition_id", "matches_played", "points", "created_at"],
    MODELS: [],
    WEIGHTS: ["id", "positive_coefficient", "created_at"],
    SCORES: ["id", "competition_id", "raw_score", "feature_contributions_json", "created_at"],
}
PRIMARY_KEYS = {
    FEATURES: ["team_id", "season_id"], MODELS: ["id"],
    WEIGHTS: ["model_id", "attribute_group", "feature_name"],
    SCORES: ["model_id", "team_id", "season_id", "attribute_group"],
}


def compact_notes(notes: str) -> dict:
    results = json.loads(notes)["group_results"]
    return {"group_results": {
        group: {key: results[group][key] for key in ("rows_used", "intercept", "r2_score")}
        for group in FEATURE_GROUPS
    }}


def capture_snapshot(*, before: bool) -> dict:
    conn = get_conn()
    try:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor(dictionary=True) as cur:
            data = {}
            for table, columns in KEEP_COLUMNS.items():
                source = OLD_FEATURES if before and table == FEATURES else table
                cur.execute("""
                    SELECT COLUMN_NAME FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s
                """, (source,))
                actual = {row["COLUMN_NAME"] for row in cur.fetchall()}
                expected = set(columns + (DROP_COLUMNS[table] if before else []))
                if actual != expected:
                    raise AssertionError(f"Unexpected columns in {source}: {sorted(actual)}")
                cur.execute("""
                    SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE
                    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s AND CONSTRAINT_NAME='PRIMARY'
                    ORDER BY ORDINAL_POSITION
                """, (source,))
                key = [row["COLUMN_NAME"] for row in cur.fetchall()]
                if key != (["id"] if before else PRIMARY_KEYS[table]):
                    raise AssertionError(f"Unexpected primary key in {source}: {key}")
                cur.execute(f"SELECT {', '.join(columns)} FROM {source} ORDER BY {', '.join(PRIMARY_KEYS[table])}")
                rows = cur.fetchall()
                if table == MODELS:
                    for row in rows:
                        notes = compact_notes(row["notes"])
                        if not before and json.loads(row["notes"]) != notes:
                            raise AssertionError("Model notes still contain duplicate values")
                        row["notes"] = notes
                data[table] = rows

            cur.execute("SELECT COUNT(*) AS n FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s",
                        (FEATURES if before else OLD_FEATURES,))
            if cur.fetchone()["n"]:
                raise AssertionError("Both old and new feature table names exist")

            for table in (FEATURES, SCORES):
                source = OLD_FEATURES if before and table == FEATURES else table
                cur.execute(f"""
                    SELECT COUNT(*) AS n FROM {source} f
                    LEFT JOIN team_seasons ts ON ts.team_id=f.team_id AND ts.season_id=f.season_id
                    WHERE ts.team_id IS NULL
                """)
                if cur.fetchone()["n"]:
                    raise AssertionError(f"Missing team-season relationship in {source}")
                if before:
                    cur.execute(f"""
                        SELECT COUNT(*) AS n FROM {source} f JOIN seasons s ON s.season_id=f.season_id
                        WHERE f.competition_id <> s.competition_id
                    """)
                    if cur.fetchone()["n"]:
                        raise AssertionError(f"Competition mismatch in {source}")
                    cur.execute(f"""
                        SELECT COUNT(*) AS n FROM (
                            SELECT 1 FROM {source} GROUP BY {', '.join(PRIMARY_KEYS[table])}
                            HAVING COUNT(*) > 1
                        ) duplicates
                    """)
                    if cur.fetchone()["n"]:
                        raise AssertionError(f"Duplicate target keys in {source}")
                else:
                    cur.execute("""
                        SELECT COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
                        FROM information_schema.KEY_COLUMN_USAGE
                        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s AND REFERENCED_TABLE_NAME='team_seasons'
                        ORDER BY ORDINAL_POSITION
                    """, (table,))
                    links = [tuple(row.values()) for row in cur.fetchall()]
                    if links != [("team_id", "team_seasons", "team_id"), ("season_id", "team_seasons", "season_id")]:
                        raise AssertionError(f"Missing team-season FK in {table}")

            # 모델 ID 이외의 기존 일련번호는 다른 테이블에서 참조하지 않아야 제거할 수 있어요.
            cur.execute("""
                SELECT TABLE_NAME FROM information_schema.KEY_COLUMN_USAGE
                WHERE REFERENCED_TABLE_SCHEMA=DATABASE()
                  AND REFERENCED_TABLE_NAME IN (%s, %s, %s, %s)
            """, (OLD_FEATURES, FEATURES, WEIGHTS, SCORES))
            if cur.fetchall():
                raise AssertionError("An attribute child table has incoming foreign keys")
            for table in (WEIGHTS, SCORES):
                cur.execute("""
                    SELECT k.COLUMN_NAME, k.REFERENCED_TABLE_NAME, k.REFERENCED_COLUMN_NAME, r.DELETE_RULE
                    FROM information_schema.KEY_COLUMN_USAGE k
                    JOIN information_schema.REFERENTIAL_CONSTRAINTS r
                      ON r.CONSTRAINT_SCHEMA=k.CONSTRAINT_SCHEMA AND r.TABLE_NAME=k.TABLE_NAME
                     AND r.CONSTRAINT_NAME=k.CONSTRAINT_NAME
                    WHERE k.TABLE_SCHEMA=DATABASE() AND k.TABLE_NAME=%s AND k.REFERENCED_TABLE_NAME=%s
                """, (table, MODELS))
                if [tuple(row.values()) for row in cur.fetchall()] != [("model_id", MODELS, "id", "CASCADE")]:
                    raise AssertionError(f"Model FK changed in {table}")
            cur.execute(f"SELECT * FROM {VIEW} ORDER BY model_id, team_id, season_id")
            data[VIEW] = cur.fetchall()
            # Decimal과 시각은 문자열로 보존해 소수 네 자리와 갱신 시각까지 정확히 대조해요.
            return json.loads(json.dumps(data, ensure_ascii=False, default=str))
    finally:
        conn.rollback()
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--before", type=Path, help="적용 전 보존 값의 JSON 저장 경로")
    mode.add_argument("--after", type=Path, help="적용 전 저장한 JSON과 현재 DB를 대조")
    args = parser.parse_args()
    data = capture_snapshot(before=args.before is not None)
    if args.before is not None:
        # 같은 경로를 다시 써서 적용 전 증거를 덮어쓰지 않아요.
        with args.before.open("x", encoding="utf-8") as output:
            json.dump(data, output, ensure_ascii=False, indent=2)
    else:
        expected = json.loads(args.after.read_text(encoding="utf-8"))
        changed = [table for table in data if data[table] != expected[table]]
        if changed:
            raise AssertionError(f"Preserved values changed: {changed}")
    print(json.dumps({table: len(rows) for table, rows in data.items()}, indent=2))
    print("Team attributes migration verification passed.")


if __name__ == "__main__":
    main()
