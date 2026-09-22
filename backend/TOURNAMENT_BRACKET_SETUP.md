# 토너먼트 대진표 백엔드

> 아래 적용 전 수치와 미반영 표시는 최초 구현 당시의 기록이에요. 2026-09-22 후속 요청으로 운영 반영을 진행하며, 현재 상태는 해당 배포 결과 보고서를 기준으로 확인해 주세요.

2026-09-22 로컬 구현·검증 기록이에요. 프런트엔드 수정, 운영 DB 변경, 배포, 커밋·푸시는 실행하지 않았어요. 새 예약 작업도 만들지 않았어요.

## 지원 범위

| 대회 | competition_id | 포함 범위 |
| --- | ---: | --- |
| 챔피언스리그 | 2 | 본선 녹아웃 플레이오프부터 결승 |
| 유로파리그 | 5 | 본선 녹아웃 플레이오프부터 결승 |
| 컨퍼런스리그 | 2286 | 본선 녹아웃 플레이오프부터 결승 |
| FA컵 | 24 | 본선 1라운드부터 결승, 예선·예선 재경기 제외 |
| EFL컵 | 27 | 예비 라운드부터 결승 |
| 코파 이탈리아 | 390 | 예비 라운드부터 결승 |
| 코파 델 레이 | 570 | 예비 라운드부터 결승 |

지원 시즌은 2024/25부터예요. 더 오래된 원정 다득점·FA컵 본선 재경기를 현재 규칙으로 계산하지 않아요.

## 미정 대진 처리 기준

2026-09-22 합의에 따라, 미정인 다음 대진 연결은 비워 두고 공급사에서 확인되면 기존 수집 과정에서 연결해요. 미래 추첨 경로를 위한 무료 API 연동이나 별도 스크레이핑은 이번 범위에서 제외해요.

- 확인되지 않은 `next_tie_id`와 `source_tie_id`는 `null`로 유지해요. 참가팀이 미정이면 `team_id`도 `null`이에요.
- 기존 갱신 과정은 시즌 전체 경기를 다시 읽어요. 종료된 대진의 진출팀이 다음 라운드 참가팀으로 확인되거나, 공급사가 명시적인 연결을 제공하면 같은 공통 로직에서 연결해요.
- 경기 날짜만 정해지고 다음 대진의 참가팀·연결 정보가 없으면 계속 비워 둬요. 날짜나 경기 ID 순서로 연결하지 않아요.
- 일부 연결이 비어 있으면 확인된 경기만 제공하고 `path_status=partial`을 유지해요. 이미 발표된 대진도 공급사에 늦게 반영될 수 있으므로 이를 모두 ‘추첨 전’으로 표시하지 않아요.

현재 국내 컵 `fixtures`는 같은 국가의 Big Five 리그 팀이 참가한 경기만 저장해요. 대진표 수집기는 Sportmonks의 해당 시즌 **전체 경기**를 읽어 `tournament_brackets`에 저장하므로 하부리그 팀끼리의 경기도 표시할 수 있어요. 기존 경기·팀 테이블의 적재 범위는 확대하지 않아요.

## 프런트엔드 전달용 API 계약

회원 Bearer 토큰으로 다음 API를 호출해요.

```http
GET /v1/competitions/2/bracket
GET /v1/competitions/2/bracket?season_id=25580
```

`season_id` 생략 시 해당 대회의 현재 시즌이에요. 다른 대회에 속한 시즌은 404, 미지원 대회·2024/25 이전 시즌은 400, 잘못된 시즌 ID는 422예요. 해당 시즌을 아직 수집하지 않았으면 503이에요. 수집했지만 본선 대진이 아직 응답에 없으면 200과 빈 `stages`를 반환해요.

전체 구조는 `/openapi.json`의 `TournamentBracketResponse`에서 확인할 수 있어요.

| 필드 | 의미와 표시 방법 |
| --- | --- |
| `competition_id`, `season_id`, `season_name` | 조회한 대회·시즌 |
| `fetched_at` | 원본 수집 시각, UTC |
| `status` | `not_published`: 수집 원본에 대상 대진 없음, `in_progress`: 진행·예정 대진 있음, `completed`: 우승팀 확정 |
| `path_status` | `complete`: 모든 대진의 다음 연결·참가 슬롯 확인, `partial`: 일부 연결·참가 슬롯·차전 정보 미확인, `not_published`: 대상 대진 없음 |
| `champion_team_id` | 우승팀, 미확정이면 `null` |
| `stages[]` | 라운드 목록. `order`로 정렬하고 `name`은 공급사 이름, `key`는 고정된 단계 식별자예요 |
| `stages[].ties[]` | 단판 경기 또는 1·2차전을 묶은 한 대진 |
| `teams` | 문자열 팀 ID를 키로 한 이름·약칭·로고. TBC의 가짜 팀 ID는 포함하지 않아요 |
| `edges[]` | `from_tie_id` 승자가 `to_tie_id`의 `to_slot`으로 진출하는 선 |
| `unlinked_tie_ids` | 결승을 제외하고 다음 대진 연결을 확인하지 못한 대진 ID |
| `issues[]` | 차전·중간 라운드 누락 등 확인된 자료 문제 |

한 대진에는 다음 값이 있어요.

- `tie_id`: 대진 식별자. 공급사의 경기 ID를 기반으로 해요.
- `format`: `single_match` 또는 `two_leg`.
- `slots[0/1]`: 각각 `home/away`. **두 경기 대진에서는 1차전의 홈·원정 기준**이에요. 대진 전체의 홈팀이라는 의미는 아니에요.
- 각 슬롯의 `team_id`는 미정이면 `null`이에요. `source_tie_id`가 있으면 그 대진의 승자가 들어와요. `label`에는 공급사의 팀명 또는 `Winner Quarter-final 1` 같은 미정 문구가 있어요.
- `fixtures[]`: 실제 경기 ID, 각 경기의 홈·원정 팀 ID, 시작 시각, 상태, 차전, 경기 점수, 승부차기 점수예요. 점수 `null`을 0으로 바꾸지 않아요. `starting_at`이 없으면 시간 미정이에요.
- `fixtures[].detail_available`: 현재 일반 경기 테이블에도 해당 경기가 있는지 표시해요. `false`일 때 경기 상세 화면 링크를 열지 않으면 돼요. 대진표 갱신 이후 일반 경기 적재가 추가돼도 조회 시 다시 확인해요.
- `fixtures[].leg`: 대진표에서 확인한 차전. `source_leg`는 공급사 원문이라 검증된 오류 보정 여부를 구분할 수 있어요.
- `aggregate_score`: 두 경기 합산 득점, `slots` 순서예요. 연장 득점을 포함하고 승부차기 득점은 제외해요. 단판 또는 점수 누락이면 `null`이에요.
- `winner_team_id`: 다음 라운드 **진출팀**이에요. 개별 경기 베팅의 승자와 다를 수 있어요.
- `winner_basis`: 경기 결과, 합산 득점, 승부차기, 공급사 aggregate, 다음 라운드 참가로 확인했는지 표시해요.
- `next_tie_id`: 이 대진 승자가 진출하는 다음 대진. 결승 또는 미확인일 때 `null`이에요.

`edges[].source=results`는 종료 결과·다음 라운드 참가팀을 대조해 복원한 연결, `provider_bracket`은 공급사가 직접 제공한 연결이에요. `ties` 배열의 나열 순서로 연결선을 추정하지 말고 `edges`를 사용해 주세요.

화면 안내 문구:

> 대진표의 진출팀은 단판 경기 결과 또는 1·2차전 합산 결과로 결정됩니다. 합산 동률이면 연장전·승부차기 결과를 반영합니다. 베팅은 선택한 개별 경기의 결과를 기준으로 하므로 대진표의 진출팀과 다를 수 있습니다.

일부 연결이 확인되지 않았을 때:

> 다음 대진 정보가 확인되면 연결됩니다.

`partial`을 일괄적으로 ‘아직 추첨 전’이라고 표시하지 말아 주세요. 이미 발표됐어도 공급사의 연결 정보가 비어 있는 경우가 있어요.

## 복원 규칙과 확인된 원본 오류

모든 대회는 `core/tournament_bracket.py`의 공통 로직을 사용하고, 단계 이름·순서만 대회별 설정으로 전달해요.

1. 공급사 aggregate가 있으면 해당 대진을 묶어요. 없으면 **같은 단계, 동일한 두 참가자, 반대 홈·원정, 고유한 1·2차전**이 모두 확인될 때만 묶어요. 익명의 TBC끼리는 임의로 묶지 않아요.
2. 종료된 대진의 진출팀을 다음 단계의 실제 참가팀과 대조해 연결해요. 점수가 누락돼도 완료 상태이고 두 팀 중 정확히 한 팀만 다음 단계에 고유하게 나타나면 진출팀을 복원할 수 있어요. 이때 점수는 만들어 넣지 않아요.
3. 단판은 연장 포함 경기 점수, 동률 시 승부차기를 사용해요. 두 경기 대진은 합산 점수, 동률 시 2차전 승부차기를 사용해요. 2차전의 개별 승자를 합산 진출팀으로 사용하지 않아요.
4. 아직 확인되지 않은 다음 대진은 비워 두고, 공급사 bracket edges가 들어오면 같은 구조로 연결해요. ID 순서·경기 날짜로 추첨 경로를 만들지 않아요.

실제 자료에서 아래 항목을 확인했어요.

- 2025/26 코파 델 레이 준결승 4경기는 aggregate ID가 없지만 1·2차전과 참가팀으로 정확히 묶였어요.
- 2025/26 코파 델 레이 예비 라운드 20경기는 공급사가 전부 `1/1`로 줬어요. [RFEF 공식 일정](https://rfef.es/es/noticias/el-sueno-para-los-20-equipos-de-la-previa-ya-tiene-horarios)에서 9/27 1차전·10/4 2차전을 확인해 해당 경기만 보정해요.
- 코파 이탈리아 경기 `19431119`의 공급사 점수는 Cerignola 0–1 Avellino였지만 [Lega Serie A 공식 기록](https://www.legaseriea.it/coppa-italia/news/questa-sera-si-chiudono-i-trentaduesimi)은 Cerignola 1–0 Avellino예요. 공유 점수 파서에서 확인된 반전 값만 보정하므로 일반 경기 수집과 대진표가 같은 값을 사용해요. 운영의 기존 점수 행을 직접 변경하지 않았어요.
- 2026/27 코파 이탈리아의 공급사 단계 순서는 Final=1, 16강=2로 오기재돼 있어 검증한 라운드 순서를 사용해요.

## 우승확률 연결과 현재 제한

기존 `probability_refresh` 실행 경로가 ClubElo Ranking을 한 번 읽고, 전체 대진을 수집한 뒤 유럽대항전 계산에 같은 대진을 전달해요. **새 크론잡·타이머를 만들지 않아요.** 대진표 단독 수집에는 Elo나 확률 모델이 필요하지 않아요.

리그페이즈·추첨 전은 기존 UEFA 동률 기준과 Annex B 계산을 유지해요. 결승까지 연결된 대진이 확인되면 실제 경로·종료 결과를 고정해 남은 경기만 계산해요. 1차전이 끝났으면 그 점수를 유지하고 2차전과 필요한 연장·승부차기만 계산해요. 대진·결과가 바뀌면 이전 대진 지문의 우승확률을 API에서 숨겨요.

**미래의 공식 추첨 경로를 별도로 자동 수집하는 작업은 이번 범위에서 제외해요.** 7개 대회 × 2025/26·2026/27, 총 14개 시즌의 [Sportmonks Brackets 응답](https://docs.sportmonks.com/v3/endpoints-and-entities/endpoints/seasons/get-brackets-by-season-id)은 모두 `stages=[]`, `edges=[]`였어요. 과거 대진은 경기로 복원했지만, 현재 코파 이탈리아처럼 일부 미래 경로가 응답에 없는 대회는 `partial`이에요. 합의한 기준에 따라 이 연결은 비워 두고, 이후 공급사 응답에서 확인되면 연결해요.

녹아웃 경기는 생겼는데 경로가 불완전하면 우승확률 갱신은 계속 `verified_knockout_path_required`를 반환해요. 대진표 자체는 확인된 부분을 조회할 수 있어요. 따라서 **현재 구현을 미래 추첨부터 시즌 종료까지 완전 자동 지원한다고 해석하면 안 돼요.** 과거 결과로 복원한 대진을 과거 경기 전 확률 검증에 사용하지 않아요.

## 수동 적용 명령

아래 명령은 **실행하지 않았어요.** 요청한 작업 규칙에 따라 운영 데이터 저장은 사용자가 직접 실행해야 해요. Windows에서 기존 백엔드 DB·Sportmonks 환경 설정을 사용하고, 변경한 API·예약 실행 코드를 배포하기 **전에** 테이블을 생성해 주세요.

```powershell
Set-Location C:\dev\1touch\backend
$env:PYTHONPATH = (Join-Path (Get-Location) 'python')
python -m diagnostics.migrate_tournament_brackets
python -m diagnostics.migrate_tournament_brackets --apply
python -m one_touch_loader.loaders.tournament_bracket_loader --check
python -m one_touch_loader.loaders.tournament_bracket_loader --apply
```

마이그레이션은 기존 공통 도구로 `seasons`와 기존 대진표 테이블을 백업한 후 생성·검증해요. 현재 공통 백업 도구는 Windows MySQL 설치 경로를 사용해요. 위 명령을 Linux 컨테이너용 명령으로 그대로 해석하면 안 돼요.

지난 2025/26 시즌 7개 대진표도 저장하려면 다음 명령을 직접 실행해 주세요.

```powershell
python -m one_touch_loader.loaders.tournament_bracket_loader --season-id 25580 --season-id 25582 --season-id 25581 --season-id 25919 --season-id 25654 --season-id 25642 --season-id 26557 --apply
```

유럽 확률 모델 설치는 `EUROPEAN_PROBABILITY_SETUP.md`의 기존 순서를 따라요. 준비된 모델의 이후 공통 갱신 명령은 아래와 같아요.

```powershell
python -m one_touch_loader.loaders.probability_refresh --apply
```

## 실제 자료 검증

2025/26 7개 대회의 총 **451개 대진, 444개 다음 라운드 연결**이 모두 복원됐어요. 결승 7개는 다음 연결이 없어요.

| 대회 | 대진 | 연결 | 경로 |
| --- | ---: | ---: | --- |
| UCL | 23 | 22 | 전체 복원 |
| UEL | 23 | 22 | 전체 복원 |
| UECL | 23 | 22 | 전체 복원 |
| FA컵 | 123 | 122 | 전체 복원 |
| EFL컵 | 91 | 90 | 전체 복원 |
| 코파 이탈리아 | 43 | 42 | 전체 복원 |
| 코파 델 레이 | 125 | 124 | 전체 복원 |

2026/27은 UEFA 3개 대회와 FA컵 본선 대진이 아직 공급사 응답에 없고, EFL컵·코파 이탈리아·코파 델 레이는 확인된 경기·연결을 부분 반환해요.

검증 입력과 전체 대진 결과는 `.codex_tmp/brackets-20260922/full-fixtures.json`, `normalized-preview.json`에 있어요. 외부 인증 정보는 포함하지 않아요. 대표적인 실제 응답 35경기는 `python/diagnostics/fixtures/tournament_bracket_cases.json`에 회귀 테스트용으로 최소 필드만 보존했어요.

API는 격리된 로컬 DB로 인증, 현재·과거 시즌, 잘못된 대회·시즌, 미수집과 미발표 구분, 상세 경기 링크, OpenAPI 스키마를 검사해요. 운영 API·DB 적용 성공을 뜻하지 않아요.

이번 검증에서는 대진표·API·유럽 확률·ClubElo·컵 베팅·기존 경기 수집 테스트 **150개가 모두 통과**했어요. 별도의 로컬 MySQL에서 새 DDL 재실행, 스키마·외래 키, 14개 시즌 저장·갱신, 잘못된 시즌 저장 시 전체 롤백, API 조회, 대진 지문에 따른 확률 노출 SQL도 통과했어요. 로그는 `.codex_tmp/brackets-20260922/tests.log`, `mysql-tests.log`에 있어요.
