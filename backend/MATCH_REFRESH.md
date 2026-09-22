# 경기 중·종료 후 갱신

2026-09-22 백엔드 배포 대상 코드 기준. 실제 적용·검증 결과는 [Mac 인수인계](MAC_HANDOFF.md)에 기록한다. 이 배포에는 frontend 변경을 포함하지 않는다.

## 실행 기준

| 작업 | 확인 시점 | 선행 작업과 완료 기준 |
| --- | --- | --- |
| 라이브 결과·출전 기록 | 기존 live-fixtures 서비스 | 한 응답의 상태·점수·명단·선수 통계를 같은 트랜잭션으로 저장 |
| 경기 중 순위 | standings 작업 종료 후 30초 | Sportmonks 라이브 순위, 시즌·전체 참가 팀 검증 후 별도 `live_standings` 저장 |
| 공식 순위 | 경기 상태·결과 변경, 평상시 1시간 | 공식 순위 원본 저장. 진행 중 경기가 없으면 이전 라이브 표도 제거 |
| Understat xG·슈팅 → xG 기대 순위 | 종료 경기 탐지 후 첫 수집, 미공개 자료는 5분 후 재확인 | 종료 상세·명단 → ID 연결 → xG·슈팅 저장 → 기대 순위 계산 |
| Opta 슈팅·패스·수비 | 종료 경기 탐지 후 첫 수집, 미공개 자료는 5분 후 재확인 | 종료 상세·명단 → 검증된 경기·선수 연결 → 한 번의 분석 화면 수집으로 슈팅과 분석 저장 |
| ClubElo → 대진표 → 리그·컵·유럽 확률 | 경기 상태·결과·일정 변경, 원본 정기 확인 15분 | 한 번 가져온 Elo를 계산에 공유. 입력이 같으면 시뮬레이션 생략. 선행 요청 실패 시 후속 계산 중단 |
| 1Touch 랭킹 | 완료 경기 상세 저장 후 점수 갱신, 화면 재조회 변경은 이번 배포에서 제외 | 전체 순위에서 더 읽은 페이지도 다시 조회해 함께 교체. 기준 평점 표본 초기화가 선행되어야 함 |
| Ones to Watch | API 요청 때 최근 실제 출전 10경기로 계산, 화면 재조회 변경은 이번 배포에서 제외 | 현재 명단과 완료 경기 평점이 먼저 최신이어야 함. 별도 계산 예약은 필요 없음 |
| Capology ID 연결 → 급여 | 사용자 주 1회 수동 | 아래 명령 사용. 자동 서비스에 포함하지 않음 |

Understat·Opta·확률 서비스는 실행이 끝난 뒤 15초 후 DB를 다시 확인한다. 15초마다 전체 시즌을 다시 수집하지 않는다. 완료된 경기와 재확인 대기는 `/app/logs/match-refresh/*.json`에 남긴다. 새 종료 경기는 다른 경기의 5분 대기에 묶이지 않는다. 원본 오류로 제외하기로 확정한 Understat 경기는 계속 제외한다.

공급자가 아직 공개하지 않은 자료를 경기 종료 시점에 만들어 낼 수는 없다. 5분은 재확인 간격이며, 적재·계산·컨테이너 시작에 걸리는 시간이 더해진다. 화면 재조회와 캐시 변경은 frontend 범위라 이번 백엔드 배포에서 제외한다. 서버 배포만으로 설치된 앱의 갱신 주기가 바뀌지는 않는다.

Squad Role은 현재 시즌 정규리그의 완료 경기 상세·출전 기록 저장 뒤 같은 트랜잭션에서 해당 두 팀을 재계산한다. 이전 Windows 체크아웃만으로 작성한 감사의 '역할 자동 연결 없음' 판단은 최신 원격·운영 코드에는 해당하지 않는다. 명단·결장만 바뀔 때의 연결은 별도 작업으로 남아 있다.

일정·새 컵 상대 발견, 완료 자료의 통계 정정 재확인, Best Eleven·팀 특성, 명단·부상·이적·계약 정기 갱신은 이번 네 서비스에 추가하지 않았다. 미공개 자료의 5분 재확인은 이미 완료 처리한 경기의 통계 정정을 계속 재수집하는 주기가 아니다.

확률은 **확정된 종료 결과**를 반영한다. 다른 경기가 진행 중이어도 계산하지만 진행 중 점수는 최종 승점·승자로 취급하지 않는다. 킥오프 때 다음 경기 시나리오는 갱신한다. ClubElo 원본의 갱신 시각은 우리 경기 종료 시각과 다를 수 있고, 새 Elo가 올라오면 다음 원본 확인에서 다시 계산한다. 검증된 토너먼트 대진이 없는 시즌은 계산 완료로 표시하지 않고 대기 사유를 남긴다.

## 50경기 묶음 조회

기존 fixture-details, 선수 경기 통계, team-stats 등의 묶음 조회에 더해, 이번에는 라이브 목록에서 빠진 경기 확인과 Opta 수집 전 종료 상세 보충도 같은 Sportmonks 다중 경기 경로를 쓴다. 101경기 선택 테스트는 `50 + 50 + 1`, 총 3회 호출을 검증한다. 이것은 API 요청 횟수 검증이며 운영 전체 소요 시간 실측은 아니다.

근거: [Sportmonks 다중 경기 조회](https://docs.sportmonks.com/v3/endpoints-and-entities/endpoints/fixtures/get-fixtures-by-multiple-ids), [라이브 순위 조회](https://docs.sportmonks.com/v3/endpoints-and-entities/endpoints/standings/get-live-standings-by-league-id).

이 API를 개별 선수 프로필이나 Understat·Opta에 적용할 수는 없다. 모든 성능 개선이 끝났다는 의미도 아니다. Understat와 Opta는 각각 필요한 상세를 확인하므로 두 작업 사이의 원격 상세 조회까지 하나로 합친 것은 아니다. 해당 비용과 실서비스 지연은 배포 후 별도로 측정해야 한다.

## 최초 준비와 수동 명령

### 배포 전 새 테이블 (이번 운영 DB에는 적용 완료)

API가 `live_standings`를 읽으므로 먼저 같은 대상 DB에 테이블이 있어야 한다. 배포 스크립트는 새 API로 바꾸기 전에 해당 컬럼을 조회하고, 테이블이 없으면 중단한다. 기존 `standings` 자료는 변경하지 않는다.

로컬에서 현재 설정된 DB에 적용하려면 PowerShell에서 실행한다.

```powershell
Set-Location C:\dev\1touch\backend\python
@'
from pathlib import Path
from one_touch_loader.core.db import transaction
with transaction() as connection:
    with connection.cursor() as cursor:
        cursor.execute(Path('one_touch_loader/sql/create_live_standings.sql').read_text(encoding='utf-8'))
        cursor.execute('SHOW COLUMNS FROM live_standings')
        print([row[0] for row in cursor.fetchall()])
'@ | python -X utf8 -
if ($LASTEXITCODE -ne 0) { throw 'live_standings 생성 또는 확인 실패' }
```

운영 서버 DB에 적용할 때는 서버 터미널에서 아래를 실행한다. 위 명령과 대상 DB가 같다면 중복 실행할 필요 없다.

```bash
cd /opt/1touch/backend/deploy/vultr
docker compose exec -T db sh -c \
  'MYSQL_PWD="$MYSQL_PASSWORD" mysql --user="$MYSQL_USER" --database="$MYSQL_DATABASE"' <<'SQL'
CREATE TABLE IF NOT EXISTS live_standings LIKE standings;
SHOW COLUMNS FROM live_standings;
SQL
```

그 뒤 검토한 코드로 기존 운영 배포를 실행한다. 변경한 배포 스크립트는 공용 실행 파일과 standings·understat 서비스를 설치하고 standings·understat·opta·probability 타이머를 활성화한다. 현재 작업 트리의 다른 변경까지 무조건 배포하라는 뜻은 아니다.

새 버전 배포 후 서버에서 라이브 결과 수집과 예약 상태를 확인한다. 종료 감지는 라이브 결과 수집이 먼저 정상 작동해야 한다.

```bash
sudo systemctl enable --now onetouch-fixture-live.timer
systemctl list-timers onetouch-fixture-live.timer onetouch-standings-sync.timer onetouch-understat-sync.timer onetouch-opta-sync.timer onetouch-probability-sync.timer --no-pager
journalctl -u onetouch-standings-sync.service -u onetouch-understat-sync.service -u onetouch-opta-sync.service -u onetouch-probability-sync.service -n 100 --no-pager
```

앱의 자동 재조회는 이번 Flutter 코드가 포함된 앱에서 동작한다. 서버 배포만으로 이미 설치된 앱의 영구 캐시가 바뀌지는 않는다.

### 26/27 Capology 주 1회 수동

로컬 Chrome에서 캡챠를 해결하면서 실행한다. 앞 단계가 실패하면 다음 단계는 실행하지 않는다.

```powershell
Set-Location C:\dev\1touch\backend\python
foreach ($task in @('capology-team-slugs', 'capology-player-ids', 'wages')) {
    python -m one_touch_loader.cli $task '2026/2027' 8 82 301 384 564
    if ($LASTEXITCODE -ne 0) { throw "$task 실패: 원인을 확인한 뒤 다시 실행하세요." }
}
```

국내 컵에서 새 상대 팀·경기가 발견되는 작업은 기존 `teams → team-seasons → fixtures` 순서로 별도 실행한다. 이번 종료 경기 감지는 DB에 없는 경기를 자동으로 발견하는 작업을 대신하지 않는다. 선수·스쿼드 정기 갱신과 역할 계산의 나머지 주기도 이번 네 서비스에 추가하지 않았다.
