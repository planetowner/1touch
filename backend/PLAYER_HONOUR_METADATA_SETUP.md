# 선수 우승 이력 이름 보완

> 아래 적용 전 수치와 미반영 표시는 최초 구현 당시의 기록이에요. 2026-09-22 후속 요청으로 운영 반영을 진행하며, 현재 상태는 해당 배포 결과 보고서를 기준으로 확인해 주세요.

선수 상세 `Career → TROPHIES → TEAM`의 대회명을 보완하는 작업이에요. 2026-09-22 기준으로 코드와 조회 검증을 마쳤고, 운영 DB 반영과 배포는 실행하지 않았어요.

## 확인 결과

| 항목 | 현재 DB | 명령 실행 후 예상 |
| --- | ---: | ---: |
| 선수 팀 우승 기록 | 5,694건 | 5,694건 |
| 대회명이 없는 기록 | 3,089건 | 8건 |
| 시즌명이 없는 기록 | 3,089건 | 3,089건 |

현재 구독에서 조회되는 대회는 31개예요. 이름이 누락된 기록의 대회 257개는 이 목록 밖에 있어요. 실제 선수 우승 응답에서도 해당 `league`·`season` 관계가 비어 있었고, 대회 163·시즌 18220의 개별 조회에서도 정보가 반환되지 않았어요. 같은 선수 데이터를 다시 수집하는 것만으로는 누락이 해결되지 않아요.

Sportmonks가 공개한 아래 두 목록에서 ID가 일치하는 대회 254개의 이름을 확인했어요. 이 이름으로 우승 기록 3,081건을 보완할 수 있어요.

- [Sportmonks 공식 대회 목록](https://www.sportmonks.com/football-api/coverage/)
- [공식 페이지의 Download Coverage 문서](https://docs.google.com/spreadsheets/d/1EoyP_GGvi1pUWHnCRJGVou0mDSFg0C4aCMB2bvuyYsk/edit#gid=664279901)

확인한 이름·출처·확인일은 [honour_competition_names.json](C:/dev/1touch/backend/python/one_touch_loader/core/honour_competition_names.json)에 담았어요. 공식 페이지에서 ID별 이름이 하나로 확인되는 항목을 우선하고, 나머지는 공식 문서에서 확인했어요. 목록은 현재 대회명을 제공하므로 과거 시즌 당시의 명칭을 별도로 복원하지는 않아요.

## 코드 동작

- 기존 `player_team_honours.competition_name`의 `NULL`만 채워요. 대회 마스터 이름이 이미 있는 기록은 보완 대상에서 제외해요.
- 우승 기록의 추가·삭제, 기존 이름 덮어쓰기, 시즌 추정은 하지 않아요.
- 선수 우승을 다시 수집할 때도 같은 이름 조회 함수를 써요. 공급사가 이름을 주면 그 값을 우선하고, 관계가 비어 있으면 확인한 공식 이름을 사용해요.
- 운영 DB에서 필요한 표시 정보 컬럼을 확인했어요. 이번 작업에 새 테이블이나 마이그레이션은 필요하지 않아요.
- 기존 선수 상세 조회는 이미 `COALESCE(대회 마스터 이름, 우승 기록의 대회명)`을 사용해요. 프런트엔드와 API 응답 형식은 수정하지 않았어요.
- 명령의 기본 동작과 `--check`는 조회예요. `--apply`를 지정해야 DB에 반영해요.

## 직접 실행할 명령

아래 명령은 `C:\dev\1touch\backend`의 기존 DB 접속 설정을 사용해요. 사용자가 지정한 작업 규칙에 따라 DB 변경 명령은 직접 실행해야 해요.

먼저 보완 대상을 확인해 주세요.

```powershell
Set-Location 'C:\dev\1touch\backend'
$env:PYTHONPATH = (Join-Path (Get-Location) 'python')
$env:PYTHONIOENCODING = 'utf-8'
New-Item -ItemType Directory -Path 'C:\dev\1touch\outputs\honour-metadata-20260922' -Force | Out-Null
& 'C:\Users\eunwo\AppData\Local\Programs\Python\Python311\python.exe' -m one_touch_loader.loaders.player_team_honours_loader --check --output 'C:\dev\1touch\outputs\honour-metadata-20260922\preview.json'
```

확인한 대회명을 반영하고, 반영 직후 DB를 다시 조회해 결과를 저장해요.

```powershell
& 'C:\Users\eunwo\AppData\Local\Programs\Python\Python311\python.exe' -m one_touch_loader.loaders.player_team_honours_loader --apply --output 'C:\dev\1touch\outputs\honour-metadata-20260922\applied.json'
```

현재 데이터가 그대로라면 `updated_rows`는 3,081이에요. `observed_after`에서 `competition_names_to_fill=0`, `missing_competition_names_before=8`, `missing_season_names=3089`를 확인할 수 있어요. 같은 명령을 다시 실행하면 이미 채운 이름은 수정하지 않아요. 이후 운영 수집에서도 이 규칙을 사용하려면 수정한 코드와 JSON 파일을 함께 배포해야 해요.

## 아직 필요한 원본

대회명 8건은 공식 공개 목록에서도 ID를 확인하지 못했어요.

| 대회 ID | 영향받는 우승 기록 |
| --- | ---: |
| 1187 | 6건 |
| 2295 | 1건 |
| 2532 | 1건 |

시즌명은 790개 시즌 ID에 걸친 3,089건이 남아요. 공개 대회 목록에는 시즌 ID와 연도의 대응 정보가 없어요. Sportmonks에서 이 ID들의 시즌 정보를 받거나, 같은 ID와 시즌명을 확인할 수 있는 원본이 필요해요. 팀의 활동 시기나 ID 순서로 연도를 추측하지 않았어요.

[조회 결과](C:/dev/1touch/outputs/honour-metadata-20260922/preview.json)의 `unresolved_seasons`에 필요한 대회 ID·시즌 ID·영향받는 우승 건수를 정리했어요. 따라서 이번 명령만 실행해도 우승 시즌까지 모두 완성되는 것은 아니에요.

## 검증

- 관련 테스트 12개 통과: 공급사 이름 우선, 누락 관계 처리, 조회 모드의 DB 쓰기 금지, 기존 이름·시즌 보존, 우승 행 수 보존, 반영 후 재조회.
- 운영 DB 조회 미리보기: 5,694건 중 대회명 3,081건 보완 가능, 실제 변경 0건.
- 저장된 선수 원본 2,592명·우승/준우승 11,026건 전체 재처리: 우승 5,694건의 식별 키와 기존 시즌·대회명 유지 확인. [원본 검증 결과](C:/dev/1touch/outputs/honour-metadata-20260922/source-validation.json)
- DB 변경 테스트는 메모리 안의 임시 DB와 모의 연결에서만 실행했어요.

테스트 재실행:

```powershell
Set-Location 'C:\dev\1touch\backend'
$env:PYTHONPATH = (Join-Path (Get-Location) 'python')
$env:PYTHONIOENCODING = 'utf-8'
& 'C:\Users\eunwo\AppData\Local\Programs\Python\Python311\python.exe' -m unittest diagnostics.test_player_team_honours
```
