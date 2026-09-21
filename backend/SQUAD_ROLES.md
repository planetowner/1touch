# 스쿼드 역할

## 확정 기준

현재 구단에서 이번 시즌에 출전할 수 있었던 정규리그 시간을 얼마나 사용했는지로 역할을 계산해요.

- `usage_rate = 실제 출전 시간 / 출전 가능 시간`이에요.
- 구단 소속 기간의 정상 종료 정규리그 경기만 사용해요. 컵·유럽 대회와 플레이오프는 포함하지 않아요.
- 경기별 Sportmonks `sidelined.sideline`에서 `injury`, `suspended`인 경기를 분모에서 빼요. `doubtful`은 확정 결장이 아니어서 빼지 않아요.
- 경기별 연결이 빠진 부상은 같은 부상 ID의 시작일부터 마지막 결장 확인일까지 함께 반영해요. 기록된 종료일이 더 이르면 그날까지만 사용해요. 징계는 경기별 기록만 사용해요.
- 실제 선발·벤치에 포함된 선수는 출전 가능했다고 판단해요. 경기 전 결장 목록과 겹친 건수는 보고서의 `lineup_absence_conflicts`에 남겨요.
- 출전 가능한 경기마다 90분을 분모에 넣어요. 실제 출전 시간이 90분을 넘거나 출전 증거가 있는데 시간이 없으면 추정·상한 보정 없이 그 선수의 역할을 미제공으로 남겨요.
- 이적 전과 이탈 이후의 경기는 제외해요. 소속 시작일을 알 수 없거나 경기 명단과 소속 기간이 충돌하면 역할을 만들지 않아요.
- 분모가 0인 선수에게 0%를 부여하지 않아요. 경기별 결장 자료나 선발 명단이 불완전한 경우도 미제공이에요.

## 네 출전량 그룹과 Prospect

직전 5개 완료 시즌의 5대 리그를 합쳐, 구단·시즌·선수별 출전 비중을 하나의 GMM으로 학습해요.
현재 시즌 기록은 학습하지 않고 현재 역할 판정에만 사용해요. 같은 선수가 구단을 옮겼으면 별도 표본이에요.
시즌 말 스쿼드에 없어도 실제 경기 명단이 있는 이적 선수는 학습 대상에 포함해요.
소속 기간과 출전 시간을 확인할 수 있는 표본만 사용하므로, 모든 등록 선수가 학습 표본에 들어가는 것은 아니에요.

- 사용량 평균이 낮은 순서로 Sporadic → Rotation → Important → Crucial이에요.
- `GaussianMixture(n_components=4, covariance_type='tied', n_init=10, max_iter=500, random_state=20260920)`를 사용해요.
- 공통 분산으로 출전 비중이 높아졌을 때 낮은 역할로 역전되는 문제를 피하고, 실제 학습한 평균·분산·혼합 비중에서 세 경계를 구해요.
- 네 그룹의 수와 이름은 제품 규칙이에요. 경계 수치를 고정하지 않으며, 실제 감독의 판단을 학습한 정답 모델로 설명하지 않아요.
- 각 그룹 확률은 GMM 안에서의 소속 확률이에요. 실제 감독이 그 역할이라고 생각할 확률은 아니에요.
- **가장 낮은 출전량 그룹이면서 계산일 기준 만 21세 이하이면 Prospect**예요. 어린 주전은 Important나 Crucial이 될 수 있어요.
- 나이 기준일은 보고서 `as_of`의 날짜예요. 시즌 도중 만 22세 생일이 지나면 다음 역할 계산부터 Prospect에서 제외해요.
- 저사용량인데 생년월일을 모르면 Sporadic/Prospect를 추정하지 않아요.
- 시즌 초에도 확인된 경기로 계산해요. 최소 경기 수를 임의로 추가하지 않았으므로 적은 경기에서는 역할 변동이 클 수 있어요.

## 저장과 조회

새 테이블 없이 기존 `team_squad_members.squad_role`을 사용해요.
기존 부상 화면용 `team_player_injuries`의 현재 목록은 변경하지 않아요.
이적 소속 기간은 `core/player_membership.py`로 옮겨 기존 Club History와 공유해요. 기존 스쿼드의 시즌 시작일 함수도 이 모듈에 있지만, 역할 판정 나이에는 계산일을 사용해요.

`GET /v1/players/{player_id}/indicators`에 nullable `squad_role`을 추가했어요.
값은 `crucial`, `important`, `rotation`, `sporadic`, `prospect` 중 하나예요.
조회 시 역할을 재계산하거나 공급자 API를 호출하지 않아요. 저장된 현재 구단의 역할을 읽어요.
응답의 `as_of`는 기존 지표 조회 기준 시각이며, 역할의 마지막 갱신 시각이 아니에요.
역할의 실제 계산 시각과 근거는 실행 보고서의 `as_of`와 선수별 행에서 확인해요.

선수 Overview는 같은 지표 조회 요청·로딩·실패·재시도 흐름으로 역할을 표시해요.
역할에는 등급 링을 붙이지 않아요. 저장값이 없으면 샘플 역할을 대신 표시하지 않고 `—`로 남겨요.
현재 시즌 정규리그의 종료 결과·출전 시간·교체 기록이 바뀌면 해당 두 팀의 역할을 자동으로 갱신해요.
`fixture_details_loader.replace_fixture_detail_rows`와 `live_fixtures_loader.store_live_fixture`가 같은 `refresh_squad_roles_after_fixture`를 호출해요.
종료 취소도 다시 계산하며, 진행 중 경기·과거 시즌·컵 경기·동일 응답 반복 수신에는 갱신하지 않아요.
경기 저장과 역할 저장을 같은 트랜잭션에 묶어요. 공급자 조회나 역할 계산이 실패하면 경기 종료 저장도 롤백해 기존 라이브 수집이 재시도할 수 있어요.
기존 `onetouch-fixture-live.timer`는 실행 종료 후 15초마다 돌아가요. 별도 예약 작업은 추가하지 않아요.
이 동작은 서버에 새 코드를 배포한 뒤 활성화돼요. Git 푸시나 초기 DB 저장만으로 실행 중인 서버 코드가 바뀌지는 않아요.

학습된 GMM은 `core/squad_role_calibration.json`에 저장해요. 매 경기 과거 5개 시즌을 재수집하지 않고, 해당 두 팀의 현재 시즌 기록과 결장만 조회해요.
생일은 매 계산일 기준으로 확인해요. 새 시즌의 학습 기준은 아래 명령으로 다시 학습·검증·배포한 뒤 사용해야 해요.

## 읽기 전용 미리보기

```powershell
Set-Location C:\dev\1touch\backend\python
python -m diagnostics.refresh_squad_roles --report ..\logs\diagnostics\squad-roles-preview.json
```

DB SELECT와 공급자 GET만 실행하며 로컬 보고서만 저장해요.
현재 시즌의 경기별 결장을 최대 50경기씩 읽고 배포된 학습 기준으로 계산해요. 운영 DB 읽기 검증에서 전체 계산은 약 18초, 바르셀로나·아틀레티코 52명 계산은 약 7초였어요.
API 키·DB 접속 정보는 기존 환경 설정으로 읽고 보고서에 저장하지 않아요.

## 초기 DB 반영 또는 전체 재계산

```powershell
Set-Location C:\dev\1touch\backend\python
python -m diagnostics.refresh_squad_roles --apply --report ..\logs\diagnostics\squad-roles-applied.json
```

최신 자료를 다시 조회·계산한 후 현재 스쿼드의 역할 컬럼만 한 트랜잭션으로 갱신해요.
검증되지 않은 역할은 NULL로 저장해 오래된 역할을 남기지 않아요. 선수 프로필·명단·부상·출전 기록은 바꾸지 않아요.
모든 계산이 성공해야 저장 단계에 들어가요. 기본 실행에는 저장 단계가 없어요.
운영 API와 앱에 새 코드를 반영하는 배포는 별도예요. DB 반영만으로 기존 앱 코드가 바뀌지 않아요.

## 다음 시즌 기준 학습

```powershell
python -m diagnostics.refresh_squad_roles --calibration-output one_touch_loader/core/squad_role_calibration.json --report ../logs/diagnostics/squad-roles-training.json
```

직전 5개 완료 시즌을 읽어 학습하고 로컬 기준 파일·보고서만 저장해요. `--apply`와 동시에 실행하지 않아요.
학습한 기준 파일을 검증·배포한 뒤 일반 갱신 명령으로 저장해야 자동 갱신과 수동 갱신이 같은 기준을 사용해요.

## 검증

- 백엔드 역할·자동 갱신·선수 지표·경기 상세·라이브·랭킹 연동·이적·공급자 회귀 테스트 169개를 통과했어요.
- 선수 지표·반응형 화면 테스트 23개와 변경한 Dart 6개 파일의 정적 분석을 통과했어요. 현재 나이·부상 기간과 경기별 누락·종료 취소·실패 롤백도 검증했어요.
- 2,596명의 최신 전체 계산은 앞선 미리보기와 역할이 모두 같았어요. 두 팀으로 범위를 줄인 52명도 전체 계산과 일치해요.
- 표준 `tool/verify.sh`는 변경 밖의 기존 12개 파일 포맷 차이로 중단돼요. `--output=none` 검사여서 해당 파일을 변경하지 않아요.
- 전체 Flutter 테스트에서 확인한 다른 기능의 실패 26건은 변경 전 원격 기준 코드에서도 재현했어요. 이번 역할 변경의 관련 테스트와 분리해 기록해요.
- 기존 선수 화면 테스트의 샘플 역할 기대값은 실제 역할 표시 컴포넌트를 확인하도록 바꿨어요. API 값이 없으면 샘플 역할을 표시하지 않는 동작을 함께 검증해요.

명령:

```powershell
python -m unittest diagnostics.test_squad_roles diagnostics.test_squad_role_refresh diagnostics.test_player_indicators diagnostics.test_fixture_details diagnostics.test_live_fixtures diagnostics.test_player_rating_refresh diagnostics.test_transfers_contracts diagnostics.test_players_audit diagnostics.test_sportmonks_client
flutter test --no-pub test/player_indicators_test.dart test/player_screen_responsive_test.dart
flutter analyze --no-pub lib/models/player_indicators.dart lib/data/players/api/api_player_indicators_response.dart lib/features/player/player_indicator_value.dart lib/screens/AllPlayersScreen_tabs/Overview.dart test/player_indicators_test.dart test/player_screen_responsive_test.dart
```

참고: [Sportmonks 경기별 결장](https://docs.sportmonks.com/v3/endpoints-and-entities/entities/fixture), [부상 기간과 복귀 상태 필드](https://www.sportmonks.com/glossary/injuries-and-suspensions/), [scikit-learn GaussianMixture](https://scikit-learn.org/stable/modules/generated/sklearn.mixture.GaussianMixture.html).

## 2026-09-20 뉴욕 시간 실제 데이터 미리보기

기준 시각은 2026-09-21 02:34:27 UTC예요. DB에는 반영하지 않았어요.

- 조회한 정상 종료 정규리그: **9,155경기**. 모든 경기별 결장 응답을 수신하고 ID 연결을 검증했어요. 공급자가 누락한 결장까지 없다고 보장하는 의미는 아니에요.
- 결장 응답: injury 36,513건, suspended 2,145건, doubtful 936건. 기간 보완까지 포함해 실제 명단과 겹친 부상·징계 1,260건은 명단을 우선했어요.
- 학습에 사용한 검증 가능한 구단·시즌·선수 표본: **7,237개**. 이적 기간이 확인되는 선수로 제한돼 표본 선택 편향이 있을 수 있어요.
- 현재 스쿼드 **2,596명** 중 **2,171명 판정**, **425명 미제공**이에요.

| 역할 | 현재 선수 수 | 학습한 출전 비중 경계 |
| --- | ---: | --- |
| Sporadic | 552 | 약 21.98% 미만 중 나이 기준 미충족 |
| Prospect | 175 | 약 21.98% 미만이면서 계산일 만 21세 이하 |
| Rotation | 338 | 약 21.98~47.51% |
| Important | 388 | 약 47.51~72.78% |
| Crucial | 718 | 약 72.78% 초과 |

위 숫자는 설명용 반올림이에요. 코드는 고정 경계 대신 학습한 GMM의 최대 소속 확률로 판정해요.
미제공 425명은 소속 이력 미확인·기존 이적 표시 보류 188명, 소속 기간과 경기 명단 불일치 등 79명, 출전 가능 경기 없음 158명이에요.
예: Harry Kane(ID 997)은 4경기·출전 가능 360분 중 295분(81.94%)으로 Crucial이에요.

시즌별로 따로 적합한 진단 결과:

| 학습 시즌 | 표본 수 | Sporadic/Rotation | Rotation/Important | Important/Crucial |
| --- | ---: | ---: | ---: | ---: |
| 2021/2022 | 986 | 21.88% | 47.59% | 73.11% |
| 2022/2023 | 1207 | 22.18% | 47.83% | 72.42% |
| 2023/2024 | 1386 | 22.55% | 48.78% | 73.25% |
| 2024/2025 | 1645 | 22.06% | 47.91% | 74.00% |
| 2025/2026 | 2013 | 21.86% | 46.84% | 72.03% |

선수별 미리보기: `C:\dev\1touch\.codex_tmp\squad-role-audit\preview.json`. 로컬 입력·공급자 응답도 같은 폴더에 보관했어요.

## 바르셀로나 정정

- 가비는 2004-08-05생으로 2026-09-20 기준 만 22세예요. 계산일 나이로 판정하므로 Prospect 대신 Sporadic이에요.
- 더 용(ID 26536)은 8/23, 8/27, 8/31, 9/6, 9/13, 9/16, 9/19 경기 모두 DB와 공급자 선발·벤치 명단에 없어요.
- 경기별 결장 연결은 마지막 3경기에만 있지만, 부상 이력 ID 805693은 2026-06-30부터 시작한 미종료 부상이에요. 팀 부상 이력 조회에서도 같은 ID와 기간을 확인했어요.
- 같은 부상의 시작일과 마지막 결장 확인일인 9/19를 반영하면 앞선 4경기도 분모에서 빠져요. 더 용은 출전 가능 0경기이므로 Sporadic이 아니라 미제공이에요. 11/30 종료일은 미래 날짜이므로 복귀 확정일로 설명하지 않아요.
- 같은 문제가 있던 바르다지도 출전 가능 0경기로 바뀌어 Prospect 대신 미제공이에요.

더 용 대조 원본: `C:\dev\1touch\.codex_tmp\squad-role-audit\de-jong-availability-audit.json`.

추천 커밋 메시지: `fix(players): 스쿼드 역할에 현재 나이와 확인된 부상 기간 반영`
