# 선수 순위 변동 이력

> 아래 적용 전 수치와 미반영 표시는 최초 구현 당시의 기록이에요. 2026-09-22 후속 요청으로 운영 반영을 진행하며, 현재 상태는 해당 배포 결과 보고서를 기준으로 확인해 주세요.

## 이번 범위

현재 시즌 선수 목록의 일별 순위 이력과 상승·하락 계산을 구현했어요.
HTTP API 응답에 새 필드를 추가하거나 프런트엔드를 수정하지 않았어요. API 정리는 이후 한 번에 진행해요.
운영 DB 반영·배포·커밋·푸시는 별도예요. 새 크론잡이나 타이머는 만들지 않아요.

## 비교 규칙

- 현재 순위를 **전날 마지막 순위**와 비교해요. 날짜 경계는 기존 일별 확률 이력과 같은 UTC예요.
- 하루 안에서 여러 번 갱신해도 어제 비교 기준은 그대로예요. 오늘 기록만 마지막 상태로 교체해요.
- 전체, 리그, 포지션, 리그+포지션마다 같은 조건의 목록끼리 비교해요. 페이지를 자르기 전에 순위를 계산해요.
- 기존 평점 합계/경기 수의 정확한 평균으로 정렬해요. 표시 점수의 반올림으로 순위를 정하지 않아요.
- 공동 순위는 기존처럼 1·1·3이에요. 전체 목록에서 여러 리그를 거친 선수는 합계와 경기 수를 합쳐 한 명으로 계산해요.
- 포지션은 현재 시즌 모든 대회의 실제 출전 기록으로 정해요. 이전 기록에는 그날의 포지션을 보관해요.
- 12위에서 9위가 되면 `rank_delta=3`, 상승이에요. 9위에서 12위가 되면 `-3`, 하락이에요.
- 이전 기록 자체가 없으면 `unavailable`, 기록은 있지만 같은 조건의 목록에 선수가 없으면 `new`예요. 두 경우 모두 이전 순위와 변동 수치는 `null`이에요.
- 순위 갱신이 없는 휴식일에는 마지막 저장 상태가 이어져요. 응답에 실제 기록 날짜와 시각도 담아, 어제 새로 수집한 것처럼 표시하지 않아요.
- 시즌이 바뀌면 이전 시즌과 비교하지 않아요. 최초 적용 때 오늘부터 기록하며, 현재 데이터로 과거 순위를 만들어 넣지 않아요.

프런트 안내 문구: **“순위 변동은 전날 마지막 순위와 비교합니다. 날짜는 UTC 기준이며, 처음 집계되거나 새로 진입한 선수는 변동 수치가 표시되지 않습니다.”**

## 저장과 갱신

`player_ranking_snapshots`에 시즌·날짜별 마지막 기록 시각과 입력 해시를 저장해요.
`player_ranking_snapshot_rows`에 당시 선수별 리그·시즌·평점 합계·경기 수·포지션을 저장해요.
공통 순위 함수로 모든 필터의 이전 순위를 재현하므로 필터별 순위를 중복 저장하지 않아요.
백분위와 표시 점수의 기존 저장·변환 규칙은 바꾸지 않았어요.

전체 평점 재적재, 시즌 평점 갱신, 실제 경기 상세/실시간 결과 저장 경로에서 이력을 함께 기록해요.
컵 경기의 출전 결과도 대표 포지션을 바꿀 수 있어, 현재 시즌 컵 결과 갱신 때도 기록해요.
기존 평점 공통 잠금 아래 같은 트랜잭션으로 처리해요. 이력 저장에 실패하면 해당 경기·평점 변경도 함께 롤백돼요.
같은 날 입력이 같으면 선수 행은 다시 쓰지 않고 마지막 확인 시각만 갱신해요.

따라서 **새 적재 코드를 실행하기 전에 테이블을 생성해야 해요.**

## 수동 적용 순서

아래는 프로젝트의 DB 설정을 확인한 Windows PowerShell에서 사용자가 직접 실행할 명령이에요.
적재 작업을 멈춘 상태에서 스키마 생성 → 새 코드 준비 → 최초 기록 → 적재 재개 순서로 적용해요.

먼저 읽기 전용으로 대상 스키마와 기록할 선수 수를 확인해요.

```powershell
Set-Location C:\dev\1touch\backend\python
python -B -X utf8 -m diagnostics.migrate_player_ranking_history
if ($LASTEXITCODE -ne 0) { throw '순위 이력 스키마 확인에 실패했어요.' }
python -B -X utf8 -m one_touch_loader.loaders.player_ranking_history_loader capture --check
if ($LASTEXITCODE -ne 0) { throw '순위 이력 사전 계산에 실패했어요.' }
```

테이블 생성과 최초 기록은 다음 명령이에요. 마이그레이션은 공통 실행기로 시즌 목록과 기존 이력 테이블을 `backend/logs/database-backups/`에 백업한 후 실행해요.
MySQL의 테이블 생성은 자동 커밋되므로 두 테이블 생성 전체가 하나의 롤백 단위는 아니에요.

```powershell
python -B -X utf8 -m diagnostics.migrate_player_ranking_history --apply
if ($LASTEXITCODE -ne 0) { throw '순위 이력 테이블 생성에 실패했어요.' }
python -B -X utf8 -m one_touch_loader.loaders.player_ranking_history_loader capture --apply
if ($LASTEXITCODE -ne 0) { throw '최초 순위 기록에 실패했어요.' }
python -B -X utf8 -m one_touch_loader.loaders.player_ranking_history_loader changes --limit 20
```

기존 누적 평점 마이그레이션/재적재는 필요 없어요. 기존 평점 테이블이 이미 초기화된 환경을 대상으로 해요.
최초 기록 당일의 `comparison_available=false`는 정상이에요. 다음 UTC 날짜부터 비교할 수 있어요.

## 내부 조회

```powershell
python -B -X utf8 -m one_touch_loader.loaders.player_ranking_history_loader changes --competition-id 8 --position FW --limit 20
```

현재 조회는 읽기 전용이에요. 기록 생성은 `capture --apply`일 때만 가능해요.
리그 필터는 8·82·301·384·564, 포지션은 GK·DF·MF·FW예요. 생략하면 전체예요.

나중에 API에 연결할 내부 결과는 다음과 같아요.

| 필드 | 의미 |
|---|---|
| `items[].rank` | 현재 필터의 순위 |
| `items[].previous_rank` | 이전 기록의 같은 필터 순위, 없으면 null |
| `items[].rank_delta` | 이전 순위 - 현재 순위, 비교 불가이면 null |
| `items[].movement` | up / down / unchanged / new / unavailable |
| `comparison_date` | 전날 UTC 날짜 |
| `comparison_available` | 비교할 이전 기록이 있는지 |
| `previous_snapshot_date` | 실제 사용한 기록 날짜 |
| `previous_observed_at` | 실제 기록을 확인한 마지막 시각 |

## 검증

`diagnostics.test_player_ranking_history`에서 UTC 날짜 전환, 하루 중 반복 갱신, 휴식일, 시즌 전환,
공동 순위, 이적, 신규 진입, 포지션 변경, 기록 실패 롤백, 읽기 전용 확인을 검증해요.
경기 저장 경로의 컵 포지션 갱신과 이력 실패 롤백은 `diagnostics.test_player_rating_refresh`에서 검증해요.
운영 데이터에는 쓰지 않고, 메모리 DB와 별도의 로컬 MySQL에서 확인해요.

2026-09-22 UTC 로컬 검증 결과: 관련 테스트 137개 통과.
읽기 전용으로 가져온 현재 시즌 점수 2,051행·출전 기록 23,590행을 별도 MySQL에서 검증했어요.
이적 선수를 합친 2,033명의 전체/리그/포지션 30개 조합에서 기존 API 응답과 순위가 동일했어요.
실제 MySQL 테이블 생성의 재실행, 같은 날 갱신, 외래키 오류 시 전체 롤백, 확인 모드의 무쓰기도 확인했어요.
