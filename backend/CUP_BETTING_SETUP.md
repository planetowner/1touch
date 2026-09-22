# 컵·UCL 경기 베팅 변경 안내 — 2026-09-21

> 아래 적용 전 수치와 미반영 표시는 최초 구현 당시의 기록이에요. 2026-09-22 후속 요청으로 운영 반영을 진행하며, 현재 상태는 해당 배포 결과 보고서를 기준으로 확인해 주세요.

로컬 코드 구현·검증 결과예요. 운영 DB에 모델·배당을 저장하거나 서버를 배포하지 않았고, 커밋·푸시도 하지 않았어요.

## 적용한 판정

모든 베팅은 선택한 **경기 한 경기**의 최종 결과로 판정해요.

1. 정규시간에 끝나면 종료 스코어를 사용해요.
2. 연장전이 진행되면 연장전까지 포함한 스코어를 사용해요.
3. 해당 경기 스코어가 동점이고 승부차기가 진행됐다면 승부차기 승자를 사용해요.
4. 동점으로 끝나고 승부차기가 없다면 무승부예요.
5. 1·2차전 합산 스코어와 진출팀은 결과 판정에 반영하지 않아요. 승부차기 득점도 경기 스코어에 더하지 않아요.

확정 예시: 1차전 A 0–1 B, 2차전 연장 종료 A 1–0 B, 승부차기 B 승이면 **2차전 베팅은 A 승**이에요.

FT·AET·FT_PEN 종료 상태를 처리해요. 아직 진행 중이거나 필요한 점수·승부차기 결과가 누락되면 정산을 기다려요. 기존 취소·연기 등에 대한 환불 규칙은 같아요. 이미 수락한 확률과 지급액, 중복 요청 방지, 사용자별 잠금·원장 트랜잭션을 그대로 사용해요.

## 프런트 개발자 전달용 문구

### 짧은 안내

이 경기 한 경기의 결과로 판정해요. 연장전은 포함하고, 합산 스코어와 진출 여부는 반영하지 않아요.

### 판정 기준

이 베팅은 선택한 경기 한 경기의 결과를 기준으로 해요.

- 정규시간에 끝난 경기는 종료 스코어로 판정해요.
- 연장전이 진행되면 연장전까지 포함한 종료 스코어로 판정해요.
- 해당 경기의 종료 스코어가 동점이고 승부차기가 진행됐다면, 승부차기에서 이긴 팀을 승리로 판정해요.
- 동점으로 끝나고 승부차기가 없다면 무승부로 판정해요.

1·2차전 합산 스코어와 다음 라운드 진출 여부는 반영하지 않아요. 승부차기 득점도 경기 스코어에 더하지 않아요.

예시: 2차전이 연장전까지 A 1–0 B로 끝났다면 A 승이에요. 합산 동점으로 진행한 승부차기에서 B가 이겨도, 이 베팅은 A 승으로 판정해요.

현재 Flutter의 영어 화면에도 같은 내용의 `RESULT RULES` 버튼과 안내 창을 베팅 카드·참여 화면에 넣었어요. 정산 규칙은 API의 `settlement_rule=single_match_final_v1`로 식별해요.

## 선택지와 API

`GET /v1/fixtures/{fixture_id}/betting`의 `options`는 가능한 결과만 반환해요.

| 경기 | 선택지 |
| --- | --- |
| 리그·유럽대항전 리그/조별 단계·1차전 | 홈 승 / 무 / 원정 승 |
| 단판 토너먼트 | 홈 승 / 원정 승 |
| 1차전이 동점으로 끝난 2차전 | 홈 승 / 원정 승 |
| 1차전에 승패가 난 2차전 | 홈 승 / 무 / 원정 승 |

2차전의 합산 정보는 **무승부가 가능한지** 확인할 때만 사용해요. 베팅 승자를 합산 결과로 바꾸지는 않아요. 1차전 결과·차전 정보가 확인되지 않으면 배당을 제공하지 않아요. UEFA 예선에 `leg=1/1` 오기재가 실제로 있어 이 값만으로 단판을 판단하지 않아요.

새 옵션에서 빠진 결과를 제출하면 409 `outcome_unavailable`을 반환해요. 화면은 갱신된 선택지를 표시하고 무승부가 없는 경기의 그래프도 홈·원정 색상을 유지해요.

## 저장·예측 구조

- 신규 테이블이나 스키마 변경은 없어요. 기존 `probability_models`, `probability_runs`, `fixture_bets`, 지갑·원장을 재사용해요.
- 컵 모델은 `cup_final_result_elo_v1`로 구분해요. 기존 리그 모델과 최신 모델 조회가 섞이지 않도록 조건을 추가했어요.
- `probability_runs.payload.market_kind=single_match_final_v1`이고 `fixture_markets`에 경기별 확률·전력·경기 식별 정보·무승부 가능 여부를 저장해요. 리그 순위·우승확률 API에는 이 기록을 노출하지 않아요.
- 서로 다른 리그의 팀도 각 팀의 검증된 ClubElo 기록을 사용해요. 현재 정규리그의 같은 예측 실행에 두 팀이 있어야 한다는 제약을 컵 경기에는 적용하지 않아요.
- 학습과 정산이 같은 최종 결과 함수를 사용해요. 무승부가 불가능한 경기는 학습·예측 모두 무승부 확률을 제외해요. 임의로 연장 승률·승부차기 승률을 50%로 붙이지 않아요.
- 경기 시작 전 실제로 만든 배당만 제공해요. 킥오프·대진·경기 형식이나 참조한 1차전 점수가 바뀌면 기존 배당을 새로 수락하지 않아요.
- 확정된 과거 베팅은 수락 당시 실행의 규칙과 지급액을 사용해요.
- 지원 대회 ID: UCL 2, UEL 5, UECL 2286, FA컵 24, 카라바오컵 27, 코파 이탈리아 390, 코파 델레이 570. 서비스 시즌은 기존과 같은 2026/27이에요.
- UCL·UEL·UECL 대회 전체 우승확률은 별도 공통 엔진으로 추가했어요. 범위와 제한은 [유럽대항전 우승확률 안내](EUROPEAN_PROBABILITY_SETUP.md)를 확인해 주세요. 국내 컵 대회 전체 우승확률은 아직 없어요.

## 실제 데이터 점검

운영 DB에서 읽기 전용으로 내보낸 경기·Elo로 로컬에서 재현했어요.

- 2023/24~2025/26 과거 컵·유럽대항전 526경기로 최종 모델을 학습했어요.
- 앞선 두 시즌 343경기로 학습하고, 이후 시즌 183경기로 검증했어요.
- 검증 로그 손실: 모델 0.8184, 결과 빈도 기준 0.8998. 낮을수록 좋아요.
- 현재 예측 가능한 예정 경기 72개: 세 선택지 59개, 두 선택지 13개.
- 전력 자료가 부족한 예정 경기 303개는 배당 미제공이에요. 임의 전력으로 대체하지 않아요.
- 전체 팀을 포괄하는 모델은 아니에요. 중립 경기장, 선발 명단, 합산 점수 차이를 별도 입력으로 반영하지 않는 현재 모델의 한계가 있어요. 검증 수치는 실제 서비스 적중률 보장이 아니에요.

원본·학습 결과·미리보기·검증 로그는 `C:\dev\1touch\.codex_tmp\cup-betting-20260921`에 있어요.

## 운영 반영 시 사용자가 직접 실행할 명령

아래 명령은 **수정한 백엔드 코드가 운영 이미지에 배포된 뒤**, 서버의 `/opt/1touch/backend/deploy/vultr`에서 실행해요. 운영 변경 권한 제한에 따라 이번 작업에서는 실행하지 않았어요. 현재 작업 폴더에 다른 기능의 미커밋 변경이 많으므로 이 폴더 전체를 그대로 배포하는 명령은 제공하지 않아요.

```bash
cd /opt/1touch/backend/deploy/vultr

# 읽기 전용 학습 검증
bash compose-production.sh run --rm --no-deps -T api python -m one_touch_loader.loaders.cup_betting_loader train --output /tmp/cup-betting-model.json

# 검토한 모델을 DB에 저장
bash compose-production.sh run --rm --no-deps -T api python -m one_touch_loader.loaders.cup_betting_loader train --output /tmp/cup-betting-model.json --apply

# 최신 전력과 예정 경기 배당을 DB에 저장
bash compose-production.sh run --rm --no-deps -T api python -m one_touch_loader.loaders.cup_betting_loader refresh --apply

# 정산 예정 내역 조회: 포인트를 바꾸지 않음
bash sync-betting.sh
```

기존 매시간 `sync-probability.sh`는 ClubElo Ranking을 한 번 읽고 리그·컵·유럽대항전 계산에 공유하도록 확장했어요. 유럽대항전 모델도 최초 저장해야 하므로 [최신 실행 순서](EUROPEAN_PROBABILITY_SETUP.md)를 따라 주세요. 기존 매분 정산 작업은 FT뿐 아니라 AET·FT_PEN도 처리해요.

현재 전력은 Ranking 표에서 수집해요. 추가로 확인한 유럽 본선 108팀의 매핑을 코드에 포함했어요. 아래의 72경기·303경기 점검 수치는 이 매핑 추가 전 기록이에요. 명시적인 과거 이력 수집만 기존 `probability sync-elo` 명령을 사용해요.

## 검증

- MySQL 8.0 격리 테스트 DB와 정산 규칙: `diagnostics.test_betting` 23개 통과. 동시 지출·동시 정산·원장 실패 시 롤백·컵 배당 생성→DB 저장→API 조회→베팅 접수·최종 경기 승자 우선·승부차기 지연·시작 전 마감 포함.
- 컵 모델·기존 리그 모델·예측 저장·API 회귀 테스트 59개 통과. 백엔드 관련 테스트 합계 82개예요. 실행 로그: `probability-tests.log`, `mysql-tests.log`. 공통 Elo 갱신 코드를 정리한 뒤 관련 19개 테스트도 다시 통과했어요(`refresh-tests.log`).
- Flutter 베팅 API·화면 테스트 11개 통과. 320×568와 430×932, 밝은/어두운 테마, 두 선택지·안내 창·포인트 제출 포함.
- 변경한 Dart 파일 7개 정적 검사·포맷 검사 통과.
- 표준 `./tool/verify.sh test/api_betting_repository_test.dart test/betting_widgets_test.dart`는 수정하지 않은 파일 11개의 기존 포맷 문제로 중단됐어요. 전체 `flutter analyze`에는 기존 `main.dart`의 Firebase 패키지·`firebase_options.dart` 부재로 인한 오류 4개와 기타 진단이 있어요. 베팅 변경 파일에는 진단이 없어요. 검사 우회를 위해 다른 작업의 코드를 수정하지 않았어요.
- 전체 `flutter test`: 803개 통과, 32개 실패. Firebase 설정, 카탈로그 시즌 기대값, 선수 지표·팀 화면·경기 분석 화면 등의 실패가 남아 있어요. 전체 앱 검증 완료로 보고하지 않아요. 이 32건 전체를 변경 전과 비교한 검증은 하지 않았어요. 상세 로그: `flutter-full-tests.log`.
- 실제 운영 API·운영 포인트 지급은 미검증이에요. 이번 테스트는 로컬·격리 DB에서만 수행했어요.

추천 커밋 메시지: `feat(betting): 컵·유럽대항전 베팅과 최종 경기 결과 정산 구현`

## 경기 형식 확인 출처

- [Sportmonks scores — CURRENT와 PENALTIES 구분](https://docs.sportmonks.com/v3/tutorials-and-guides/tutorials/includes/scores)
- [UEFA 2026/27 UCL Article 21](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-21-Knockout-system-extra-time-and-penalty-shoot-outs-Online)
- [FA컵 2024/25 본선 재경기 폐지](https://www.thefa.com/news/2024/apr/18/emirates-fa-cup-format-calendar-update-increased-premier-league-grassroots-funding-20241804)
- [EFL 컵 규정](https://www.efl.com/documents/efl-cup-rules)
- [Lega Serie A 2024~2027 컵 대회 구조](https://img.legaseriea.it/vimages/649ac001/IAO%20COPPA%20ITALIA_SUPERCOPPA%20ITALIANA_2024-2027.pdf)
- [RFEF 코파 델레이 준결승 1·2차전](https://rfef.es/es/noticias/definida-la-ruta-con-destino-sevilla)
