# 유럽대항전 우승확률과 ClubElo 갱신

> 아래 적용 전 수치와 미반영 표시는 최초 구현 당시의 기록이에요. 2026-09-22 후속 요청으로 운영 반영을 진행하며, 현재 상태는 해당 배포 결과 보고서를 기준으로 확인해 주세요.

2026-09-21 작업의 로컬 구현 안내예요. 운영 모델·데이터 저장, 배포, 커밋·푸시는 실행하지 않았어요. 새 크론잡·서비스·타이머도 만들지 않았어요.

## 구현 범위와 남은 제한

현재 **2026/27 본선 리그페이즈, 녹아웃 추첨 전**의 UCL·UEL·UECL 우승확률을 계산해요. 세 대회 각 36팀, 총 108팀의 참가 명단·전체 리그페이즈 일정·ClubElo 연결을 확인했어요. 예선 탈락 팀을 본선 참가 팀에 포함하지 않아요.

실제 종료 결과는 고정하고 남은 경기, 규정에 따른 미래 대진, 연장전·승부차기까지 반복 계산해요. 리그페이즈의 UEFA 동률 기준은 마지막 클럽 계수 기준까지 적용해요. 정규리그 Top 4·Top 6는 기존과 같이 리그 순위 확률이며, 실제 유럽대항전 진출 확률로 바꾸지 않아요.

**2026-09-22 대진표 백엔드에서 확정 경로·종료 결과를 우승확률에 연결했어요.** 과거 대진은 진출팀과 다음 라운드 참가팀을 대조해 복원해요. 연결이 완전하면 종료 경기·1차전 점수를 고정하고 남은 경기만 계산해요. 다만 공급사의 미래 추첨 경로는 여전히 비어 있어, 녹아웃 경기 데이터가 생겨도 결승까지의 경로를 확인하지 못하면 `verified_knockout_path_required`로 갱신을 보류해요. 시즌 종료까지 완전 자동 지원하는 상태는 아니에요. 적용 전 `tournament_brackets` 테이블 생성이 필요하며, API 계약·현재 제한·수동 실행 명령은 [대진표 백엔드 안내](TOURNAMENT_BRACKET_SETUP.md)를 따라 주세요.

현재 API 진입점은 기존 팀 분석 화면과 같은 Big Five 팀의 국내 리그 맥락이에요. 엔진은 유럽 본선 108팀을 모두 계산하지만, 다른 국내 리그 팀까지 팀 분석 화면을 확장하는 작업은 포함하지 않았어요.

## ClubElo 수집 경로

- 현재 전력: `https://clubelo.com/Ranking` 한 페이지를 읽어요.
- 기존 `sync-probability.sh`가 `probability_refresh`를 실행해 한 번 읽은 전력을 국내 리그 예측·컵 경기 베팅·유럽대항전 우승확률에 공유해요. 각 갱신 모듈을 단독 실행해도 같은 수집 함수를 사용해요.
- 기존 DB 매핑 126팀과 검증한 유럽 본선 참가 팀을 합쳐 196팀을 확인했어요. 이번에 새로 연결한 팀은 70팀이에요.
- 같은 실제 입력으로 컵·유럽 경기의 베팅 배당도 다시 계산했어요. 매핑 확대 후 예정 경기 373개는 계산됐고, 2개는 전력 자료가 없어 제외됐어요. 운영에 저장한 수치는 아니에요.
- 상세 페이지가 있는 팀은 기존 링크 ID를 유지해요. 링크가 없는 팀은 검증한 `ranking:국가:원본 팀명` 식별자를 사용해요. 같은 이름의 팀을 유사도나 첫 번째 검색 결과로 연결하지 않아요.
- `core/clubelo_europe_teams.json`에 팀 ID·국가·Ranking 원본 이름을 담았어요. 배포 이미지에도 포함돼 예약 실행 시 로컬 PC 파일이 필요하지 않아요.
- 표의 실제 게시 날짜에 해당 Elo를 저장해요. 현재 값을 과거 날짜로 복사하지 않아요. 명시적인 과거 이력 수집 명령 `probability sync-elo`만 기존 팀 상세 페이지를 사용해요.
- 기존 `team_external_ids`, `clubelo_ratings`, `clubelo_sources`를 사용해요. 새 테이블은 없어요.

## UEFA 순위·진출 규칙

승점이 같으면 다음 순서로 비교해요.

1. 득실차
2. 다득점
3. 원정 다득점
4. 승리 횟수
5. 원정 승리 횟수
6. 맞붙은 상대들의 최종 승점 합
7. 맞붙은 상대들의 최종 득실차 합
8. 맞붙은 상대들의 최종 득점 합
9. 낮은 징계 점수
10. 높은 UEFA 클럽 계수

선수·팀 관계자의 경고는 1점, 퇴장은 3점이에요. 경고 누적 퇴장은 첫 경고를 포함해 총 3점으로 계산해요. DB에서 누락된 감독 경고가 실제 확인돼, 완료 경기의 카드 자료는 Sportmonks 원본에서 읽고 기존 공통 이벤트 보정을 적용해요. 과거 첫 경고의 대상이 없어 경고 누적 퇴장과 연결할 수 없었던 5경기는 카드 학습 표본에서 제외했어요.

미래 경고·퇴장 점수는 과거 UEFA 경기에서 관측한 홈·원정 징계 점수 쌍을 함께 추출해 모델링해요. 아직 발생하지 않은 카드를 실제 확정 기록처럼 취급하지 않아요. 동률을 무작위 순서로 풀지 않고, 이렇게 계산한 징계 점수 이후에도 클럽 계수를 적용해요.

클럽 계수는 이번 시즌 시작에 쓰는 **2021/22~2025/26 기준**이에요. 자체 5시즌 합과 협회 계수 20% 중 높은 값을 사용하고, 같으면 최근 시즌부터의 계수, 협회 계수, 직전 국내 리그 순위까지 비교해요. `core/uefa_coefficients_2026.json`에 공식 수치·출처·검증 시점을 담았어요. 공식 전체 목록 415팀에 없는 10팀은 Annex D.4의 협회 하한을 적용했어요. 다음 시즌에는 해당 시즌 기준 참가 팀·계수 검증이 필요해요.

녹아웃은 Annex B의 순위 쌍과 경로를 사용해요. 상위 시드의 2차전 홈 권한은 해당 경로를 이긴 팀이 이어받아요. 두 경기 합산이 같으면 2차전 장소에서 연장전, 이후에도 같으면 승부차기로 진출팀을 정해요. 결승은 중립 경기장 단판이에요. 원정 다득점 규칙은 적용하지 않아요.

이 **대회 진출팀 계산**은 [개별 경기 베팅 판정](CUP_BETTING_SETUP.md)과 달라요. 2차전 A 1–0 B, 합산 동점 후 승부차기 B 승이면 해당 경기 베팅은 A 승이고, 대회 시뮬레이션에서는 B가 다음 단계로 진출해요.

## 모델과 검증

- 득점 모델: Elo 차이와 홈 이점을 입력으로 사용하는 포아송 모델. 2023/24~2025/26 완료 경기 중 경기 전 Elo를 확인한 5,357경기로 최종 학습했어요.
- 시간 분리 검증: 앞선 두 시즌 3,533경기로 학습하고 2025/26의 1,824경기로 검증했어요. 경기 점수 로그 손실은 모델 **2.9276**, 평균 득점 기준 **3.0223**으로, 낮을수록 좋아요. 우승확률 자체의 보정 성능을 검증한 수치는 아니에요.
- 승부차기: 전체 34경기, 검증 14경기. Elo 모델 손실 0.6997이 양 팀 50%의 0.6931보다 나빠, 현재는 더 단순한 50% 모델을 선택해요. 검증 결과와 선택한 방법을 저장해요.
- 미래 징계 점수 표본은 1,075경기예요. 연장전은 같은 득점 과정의 30분으로 계산해요. 미래 Elo·선발·부상·퇴장에 따른 경기력 변화는 별도로 모델링하지 않아요.
- 실제 입력으로 세 대회 각각 100,000회 계산했어요. 대회별 우승 횟수 합은 100,000, 확률 합은 100%예요. 최대 표본 표준오차는 약 0.158%p이며, 모델 자체의 오차를 포함하는 신뢰구간은 아니에요.
- 드문 팀은 10만 회 중 우승이 한 번도 없을 수 있어요. 이때 표본 확률 0은 수학적인 탈락 확정을 뜻하지 않아요. API 원본 결과에는 남기며 기존 카드 선택 규칙은 0·1 값을 제외해요.

## 저장·화면 연결

기존 `probability_models`, `probability_runs`, `probability_team_results`를 재사용해요.

- 모델: `european_title_poisson_elo_v1`
- 실행 구분: `payload.outcome_kind=european_title_v1`
- 이벤트: `ucl_winner`, `uel_winner`, `uecl_winner`
- `GET /v1/teams/{team_id}/probability`의 `events`와 `cards`에 참가 대회의 우승확률을 추가해요. 기존 대회별 카드 선택 규칙과 공통 카드 UI를 사용해요.
- `european_title`에는 해당 대회의 시즌·계산 시각·모델·검증 수치·출처·한계를 별도로 제공해요. 국내 리그 모델·일별 이력·증감과 섞지 않으며, 유럽 우승확률의 `change_pp`는 현재 `null`이에요.
- 데이터가 없거나 확정 대진이 필요한 경우 `european_title=null`이고 숫자 0으로 대체하지 않아요.
- 화면에는 실제 참가 대회 이름과 추정 확률·미래 카드·미래 추첨에 대한 안내를 표시해요.

프런트 개발자 전달용 문구:

> 참가 중인 유럽대항전에서 우승할 추정 확률이에요. ClubElo 전력과 실제 경기 결과를 바탕으로 남은 경기를 반복 계산해요. 연장전·승부차기와 UEFA 동률 기준을 반영해요. 앞으로의 경고·퇴장과 아직 정해지지 않은 대진도 확률적으로 계산하므로, 실제 결과와 다를 수 있어요. 표시 값은 반올림한 추정치예요.

## 운영 반영 명령 — 사용자가 직접 실행

수정 코드를 운영 이미지에 배포한 뒤 `/opt/1touch/backend/deploy/vultr`에서 실행해요. 아래 명령은 이번 작업에서 실행하지 않았어요. 다른 변경이 많은 현재 작업 폴더 전체를 배포하는 명령도 실행하지 않았어요.

```bash
cd /opt/1touch/backend/deploy/vultr

# 모델 학습 결과를 먼저 조회해요. DB에는 저장하지 않아요.
bash compose-production.sh run --rm --no-deps -T api python -m one_touch_loader.loaders.european_probability_loader train --check

# 컵 모델을 아직 저장하지 않았다면 최초 한 번 실행해요.
bash compose-production.sh run --rm --no-deps -T api python -m one_touch_loader.loaders.cup_betting_loader train --output /tmp/cup-betting-model.json --apply

# 유럽대항전 모델을 최초 저장해요.
bash compose-production.sh run --rm --no-deps -T api python -m one_touch_loader.loaders.european_probability_loader train --apply

# 전체 갱신을 저장 없이 확인한 뒤, 확인한 결과를 실제로 갱신해요.
bash sync-probability.sh --check
bash sync-probability.sh --apply
```

기존 국내 리그 모델이 저장돼 있다는 전제예요. 새 유럽 모델을 최초 저장하기 전에는 확장한 기존 갱신 작업이 모델 부재 오류를 반환해요. 새 예약 작업은 필요하지 않아요.

## 실행한 검사

- Python: `python -m unittest diagnostics.test_european_probability diagnostics.test_clubelo_ranking diagnostics.test_cup_betting diagnostics.test_probability diagnostics.test_probability_pipeline diagnostics.test_probability_refresh diagnostics.test_probability_storage diagnostics.test_probability_api diagnostics.test_sportmonks_client -q` — **93개 통과**.
- Flutter: `flutter test test/team_probability_section_test.dart test/api_team_probability_repository_test.dart` — **15개 통과**. 세 대회 이름, 국내 리그와 다른 대회 ID, 증감 `null`, 320×568·430×932 및 두 테마를 확인했어요.
- 변경한 Dart 파일 3개의 포맷 검사 완료. 같은 3개 경로의 `flutter analyze`는 오류·경고 없이 기존 상위 파일명 `Analysis.dart`에 대한 스타일 정보 1건을 보고했어요. 종료 코드는 1이에요.
- 표준 `./tool/verify.sh test/team_probability_section_test.dart test/api_team_probability_repository_test.dart`는 작업 범위 밖 파일들의 포맷 차이로 테스트 단계 전에 중단됐어요. 마지막 실행에서 33개였으며, 이를 고치기 위해 다른 작업의 파일을 수정하지 않았어요. 전체 앱 검증 완료를 의미하지 않아요.
- 변경한 API 조회 SQL을 운영 MySQL에서 읽기 전용 트랜잭션으로 실행해 문법·스키마를 확인했어요. 새 유럽 모델은 운영에 저장하지 않아 결과는 빈 목록이었어요. 실제 운영 확률 노출은 아직 검증할 수 없어요.
- 실제 Ranking을 공통 파서로 다시 읽어 같은 196팀·날짜·전력 값이 나오는지 확인했어요.

로그와 실제 입력의 계산 결과는 로컬 `.codex_tmp/cup-betting-20260921`의 `europe-all-tests.log`, `europe-flutter-tests.log`, `europe-flutter-analyze.log`, `europe-flutter-verify.log`, `europe-model.json`, `europe-preview.json`, `europe-sql-check.json`에 있어요.

## 출처

- [ClubElo Ranking](https://clubelo.com/Ranking)
- [UCL 2026/27 Article 18](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-18-Equality-of-points-league-phase-Online)
- [UEL 2026/27 Article 18](https://documents.uefa.com/r/Regulations-of-the-UEFA-Europa-League-2026/27/Article-18-Equality-of-points-league-phase-Online)
- [UECL 2026/27 Article 18](https://documents.uefa.com/r/Regulations-of-the-UEFA-Conference-League-2026/27/Article-18-Equality-of-points-league-phase-Online)
- [UEFA 클럽 계수와 동률 기준](https://www.uefa.com/nationalassociations/uefarankings/club/?year=2026)
- [UEFA Annex B 대진 구조](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Annex-B-UEFA-Champions-League-Competition-System-Online)
- [UEFA Article 21 합산·연장·승부차기](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-21-Knockout-system-extra-time-and-penalty-shoot-outs-Online)
- [Sportmonks Brackets API](https://docs.sportmonks.com/v3/endpoints-and-entities/endpoints/seasons/get-brackets-by-season-id)

추천 커밋 메시지: `feat(probability): ClubElo Ranking 수집과 유럽대항전 우승확률 구현`
