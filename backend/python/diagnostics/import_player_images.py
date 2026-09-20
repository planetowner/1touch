"""기본 실행은 사진·DB 대조만 해요. 업로드와 DB 교체는 사용자가 --apply로 실행해요."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import re

from botocore.exceptions import ClientError
from PIL import Image
import requests

from one_touch_loader.core.player_images import IMAGE_CACHE_CONTROL, image_object_key, image_url


def scan_images(folders):
    images = {}
    for folder in folders:
        folder = Path(folder).resolve(strict=True)
        if not folder.is_dir():
            raise ValueError(f"Not a folder: {folder}")
        found = 0
        for path in sorted(folder.rglob("*")):
            if path.suffix.lower() != ".png" or "__MACOSX" in path.parts or path.name.startswith("._"):
                continue
            match = re.fullmatch(r"([0-9]+(?:,[0-9]+)*)_(.+)\.png", path.name, flags=re.I)
            if not match:
                raise ValueError(f"Missing Sportmonks ID in filename: {path}")
            sportmonks_id = int(match[1].replace(",", ""))
            data = path.read_bytes()
            with Image.open(io.BytesIO(data)) as image:
                if (image.format != "PNG" or image.size != (150, 150)
                        or image.convert("RGBA").getchannel("A").getextrema()[0] == 255):
                    raise ValueError(f"Expected a transparent 150x150 PNG: {path}")
            digest = hashlib.sha256(data).hexdigest()
            previous = images.get(sportmonks_id)
            if previous and previous["sha256"] != digest:
                raise ValueError(f"Different images for Sportmonks ID {sportmonks_id}: {previous['path']} / {path}")
            images[sportmonks_id] = {"sportmonks_id": sportmonks_id, "path": str(path),
                                    "sha256": digest, "byte_size": len(data)}
            found += 1
        if not found:
            raise ValueError(f"No player PNGs found: {folder}")
        print(f"Inspected {folder.name}: {found} files", flush=True)
    return images


def build_plan(images, players, base_url):
    # 파일 이름에는 공급자의 이름 오류가 남아 있어요. 확인된 Sportmonks ID로만 연결해요.
    by_external = {}
    for player in players:
        if player["sportmonks_id"] is None:
            continue
        external_id = int(player["sportmonks_id"])
        if external_id in by_external:
            raise ValueError(f"Duplicate Sportmonks mapping: {external_id}")
        by_external[external_id] = player
    matched, unmatched = [], []
    for external_id, image in sorted(images.items()):
        player = by_external.get(external_id)
        if player is None:
            unmatched.append(image)
            continue
        matched.append({**image, "player_id": player["player_id"], "display_name": player["display_name"],
                        "previous_image_path": player["image_path"],
                        "image_path": image_url(base_url, image["sha256"])})
    unique = {item["sha256"]: item for item in matched}
    return {"summary": {"db_players": len(players), "image_ids": len(images), "matched_players": len(matched),
                        "unmatched_files": len(unmatched), "db_players_without_file": len(players) - len(matched),
                        "unique_uploads": len(unique), "upload_bytes": sum(x["byte_size"] for x in unique.values())},
            "matched": matched, "unmatched": unmatched}


def upload_image(client, bucket, item):
    data = Path(item["path"]).read_bytes()
    if hashlib.sha256(data).hexdigest() != item["sha256"]:
        raise ValueError(f"Image changed after inspection: {item['path']}")
    key = image_object_key(item["sha256"])
    try:
        stored = client.head_object(Bucket=bucket, Key=key)
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") not in {"404", "NoSuchKey", "NotFound"}:
            raise
    else:
        if (stored["ContentLength"] != len(data) or stored.get("ContentType") != "image/png"
                or stored.get("Metadata", {}).get("sha256") != item["sha256"]):
            raise ValueError(f"Stored image differs from its content key: {key}")
        return False
    client.put_object(Bucket=bucket, Key=key, Body=data, ContentType="image/png",
                      CacheControl=IMAGE_CACHE_CONTROL, Metadata={"sha256": item["sha256"]})
    return True


def verify_public_image(item):
    with requests.get(item["image_path"], timeout=30) as response:
        response.raise_for_status()
        if (response.headers.get("Content-Type", "").split(";")[0] != "image/png"
                or hashlib.sha256(response.content).hexdigest() != item["sha256"]):
            raise ValueError(f"Public image verification failed: {item['image_path']}")


def update_image_rows(connection, items, backup_path):
    """변경 직전 주소를 백업한 뒤, 사진 주소·보존 여부만 한 트랜잭션으로 바꿔요."""
    chunks = [items[start:start + 500] for start in range(0, len(items), 500)]
    previous = []
    with connection.cursor(dictionary=True) as cursor:
        for chunk in chunks:
            ids = [item["player_id"] for item in chunk]
            cursor.execute(f"""SELECT p.player_id,p.image_path,p.image_is_custom,e.external_player_id AS sportmonks_id
                FROM players p LEFT JOIN player_external_ids e ON e.player_id=p.player_id AND e.provider='sportmonks'
                WHERE p.player_id IN ({','.join(['%s'] * len(ids))}) FOR UPDATE""", tuple(ids))
            current = cursor.fetchall()
            if {row["player_id"]: row["sportmonks_id"] for row in current} != {
                    item["player_id"]: str(item["sportmonks_id"]) for item in chunk}:
                raise ValueError("Player ID mappings changed after inspection; no image URLs were updated")
            previous.extend(current)
        backup_path.write_text(json.dumps(previous, ensure_ascii=False, indent=2), encoding="utf-8")
        for chunk in chunks:
            cases = " ".join("WHEN %s THEN %s" for _ in chunk)
            ids = tuple(item["player_id"] for item in chunk)
            values = tuple(value for item in chunk for value in (item["player_id"], item["image_path"]))
            cursor.execute(f"""UPDATE players SET image_path=CASE player_id {cases} END,image_is_custom=1
                WHERE player_id IN ({','.join(['%s'] * len(ids))})""", values + ids)
            cursor.execute(f"SELECT player_id,image_path,image_is_custom FROM players WHERE player_id IN ({','.join(['%s'] * len(ids))})", ids)
            actual = {row["player_id"]: (row["image_path"], row["image_is_custom"]) for row in cursor.fetchall()}
            if actual != {item["player_id"]: (item["image_path"], 1) for item in chunk}:
                raise ValueError("Updated player-image verification failed")


def apply_plan(plan, output, *, client, bucket, transaction):
    items = plan["matched"]
    if not items:
        return
    unique = list({item["sha256"]: item for item in items}.values())
    uploaded = int(upload_image(client, bucket, unique[0]))
    # 새 API가 배포됐는지 첫 파일로 확인한 뒤 나머지를 올려요. 실패 시 DB는 그대로예요.
    verify_public_image(unique[0])
    with ThreadPoolExecutor(max_workers=8) as executor:
        for count, changed in enumerate(executor.map(lambda item: upload_image(client, bucket, item), unique[1:]), 2):
            uploaded += int(changed)
            if count % 100 == 0:
                print(f"Storage verified: {count}/{len(unique)}", flush=True)
    verify_public_image(unique[-1])
    with transaction() as connection:
        update_image_rows(connection, items, output / "before-image-paths.json")
    result = {"updated_players": len(items), "uploaded_objects": uploaded,
              "reused_objects": len(unique) - uploaded, "completed_at": datetime.now(timezone.utc).isoformat()}
    (output / "applied.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folders", nargs="+", type=Path)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    image_url(args.base_url, "0" * 64)
    images = scan_images(args.folders)
    from one_touch_loader.core.db import get_conn, transaction
    with closing(get_conn()) as connection, connection.cursor(dictionary=True) as cursor:
        connection.start_transaction(readonly=True, consistent_snapshot=True)
        cursor.execute("""SELECT p.player_id,p.display_name,p.image_path,e.external_player_id AS sportmonks_id
            FROM players p LEFT JOIN player_external_ids e ON e.player_id=p.player_id AND e.provider='sportmonks'""")
        players = cursor.fetchall()
        connection.rollback()
    plan = build_plan(images, players, args.base_url)
    from diagnostics.migrate_player_custom_images import verify_schema
    plan["schema_ready"] = verify_schema(before=True)
    output = args.output or (Path(__file__).resolve().parents[2] / "logs/player-images"
                            / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    output.mkdir(parents=True, exist_ok=False)
    (output / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({**plan["summary"], "schema_ready": plan["schema_ready"], "report": str(output)}, ensure_ascii=False), flush=True)
    if not args.apply:
        print("Preview only: no uploads or database changes")
        return
    if not plan["schema_ready"]:
        raise ValueError("Run diagnostics.migrate_player_custom_images --apply before importing")
    from one_touch_loader.api.services.auth_security import required_setting
    from one_touch_loader.api.services.media_storage import r2_client
    apply_plan(plan, output, client=r2_client(), bucket=required_setting("R2_BUCKET"), transaction=transaction)


if __name__ == "__main__":
    main()
