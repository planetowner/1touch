# Flutter Frontend Optimization Notes

이 문서는 OneTouch Flutter 앱의 향후 성능 최적화 후보를 기록한 백로그다.
현재 기능 구현을 우선하고, 실제 병목을 Profile 모드로 측정한 뒤 순서대로 적용한다.

## 먼저 측정하기

Debug 모드는 배포 빌드보다 느리므로 Debug 체감만으로 최적화하지 않는다.
실제 iPhone에서 Profile 모드와 Flutter DevTools를 사용한다.

```bash
flutter run --profile -d 00008110-00163CA11102601E
```

측정할 항목:

- 앱 시작부터 첫 화면 표시까지 걸리는 시간
- 화면 전환과 스크롤 중 프레임 드롭
- Home, Player, Team, Match 화면의 rebuild 범위
- 메모리 사용량과 이미지 디코딩 비용
- 검색 입력 후 결과가 표시되기까지 걸리는 시간

## 우선순위 1: 앱 시작 속도

`lib/main.dart`에서 다음 초기화가 순차적으로 완료된 뒤 `runApp()`을 호출한다.

- `appThemeController.initialize()`
- `currentUserPreferences.initialize()`
- `playerRepository.initializeFollowing()`
- `Firebase.initializeApp()`

개선 후보:

- 서로 독립적인 초기화 작업을 `Future.wait`로 병렬 실행
- 첫 화면에 꼭 필요하지 않은 데이터는 앱을 먼저 띄운 뒤 로드
- 초기화 단계별 시간을 측정해 실제 병목만 변경

## 우선순위 2: 선수 검색과 정렬

`lib/data/players/mock_player_repository.dart`의 현재 구현은 일부 호출마다 전체 선수 목록을 다시 순회한다.

개선 후보:

- ID 검색용 `Map<String, Player>`를 최초 1회 생성
- 랭킹 목록을 최초 1회 계산하고 캐싱
- 리그 및 포지션별 결과 캐싱
- 검색 입력에 200~300ms debounce 적용
- 데이터가 커지면 검색 인덱스 또는 서버 검색 도입

## 우선순위 3: Widget Rebuild 범위

현재 주요 UI 파일 중 일부가 크다.

- `lib/features/MatchInfoFeatures.dart`: 약 1,200줄
- `lib/features/HomeScreenFeatures.dart`: 약 880줄
- `lib/features/PlayerScreenFeatures.dart`: 약 880줄
- `lib/features/TeamScreenFeatures.dart`: 약 870줄

파일 크기 자체가 성능 문제는 아니지만, 넓은 범위의 `setState()`가 불필요한 rebuild를 만들 수 있다.

개선 후보:

- 상태를 사용하는 작은 Widget 단위로 분리
- 변하지 않는 Widget에 `const` 적용
- `ValueListenableBuilder` 등의 구독 범위를 필요한 UI로 제한
- DevTools의 Track Widget Rebuilds로 실제 rebuild 확인

## 우선순위 4: 긴 목록과 스크롤

긴 동적 콘텐츠를 `SingleChildScrollView`와 큰 `Column`으로 모두 생성하면 첫 렌더링과 메모리 비용이 커질 수 있다.

개선 후보:

- 반복 목록은 `ListView.builder` 또는 `GridView.builder` 사용
- 복합 스크롤 화면은 `CustomScrollView`, `SliverList`, `SliverGrid` 검토
- 짧은 정적 화면의 `SingleChildScrollView`는 그대로 유지
- 이미지가 많은 목록은 화면에 보이는 항목만 생성

## 우선순위 5: 이미지와 영상

현재 전체 에셋은 약 9MB로 심각하게 크지는 않다. 상대적으로 큰 파일은 다음과 같다.

- `assets/Onboarding.mp4`: 약 2.8MB
- `assets/flag_video.mp4`: 약 0.9MB
- `assets/playerSilhouette.svg`: 약 0.8MB
- `assets/player_comparison/player_placeholder.png`: 약 0.6MB

개선 후보:

- 영상 컨트롤러를 필요한 화면에서만 생성하고 반드시 dispose
- 영상 bitrate와 해상도 조정
- 큰 PNG를 실제 표시 크기에 맞춰 축소하거나 WebP 검토
- 복잡한 SVG path 단순화
- 큰 래스터 이미지에 적절한 `cacheWidth`/`cacheHeight` 적용

## 우선순위 6: 패키지와 앱 용량

- 실제로 사용하지 않는 패키지 제거
- 패키지 major 업데이트는 한 번에 하지 않고 기능별로 검증
- iOS와 Android release 빌드 크기를 각각 측정
- 네이티브 플러그인이 시작 시간과 앱 크기에 미치는 영향 확인

## 권장 실행 순서

1. 실제 iPhone에서 Profile 모드 기준값 기록
2. 시작 초기화 시간 측정 및 병렬화
3. 선수 ID 조회와 랭킹 결과 캐싱
4. 검색 debounce 적용
5. 느린 화면의 rebuild 범위 축소
6. 긴 목록 lazy rendering 적용
7. 마지막에 이미지, 영상, 앱 용량 최적화

## 완료 체크리스트

- [ ] Profile 모드 기준 성능 기록
- [ ] 앱 시작 단계별 시간 측정
- [ ] 선수 ID 인덱스 추가
- [ ] 랭킹 캐싱 적용
- [ ] 검색 debounce 적용
- [ ] 주요 화면 rebuild 측정
- [ ] 긴 목록 lazy rendering 점검
- [ ] 이미지 및 영상 용량 점검
- [ ] release 앱 크기 비교
