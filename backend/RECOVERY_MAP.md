# 리커버리 맵 API

회원 인증이 필요한 기존 `GET /v1/fixtures/{fixture_id}/analysis` 응답을 확장합니다.
기존 이벤트·평균 회수 위치·진영별 비중은 유지합니다. DB 스키마 변경이나 재적재는 필요하지 않습니다.

## 화면에 사용할 값

`teams.home/away.defensive_activity`에 다음 두 배열이 추가됩니다.

| 필드 | 의미 |
|---|---|
| `thirds[].third` | `defensive`, `middle`, `attacking` 순서 |
| `thirds[].count` | 해당 구역의 골키퍼 제외 회수 횟수 |
| `thirds[].percentage` | 해당 팀의 전체 필드 선수 회수 중 구역 비중(%) |
| `league_comparison[].third` | 비교할 구역 코드 |
| `league_comparison[].league_percentage` | 같은 시즌·대회 평균 비중(%) |
| `league_comparison[].difference_pp` | 팀 비중에서 평균 비중을 뺀 값(%p) |

양 팀 모두 오른쪽 공격 방향으로 정규화한 x 좌표를 사용합니다.
수비 구역은 `x < 100/3`, 중앙 구역은 `100/3 <= x < 200/3`, 공격 구역은 `x >= 200/3`입니다.
세 구역의 분모는 동일한 팀의 전체 필드 선수 Recovery입니다. 태클·가로채기·클리어링은 섞지 않습니다.
소수 6자리로 응답하며, 평균·차이는 반올림 전 값으로 계산합니다. 화면에서는 차이를 소수 1자리의 **%p**로 표시할 수 있습니다.
차이의 색은 회수 비중이 높고 낮음을 나타내며 경기력 평가를 뜻하지 않습니다.

## 리그 비교 기준

최상위 `recovery_baseline`에 비교 범위와 표본 정보를 제공합니다.

- `season_id`, `competition_id`, `season`, `through`: 대상 경기의 시즌·대회·시작 시각(UTC).
- 같은 시즌의 모든 스테이지에서 `starting_at <= through`, 종료 상태 `5/7/8`인 경기만 대상으로 합니다.
- 대상 경기와 동시각 경기도 종료 상태면 포함하며, 이후 경기는 제외합니다.
- 각 **팀·경기의 구역 비중을 동일 가중치로 평균**냅니다. 모든 회수 횟수를 합친 뒤 비율을 구하지 않습니다.
- 한 팀이라도 골키퍼 여부를 판단하지 못한 Recovery가 있으면 해당 경기의 양 팀을 비교에서 제외합니다.
- 회수 0회 팀은 비중이 정의되지 않으므로 평균에서 제외합니다. 상대 팀의 비중은 양 팀 포지션이 완전하면 포함합니다.

| 표본 필드 | 의미 |
|---|---|
| `finished_fixture_count` | 기간 내 종료 경기 수 |
| `collected_fixture_count` | Opta 분석 수집 완료 경기 수 |
| `uncollected_fixture_count` | 분석 미수집 경기 수 |
| `included_fixture_count` | 실제 평균에 한 팀 이상 포함된 경기 수 |
| `team_match_count` | 평균에 포함된 팀·경기 수 |
| `excluded_position_incomplete_fixture_count` | 포지션 누락으로 양 팀을 제외한 경기 수 |
| `excluded_zero_recovery_team_match_count` | 포지션 검증을 통과했지만 회수 0회로 제외한 팀·경기 수 |
| `recovery_count` | 포함된 팀·경기의 회수 횟수 합계(평균의 가중치가 아님) |
| `includes_target` | 대상 경기의 한 팀 이상이 평균에 포함됐는지 여부 |
| `thirds` | 구역별 평균 비중 |

미수집 경기는 `available=false`, `teams=null`, `recovery_baseline=null`입니다.
팀 포지션이 불완전하면 기존 `complete=false`와 함께 구역 횟수·비중·차이를 `null`로 반환합니다.
확인된 회수 지점은 계속 제공하지만 부분합을 팀 전체 비중으로 표시하지 않습니다.
완전한 팀의 회수가 0회면 구역 횟수는 0, 비중·차이는 `null`입니다.
비교 표본이 없으면 리그 비중과 차이도 `null`이며 0으로 대체하지 않습니다.

## 회수 지점의 선수·시간

`defensive_activity.actions[].attacking_position`을 지도 좌표로 사용합니다.
같은 팀의 `events`에서 `external_event_id`로 연결하면 `player_id`, `player_name`, `minute`, `extra_minute`를 얻습니다.
`actions`에는 골키퍼를 제외한 회수만 있고 `events`에는 기존 전체 이벤트가 있으므로, 점 표시는 `actions`를 기준으로 합니다.
이 연결은 기존 응답 계약이며 이벤트나 좌표를 새로 생성하지 않습니다.

## 확인한 실제 예시

바르셀로나–라싱 산탄데르 `19732687`, 2026-09-16 19:30 UTC:

| 구역 | 회수 | 팀 비중 | 평균 비중 | 차이 |
|---|---:|---:|---:|---:|
| 수비 | 10 | 23.809524% | 44.559771% | −20.750247%p |
| 중앙 | 29 | 69.047619% | 45.605376% | +23.442243%p |
| 공격 | 3 | 7.142857% | 9.834853% | −2.691996%p |

해당 시점 라리가 57경기·114개 팀·경기, 필드 선수 회수 4,278회를 기준으로 합니다.
바르셀로나의 필드 선수 회수는 42개입니다. 이 숫자는 검증 예시이며 API에서 고정하지 않습니다.
