"""Elo 적재·모델 학습·리그 예측의 명령을 제공해요. DB 저장은 --apply로 실행해요."""

from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path

from ..core.clubelo import ClubEloClient, parse_history, rating_before
from ..core.fixture_states import LIVE_STATE_IDS
from ..core.identity import validate_external_id_uniqueness
from ..core.probability_forecast import forecast_day, forecast_dates
from .probability_training import build_dataset, train_and_validate


def _dump(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, allow_nan=False, default=str)


def _read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def _fetch(sql, params=()):
    from ..core.db import get_conn
    connection = get_conn()
    try:
        with connection.cursor(dictionary=True) as cursor:
            cursor.execute(sql, params)
            return cursor.fetchall()
    finally:
        connection.close()


def read_fixtures(seasons):
    marks = ",".join("%s" for _ in seasons)
    return _fetch(f"""
        SELECT s.competition_id,s.season_id,s.name AS season_name,
               f.fixture_id,f.home_team_id,f.away_team_id,f.starting_at,f.state_id,
               f.home_score,f.away_score,r.name AS round_name
        FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
        JOIN seasons s ON s.season_id=st.season_id LEFT JOIN rounds r ON r.round_id=f.round_id
        WHERE s.competition_id IN (8,82,301,384,564) AND s.name IN ({marks})
          AND st.stage_type_id=223
        ORDER BY f.starting_at,f.fixture_id
        """, tuple(seasons))


def read_teams():
    return _fetch("""
        SELECT s.competition_id,s.season_id,t.team_id,t.name,t.short_code
        FROM team_seasons ts JOIN seasons s ON s.season_id=ts.season_id
        JOIN teams t ON t.team_id=ts.team_id
        WHERE s.name='2026/2027' AND s.competition_id IN (8,82,301,384,564)
        ORDER BY s.competition_id,t.team_id
        """)


def read_histories():
    histories = defaultdict(list)
    for row in _fetch("SELECT team_id,rating_date,elo,segment_id FROM clubelo_ratings ORDER BY team_id,rating_date"):
        histories[row["team_id"]].append({"date": str(row["rating_date"]), "elo": row["elo"], "segment_id": row["segment_id"]})
    return dict(histories)


def cached_inputs(root: Path):
    audit, profiles = _read(root / "clubelo-audit.json"), _read(root / "clubelo-profiles.json")
    return {team_id: profiles[slug]["history"] for slug, team_id in audit["mapping_candidates"].items()}


def sync_elo(mapping_file: Path, *, cache_dir: Path | None, apply: bool) -> dict:
    mapping = _read(mapping_file)
    if not isinstance(mapping, dict) or not mapping or any(type(v) is not int or v <= 0 for v in mapping.values()):
        raise ValueError("Mapping must contain verified ClubElo identifiers and positive team IDs")
    validate_external_id_uniqueness("ClubElo", mapping)
    known_teams = {r["team_id"] for r in _fetch("SELECT team_id FROM teams")}
    if not set(mapping.values()) <= known_teams:
        raise ValueError("Mapping contains unknown team IDs")
    existing = {r["external_team_id"]: r["team_id"] for r in _fetch(
        "SELECT external_team_id,team_id FROM team_external_ids WHERE provider='clubelo'")}
    combined = {**existing, **mapping}
    if any(slug in existing and existing[slug] != team_id for slug, team_id in mapping.items()):
        raise ValueError("Mapping conflicts with an existing ClubElo team")
    validate_external_id_uniqueness("ClubElo", combined)
    rows = collect_elo(mapping, cache_dir=cache_dir)
    if apply:
        save_elo(mapping, rows)
    return {"teams": len(mapping), "ratings": len(rows), "applied": apply}


def collect_elo(mapping, *, cache_dir=None):
    client, rows = ClubEloClient(), []
    try:
        for i, (slug, team_id) in enumerate(sorted(mapping.items()), 1):
            if cache_dir:
                path = cache_dir / f"{slug}.html"
                html = path.read_text(encoding="utf-8")
                fetched_at = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).replace(tzinfo=None)
            else:
                html = client.get_html(slug)
                fetched_at = datetime.now(timezone.utc).replace(tzinfo=None)
            source_hash = hashlib.sha256(html.encode()).hexdigest()
            for point in parse_history(html):
                rows.append((team_id, point["date"], point["elo"], point["segment_id"],
                             f"https://clubelo.com/{slug}", source_hash, fetched_at))
            if i % 10 == 0 or i == len(mapping):
                print(f"ClubElo checked {i}/{len(mapping)} teams", flush=True)
    finally:
        client.close()
    return rows


def save_elo(mapping, rows):
    from ..core.db import transaction
    with transaction() as connection, connection.cursor() as cursor:
        for slug, team_id in mapping.items():
            cursor.execute("""INSERT INTO team_external_ids (team_id,provider,external_team_id)
                              VALUES (%s,'clubelo',%s) ON DUPLICATE KEY UPDATE external_team_id=VALUES(external_team_id)""",
                           (team_id, slug))
        cursor.executemany("""INSERT INTO clubelo_ratings
            (team_id,rating_date,elo,segment_id,source_url,source_sha256,fetched_at) VALUES (%s,%s,%s,%s,%s,%s,%s)
            ON DUPLICATE KEY UPDATE elo=VALUES(elo),segment_id=VALUES(segment_id),source_url=VALUES(source_url),
            source_sha256=VALUES(source_sha256),fetched_at=VALUES(fetched_at)""", rows)


def input_fingerprint(fixtures, team_elos):
    return hashlib.sha256(_dump({"fixtures": fixtures, "team_elos": team_elos}).encode()).hexdigest()


def prepare_run(**kwargs):
    run = forecast_day(**kwargs)
    if kwargs.get("observed_at") is None:
        run["history_kind"] = "daily_calculation" if kwargs["as_of"] == datetime.now(timezone.utc).date() else "reconstructed"
    run["input_sha256"] = input_fingerprint(kwargs["fixtures"], {key: entry["elo"] for key, entry in run["teams"].items()})
    return run


def latest_model():
    selected = _fetch("SELECT model_id FROM probability_models ORDER BY created_at DESC,model_id DESC LIMIT 1")
    if not selected:
        raise ValueError("Train and store the Probability model before refreshing")
    return json.loads(_fetch("SELECT payload FROM probability_models WHERE model_id=%s", (selected[0]["model_id"],))[0]["payload"])


def latest_run(season_id):
    selected = _fetch("""SELECT run_id FROM probability_runs WHERE season_id=%s
                         ORDER BY as_of DESC,created_at DESC,run_id DESC LIMIT 1""", (season_id,))
    if not selected:
        return None
    return json.loads(_fetch("SELECT payload FROM probability_runs WHERE run_id=%s", (selected[0]["run_id"],))[0]["payload"])


def refresh_league(*, competition_id, season_id, teams, fixtures, histories, model_report,
                   observed_at, simulations, seed, previous, stored_days):
    # 진행 중에는 별도 인플레이 모델이 없으므로 기존 예측을 유지해요. 다른 리그는 계속 확인해요.
    live = [f["fixture_id"] for f in fixtures if f["state_id"] in LIVE_STATE_IDS]
    if live:
        return [], {"season_id": season_id, "status": "live", "fixture_ids": live}
    today = observed_at.date()
    missing = [day for day in forecast_dates(fixtures, today) if day not in stored_days]
    elos = {str(t["team_id"]): rating_before(histories.get(t["team_id"], []), today + timedelta(days=1)) for t in teams}
    fingerprint = input_fingerprint(fixtures, elos)
    unchanged = previous is not None and all((
        previous["model_id"] == model_report["model_id"], previous.get("input_sha256") == fingerprint,
        previous["simulations"] == simulations, previous["seed"] == seed,
        previous["cutoff"] == "observed_state"))
    if unchanged and not missing:
        return [], {"season_id": season_id, "status": "unchanged"}
    common = dict(competition_id=competition_id, season_id=season_id, teams=teams, fixtures=fixtures,
                  histories=histories, model_report=model_report, simulations=simulations, seed=seed)
    runs = [prepare_run(**common, as_of=day, include_what_if=False) for day in missing]
    # 새 날의 기준선을 저장할 때도 최신 응답에는 현재 예측과 What-if가 남도록 함께 계산해요.
    runs.append(prepare_run(**common, as_of=today, observed_at=observed_at, include_what_if=True))
    return runs, {"season_id": season_id, "status": "updated", "daily_snapshots": len(missing), "current_snapshots": 1}


def refresh(*, apply, simulations=100000, seed=20260917, cache_dir=None):
    report, teams = latest_model(), read_teams()
    current_ids = {t["team_id"] for t in teams}
    # 최초에 검증·저장한 팀 매칭을 재사용해요. 서버는 로컬 PC의 매핑 파일에 의존하지 않아요.
    mapping = {r["external_team_id"]: r["team_id"] for r in _fetch(
        "SELECT external_team_id,team_id FROM team_external_ids WHERE provider='clubelo'") if r["team_id"] in current_ids}
    validate_external_id_uniqueness("ClubElo", mapping)
    if set(mapping.values()) != current_ids or not current_ids:
        raise ValueError("Verified ClubElo mappings are required for every current team")
    rows = collect_elo(mapping, cache_dir=cache_dir)
    histories = {t: {p["date"]: p for p in history} for t, history in read_histories().items()}
    for t, day, elo, segment, *_ in rows:
        histories.setdefault(t, {})[str(day)] = {"date": str(day), "elo": elo, "segment_id": segment}
    histories = {t: sorted(points.values(), key=lambda p: p["date"]) for t, points in histories.items()}
    if apply:
        save_elo(mapping, rows)
    fixtures = read_fixtures(("2026/2027",))
    observed_at = datetime.now(timezone.utc)
    results = []
    for season_id, competition_id in sorted({(t["season_id"], t["competition_id"]) for t in teams}):
        # DATETIME(6)의 TIME을 문자열과 비교하면 자정도 누락돼요. 양쪽을 시간으로 비교해요.
        stored_days = {r["day"] for r in _fetch("""SELECT DISTINCT DATE(as_of) AS day FROM probability_runs
            WHERE season_id=%s AND model_id=%s AND TIME(as_of)=TIME('00:00:00')""", (season_id, report["model_id"]))}
        runs, result = refresh_league(competition_id=competition_id, season_id=season_id,
            teams=[t for t in teams if t["season_id"] == season_id],
            fixtures=[f for f in fixtures if f["season_id"] == season_id], histories=histories,
            model_report=report, observed_at=observed_at, simulations=simulations, seed=seed,
            previous=latest_run(season_id), stored_days=stored_days)
        if apply and runs:
            # 일별 기준선만 공개되고 현재 예측 저장이 실패하는 중간 상태를 남기지 않아요.
            store_runs(runs)
        results.append(result)
        print(_dump({**result, "applied": apply}), flush=True)
    return {"applied": apply, "source_teams": len(mapping), "leagues": results}


def store_model(report):
    from ..core.db import transaction
    with transaction() as connection, connection.cursor() as cursor:
        cursor.execute("INSERT INTO probability_models (model_id,payload) VALUES (%s,%s) ON DUPLICATE KEY UPDATE model_id=VALUES(model_id)",
                       (report["model_id"], _dump(report)))


def store_run(run):
    return store_runs([run])[0]


def store_runs(runs):
    from ..core.db import transaction
    identifiers = []
    with transaction() as connection, connection.cursor() as cursor:
        for run in runs:
            serialized = _dump(run)
            run_id = hashlib.sha256(serialized.encode()).hexdigest()
            cursor.execute("""INSERT INTO probability_runs (run_id,model_id,season_id,as_of,payload)
                VALUES (%s,%s,%s,%s,%s) ON DUPLICATE KEY UPDATE run_id=VALUES(run_id)""",
                (run_id, run["model_id"], run["season_id"],
                 datetime.fromisoformat(run["as_of"].replace("Z", "+00:00")).astimezone(timezone.utc).replace(tzinfo=None), serialized))
            identifiers.append(run_id)
    return identifiers


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    sync = commands.add_parser("sync-elo")
    sync.add_argument("--mapping-file", type=Path, required=True)
    sync.add_argument("--cache-dir", type=Path)
    train = commands.add_parser("train")
    train.add_argument("--audit-dir", type=Path, help="검증한 로컬 원본으로 재현할 때만 사용해요.")
    train.add_argument("--output", type=Path, required=True)
    forecast = commands.add_parser("forecast")
    forecast.add_argument("--model", type=Path, required=True)
    forecast.add_argument("--as-of", type=date.fromisoformat, required=True)
    forecast.add_argument("--from-start", action="store_true")
    forecast.add_argument("--current", action="store_true", help="일별 복원과 별도로 현재 관측 결과의 예측도 계산해요.")
    forecast.add_argument("--output", type=Path, required=True)
    forecast.add_argument("--audit-dir", type=Path)
    refresh_parser = commands.add_parser("refresh", help="공개 Elo를 확인하고 바뀐 리그와 빠진 일별 예측만 갱신해요.")
    refresh_parser.add_argument("--cache-dir", type=Path, help="검증한 원본을 다시 시험할 때만 사용해요.")
    # 10만 회면 최악의 표본 표준오차가 약 0.158%p예요. 모델 오차와는 달라요.
    forecast.add_argument("--simulations", type=int, default=100000)
    forecast.add_argument("--seed", type=int, default=20260917)
    refresh_parser.add_argument("--simulations", type=int, default=100000)
    refresh_parser.add_argument("--seed", type=int, default=20260917)
    for command in (sync, train, forecast, refresh_parser):
        mode = command.add_mutually_exclusive_group()
        mode.add_argument("--apply", action="store_true", help="검증 결과를 운영 DB에 저장해요.")
        mode.add_argument("--check", action="store_true", help="DB를 변경하지 않아요. 기본 동작이에요.")
    args = parser.parse_args(argv)
    if args.command == "refresh":
        print(_dump(refresh(apply=args.apply, simulations=args.simulations, seed=args.seed, cache_dir=args.cache_dir)))
        return
    if args.command == "sync-elo":
        print(_dump(sync_elo(args.mapping_file, cache_dir=args.cache_dir, apply=args.apply)))
        return
    if args.command == "train":
        if args.audit_dir:
            fixtures, histories = _read(args.audit_dir / "db-fixtures.json"), cached_inputs(args.audit_dir)
        else:
            fixtures, histories = read_fixtures(("2023/2024", "2024/2025", "2025/2026")), read_histories()
        report = train_and_validate(build_dataset(fixtures, histories))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(_dump(report), encoding="utf-8")
        if args.apply:
            store_model(report)
        print(_dump({"model_id": report["model_id"], "training_fixtures": report["forecast_model"]["training_fixtures"],
                     "excluded": len(report["excluded"]), "validation": report["validation"]["metrics"], "applied": args.apply}))
        return
    if args.as_of > datetime.now(timezone.utc).date():
        parser.error("as-of cannot be in the future")
    if args.current and (args.as_of != datetime.now(timezone.utc).date() or args.audit_dir):
        parser.error("--current requires today's date and current database inputs, not audit files")
    report = _read(args.model)
    if args.audit_dir:
        context, histories = _read(args.audit_dir / "db-current-context.json"), cached_inputs(args.audit_dir)
        fixtures, teams = context["fixtures"], context["teams"]
    else:
        fixtures, teams, histories = read_fixtures(("2026/2027",)), read_teams(), read_histories()
    observed_at = datetime.now(timezone.utc) if args.current else None
    args.output.mkdir(parents=True, exist_ok=True)
    total = 0
    for season_id, competition_id in sorted({(t["season_id"], t["competition_id"]) for t in teams}):
        league_fixtures = [f for f in fixtures if f["season_id"] == season_id]
        days = forecast_dates(league_fixtures, args.as_of) if args.from_start else [args.as_of]
        cutoffs = [(day, None) for day in days]
        if observed_at:
            cutoffs.append((args.as_of, observed_at))
        for day, observed in cutoffs:
            run = prepare_run(competition_id=competition_id, season_id=season_id,
                               teams=[t for t in teams if t["season_id"] == season_id], fixtures=league_fixtures,
                               histories=histories, model_report=report, as_of=day,
                               simulations=args.simulations, seed=args.seed,
                               include_what_if=observed is not None or (not args.current and day == args.as_of),
                               observed_at=observed)
            suffix = "-current" if observed else ""
            (args.output / f"{season_id}-{day}{suffix}.json").write_text(_dump(run), encoding="utf-8")
            if args.apply:
                store_run(run)
            total += 1
            print(f"Probability checked season={season_id} date={day} teams={len(run['teams'])} applied={args.apply}", flush=True)
    print(_dump({"snapshots": total, "applied": args.apply}))


if __name__ == "__main__":
    main()
