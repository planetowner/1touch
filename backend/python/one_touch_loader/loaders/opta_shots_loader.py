"""Opta 공개 경기 화면의 슈팅 또는 패스·수비 행동을 단건·시즌 단위로 수집해요."""

from __future__ import annotations

import argparse
import json
from contextlib import contextmanager, ExitStack
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlencode

from ..core.opta_chalkboard import EXTRACT_DOM, FINISHED_SELECTOR, SHOT_EVENTS, match_page_ids, normalize_chalkboard
from ..core.opta_analysis import ANALYSIS_EVENTS, normalize_analysis
from ..core.opta_schedule import COMPETITIONS, fetch_schedule
from ..core.opta_ids import plan_match_ids
from .opta_shots_store import (
    DATASETS, bind_events, load_known_ids, load_scope, refresh_recent_rosters,
    save_match, save_match_datasets,
)


@contextmanager
def open_browser():
    from selenium import webdriver
    options = webdriver.ChromeOptions()
    options.add_argument("--headless=new")
    options.add_argument("--window-size=1440,1100")
    kwargs = {}
    if Path("/usr/bin/chromium").is_file():
        # 운영 이미지의 같은 패키지 버전 브라우저·드라이버를 써서 실행 중 다운로드를 피해야 해요.
        options.binary_location = "/usr/bin/chromium"
        kwargs["service"] = webdriver.ChromeService(executable_path="/usr/bin/chromedriver")
        # Docker 작업 컨테이너의 기본 namespace·공유 메모리 제한에 맞춰 실행해요.
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
    # Capology 세션은 사용자 프로필과 수동 인증을 전제로 해요. 이 공개 화면에는 새 세션을 써요.
    with webdriver.Chrome(options=options, **kwargs) as driver:
        driver.set_page_load_timeout(60)
        yield driver


def collect_snapshot(url: str, driver=None, *, finished_only: bool = False, dataset: str = "shots") -> dict:
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support import expected_conditions as ec
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.common.exceptions import TimeoutException

    if driver is None:
        with open_browser() as session:
            return collect_snapshot(url, session, finished_only=finished_only, dataset=dataset)
    ids = match_page_ids(url)
    # 기사 페이지에서 ChromeDriver가 종료됐어요. 그 페이지의 공개 경기 iframe만 직접 열어요.
    widget_url = "https://dataviz.theanalyst.com/opta-football-match-centre/?" + urlencode(ids)
    driver.get(widget_url)
    wait = WebDriverWait(driver, 45)
    if finished_only:
        wait.until(ec.presence_of_element_located((By.CSS_SELECTOR, '#Opta_0 .Opta-TeamName')))
        if not driver.find_elements(By.CSS_SELECTOR, FINISHED_SELECTOR):
            return {"finished": False, "match_id": ids["matchId"], "source_url": widget_url,
                    "checked_at_utc": datetime.now(timezone.utc).isoformat()}
    wait.until(ec.element_to_be_clickable((By.XPATH, "//button[normalize-space(.)='Chalkboard']"))).click()
    root = ".Opta_F_CB_container"
    try:
        wait.until(ec.presence_of_element_located((By.CSS_SELECTOR, f"{root} svg.Opta-selectable-area")))
    except TimeoutException:
        # 유럽 예선은 종료·출전 명단이 있어도 Chalkboard가 비어 있어요.
        # 빈 요약의 0을 실제 유효슈팅 0개로 저장하지 않고, 공개 화면 근거를 남겨요.
        evidence = driver.execute_script("""return {
            chalkboard_html: document.querySelector('.Opta_F_CB_container')?.outerHTML,
            commentary_message: document.querySelector('.Opta-OS-No-Data-Text')?.textContent.trim(),
            passmap_message: document.querySelector('.Opta_F_AP_container')?.textContent.trim()
        };""")
        if (evidence['commentary_message'] == 'There is no data available for this fixture.'
                and evidence['passmap_message'] == 'No data found'):
            return {"finished": True, "available": False, "match_id": ids["matchId"],
                    "source_url": widget_url, "evidence": evidence,
                    "checked_at_utc": datetime.now(timezone.utc).isoformat()}
        raise
    if dataset == "analysis":
        # data-eid는 메뉴 그룹마다 중복돼요. 공개 메뉴의 정확한 이름으로 한 번에 선택해요.
        selected = driver.execute_script("""
            const wanted = new Set(arguments[0]);
            const items = [...document.querySelectorAll('.Opta_F_CB_container li[data-eid]')];
            if ([...wanted].some(name => !items.some(e => e.textContent.trim() === name))) return false;
            for (const e of items) {
                if (e.classList.contains('Opta-On') !== wanted.has(e.textContent.trim())) e.click();
            }
            return true;
        """, list(ANALYSIS_EVENTS) + list(SHOT_EVENTS))
        if not selected:
            raise ValueError("공개 메뉴에서 필요한 패스·수비 행동을 찾지 못했어요.")
    # UI의 필터 변경은 DOM을 다시 그려요. 다음 렌더링 뒤 같은 추출 함수를 사용해요.
    driver.execute_async_script("const done=arguments[arguments.length-1]; requestAnimationFrame(()=>requestAnimationFrame(done));")
    snapshot = wait.until(lambda browser: browser.execute_script(f"return ({EXTRACT_DOM})();"))
    snapshot["dataset"] = dataset
    snapshot["checked_at_utc"] = datetime.now(timezone.utc).isoformat()
    return snapshot


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, default=str), encoding="utf-8")


def sync_matches(args) -> dict:
    from ..core.db import fetch_all

    check = not args.apply
    dataset = getattr(args, "dataset", "shots")
    datasets = tuple(DATASETS) if dataset == "both" else (dataset,)
    capture_dataset = "analysis" if "analysis" in datasets else "shots"
    normalizers = {"shots": normalize_chalkboard, "analysis": normalize_analysis}
    known = load_known_ids()
    targets = getattr(args, 'fixtures', None)
    # 새 DDL을 실행하기 전에도 --check로 매핑·실제 수집을 검토할 수 있어요.
    stored_by_dataset, fixture_ids_by_dataset = {}, {}
    for kind in datasets:
        metadata_table = DATASETS[kind][0]
        exists = fetch_all("""SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema=DATABASE() AND table_name=%s""", (metadata_table,))[0][0]
        if not check and not exists:
            raise ValueError(f"먼저 python -m diagnostics.migrate_opta_{kind} --apply를 실행해 주세요.")
        saved = fetch_all(f'''SELECT x.external_fixture_id,m.fixture_id FROM {metadata_table} m
            JOIN fixture_external_ids x ON x.fixture_id=m.fixture_id AND x.provider='opta' ''') if exists else []
        stored_by_dataset[kind] = {row[0] for row in saved}
        fixture_ids_by_dataset[kind] = {row[1] for row in saved}
    stored = set.intersection(*stored_by_dataset.values())
    complete_fixture_ids = set.intersection(*fixture_ids_by_dataset.values())
    report = {"dataset": dataset, "check": check, "ready": 0, "stored": 0, "skipped": 0, "not_finished": 0,
              "unavailable": 0, "failed": 0, "matches": [], "scopes": []}
    retry_report = getattr(args, "retry_report", None)
    retry_ids = None
    if retry_report:
        previous = json.loads(retry_report.read_text(encoding="utf-8"))
        if previous.get("dataset", "shots") != dataset:
            raise ValueError("재시도 보고서와 이번 수집의 종류가 달라요.")
        retry_statuses = set(getattr(args, "retry_statuses", None) or ("failed", "not_finished", "unavailable"))
        retry_ids = {m["external_fixture_id"] for m in previous["matches"] if m["status"] in retry_statuses}
    attempts = 0
    report_path = args.output_dir / "report.json"
    try:
        # 저장 완료·범위 밖 경기나 확보한 원본만 재검증할 때는 브라우저를 띄우지 않아요.
        with ExitStack() as browsers:
            driver = None
            for competition_id in args.competition_ids:
                try:
                    scope = fetch_schedule(competition_id)
                    write_json(args.output_dir / f"schedule-{competition_id}.json", scope)
                    # 현재 공개 페이지의 시즌만 확인했어요. 과거 시즌을 현재 값으로 바꿔 수집하지 않아요.
                    if args.season and scope["season_name"] != args.season:
                        raise ValueError(f"공개 일정은 {scope['season_name']} 시즌이에요. 요청 시즌: {args.season}")
                    matches = []
                    for match in scope['matches']:
                        if match['date'] > args.to_date.isoformat() or (args.from_date and match['date'] < args.from_date.isoformat()):
                            continue
                        external = match['external_fixture_id']
                        if targets is not None:
                            home = known['team'].get(match['home_external_team_id'])
                            away = known['team'].get(match['away_external_team_id'])
                            if not any(str(f['starting_at'])[:10] == match['date']
                                       and (home is None or home == f['home_team_id'])
                                       and (away is None or away == f['away_team_id']) for f in targets):
                                continue
                        if retry_ids is not None and external not in retry_ids:
                            continue
                        if external in stored and not args.refresh:
                            report['skipped'] += 1
                            continue
                        matches.append(match)
                        if args.limit is not None and len(matches) >= args.limit - attempts:
                            break
                    if not matches:
                        report['scopes'].append({'competition_id': competition_id, 'season': scope['season_name'],
                                                 'scheduled': len(scope['matches'])})
                        continue
                    fixtures, lineups = load_scope(competition_id, scope["season_name"],
                                                  match_dates=sorted({m['date'] for m in matches}))
                    if targets is not None:
                        target_ids = {f['fixture_id'] for f in targets}
                        fixtures = [f for f in fixtures if f['fixture_id'] in target_ids]
                        lineups = [r for r in lineups if r['fixture_id'] in target_ids]
                    if getattr(args, "refresh_details", False):
                        lineups = refresh_recent_rosters(
                            fixtures, lineups, from_date=args.from_date, to_date=args.to_date,
                            stored_ids=set() if args.refresh else complete_fixture_ids, apply=not check,
                        )
                    report["scopes"].append({"competition_id": competition_id, "season": scope["season_name"],
                                             "scheduled": len(scope["matches"])})
                except Exception as error:
                    report["failed"] += 1
                    report["scopes"].append({"competition_id": competition_id, "error": str(error)[:800]})
                    print(f"FAIL: competition_id={competition_id} {error}", flush=True)
                    continue
                for match in matches:
                    external = match["external_fixture_id"]
                    attempts += 1
                    item = {"external_fixture_id": external, "competition_id": competition_id, "date": match["date"]}
                    try:
                        # 매핑 실패는 이미 확보한 종료 경기 원본으로 재검증해요. 시간 초과는 원본이 없어 다시 읽어요.
                        cached_path = retry_report.parent / f"{external}.raw.json" if retry_report else None
                        raw = json.loads(cached_path.read_text(encoding="utf-8")) if cached_path and cached_path.is_file() else None
                        if (raw is None or not raw.get("finished") or raw.get("available") is False
                                or raw.get("dataset", "shots") != capture_dataset):
                            if driver is None:
                                driver = browsers.enter_context(open_browser())
                            raw = collect_snapshot(match["url"], driver, finished_only=True, dataset=capture_dataset)
                        write_json(args.output_dir / f"{external}.raw.json", raw)
                        if not raw["finished"]:
                            report["not_finished"] += 1
                            item["status"] = "not_finished"
                            continue
                        if raw.get("available") is False:
                            report["unavailable"] += 1
                            item.update(status="unavailable", reason="공개 화면에서 Chalkboard가 비어 있고 데이터 없음 안내를 확인했어요.")
                            print(f"UNAVAILABLE: {external}", flush=True)
                            continue
                        # 분석 화면은 슈팅도 포함해요. 한 번 읽고 필요한 자료만 같은 저장 규칙으로 처리해요.
                        needed = [kind for kind in datasets if args.refresh or external not in stored_by_dataset[kind]]
                        results = {kind: normalizers[kind](raw) for kind in needed}
                        plan = plan_match_ids(raw, match, fixtures, lineups, known)
                        write_json(args.output_dir / f"{external}.mapping.json", plan)
                        for kind, result in results.items():
                            bind_events(result, plan, dataset=kind)
                        write_json(args.output_dir / f"{external}.json", results if dataset == "both" else results[dataset])
                        if not check:
                            if dataset == "both":
                                save_match_datasets(results, plan, known, raw["checked_at_utc"])
                            else:
                                save_match(results[dataset], plan, known, raw["checked_at_utc"], dataset=dataset)
                            report["stored"] += 1
                        for entity, mapping in plan["mappings"].items():
                            known[entity].update(mapping)
                        report["ready"] += 1
                        item.update(status="verified" if check else "stored", fixture_id=plan["fixture"]["fixture_id"])
                        for kind, result in results.items():
                            collection = "shots" if kind == "shots" else "events"
                            item[collection] = len(result[collection])
                            if dataset != "both":
                                item["counts"] = result["counts"]
                        item["datasets"] = list(results)
                        print(f"PASS: fixture_id={item['fixture_id']} datasets={','.join(results)} check={check}", flush=True)
                    except Exception as error:
                        report["failed"] += 1
                        item.update(status="failed", error=f"{type(error).__name__}: {str(error)[:800]}")
                        print(f"FAIL: {external} {item['error']}", flush=True)
                    finally:
                        report["matches"].append(item)
                        write_json(report_path, report)
                if args.limit is not None and attempts >= args.limit:
                    break
    finally:
        write_json(report_path, report)
    print(json.dumps({k: v for k, v in report.items() if k not in {"matches", "scopes"}}, ensure_ascii=False))
    print(f"보고서: {report_path.resolve()}")
    return report


def sync_main(argv: list[str]) -> None:
    parser = argparse.ArgumentParser(description="공개 일정의 종료 경기를 순회해 Opta 이벤트를 수집해요. 기본값은 읽기 전용 점검이에요.")
    parser.add_argument("--dataset", choices=(*DATASETS, "both"), default="shots", help="shots: 유효슈팅, analysis: 패스·수비 행동, both: 둘 다")
    parser.add_argument("--competition-ids", type=int, nargs="+", choices=COMPETITIONS, default=list(COMPETITIONS))
    parser.add_argument("--season", help="공개 페이지가 요청한 시즌인지 확인해요. 생략하면 현재 공개 시즌을 사용해요.")
    start = parser.add_mutually_exclusive_group()
    start.add_argument("--from-date", type=date.fromisoformat)
    start.add_argument("--recent-days", type=int, help="끝 날짜를 포함해 최근 며칠을 확인할지 정해요.")
    parser.add_argument("--to-date", type=date.fromisoformat, default=datetime.now(timezone.utc).date())
    parser.add_argument("--limit", type=int, help="이번 실행에서 확인할 최대 경기 수")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="검증한 ID와 선택한 종류의 이벤트를 DB에 저장해요.")
    mode.add_argument("--check", action="store_true", help="DB를 바꾸지 않고 실제 수집·매핑을 확인해요. 기본 동작이에요.")
    parser.add_argument("--refresh", action="store_true", help="이미 저장된 완료 경기도 다시 수집해요.")
    parser.add_argument("--refresh-details", action="store_true", help="수집 구간의 종료 경기 점수·명단을 Sportmonks로 먼저 갱신해요. --check는 조회만 해요.")
    parser.add_argument("--retry-report", type=Path, help="이전 보고서의 실패·미종료·미제공 경기만 재처리해요. 확보한 종료 원본은 다시 검증해 사용해요.")
    # 매핑 수정 때 이미 미제공을 확인한 수백 경기를 다시 기다리지 않도록 상태를 골라요.
    parser.add_argument("--retry-statuses", nargs="+", choices=("failed", "not_finished", "unavailable"),
                        help="재처리할 상태를 골라요. 생략하면 실패·미종료·미제공을 모두 확인해요.")
    folder = Path(__file__).resolve().parents[3] / "logs/diagnostics" / datetime.now(timezone.utc).strftime("opta-shots-%Y%m%dT%H%M%S%fZ")
    parser.add_argument("--output-dir", type=Path, default=folder)
    args = parser.parse_args(argv)
    if args.recent_days is not None:
        if args.recent_days < 1:
            parser.error("--recent-days는 1 이상이어야 해요.")
        args.from_date = args.to_date - timedelta(days=args.recent_days - 1)
    if args.refresh_details and args.from_date is None:
        parser.error("--refresh-details에는 --from-date 또는 --recent-days가 필요해요.")
    if args.retry_statuses and not args.retry_report:
        parser.error("--retry-statuses는 --retry-report와 함께 사용해요.")
    if args.limit is not None and args.limit <= 0:
        parser.error("--limit는 1 이상이어야 해요.")
    if args.from_date and args.from_date > args.to_date:
        parser.error("시작 날짜는 끝 날짜보다 늦을 수 없어요.")
    if args.to_date > datetime.now(timezone.utc).date():
        parser.error("미래 경기는 이벤트 수집 대상이 아니에요.")
    if sync_matches(args)["failed"]:
        raise SystemExit(1)


def main(argv: list[str] | None = None) -> None:
    import sys

    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] == "sync":
        sync_main(argv[1:])
        return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", choices=DATASETS, default="shots")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--url", help="Opta Analyst 경기 페이지 주소")
    source.add_argument("--snapshot", type=Path, help="이미 수집한 원본 JSON으로 다시 검증")
    parser.add_argument("--output", type=Path, required=True, help="정규화한 로컬 JSON 경로")
    args = parser.parse_args(argv)
    raw = (json.loads(args.snapshot.read_text(encoding="utf-8"))
           if args.snapshot else collect_snapshot(args.url, dataset=args.dataset))
    raw_path = args.output.with_name(args.output.stem + ".raw.json")
    write_json(raw_path, raw)
    if raw.get("available") is False:
        write_json(args.output, raw)
        print("공개 화면에 Chalkboard 데이터가 없어요. 유효슈팅 0개로 저장하지 않았어요.")
        return
    normalize = normalize_chalkboard if args.dataset == "shots" else normalize_analysis
    result = normalize(raw)
    write_json(args.output, result)
    print(f"PASS: {args.dataset}, 홈 {result['counts']['home']} / 원정 {result['counts']['away']}")
    print(f"원본: {raw_path.resolve()}")
    print(f"결과: {args.output.resolve()}")
    print("로컬 수집 시험만 실행했어요. DB·운영 API·Understat 데이터는 바꾸지 않았어요.")


if __name__ == "__main__":
    main()
