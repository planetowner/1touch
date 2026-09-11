# OneTouch Testing Guide

Use the smallest meaningful test set first, then broaden based on the affected boundary and risk.

## Standard commands

Focused validation:

```bash
./tool/verify.sh test/example_test.dart test/another_test.dart
```

Full validation:

```bash
./tool/verify.sh
```

Both forms check Dart formatting and run `flutter analyze`. With test paths, only those tests run; without paths, the full Flutter test suite runs.

## Test selection

| Changed area | Start with |
| --- | --- |
| Models and parsing | Matching `*_model_test.dart`, response, and mapper tests |
| Repository interface or implementation | Matching mock/API repository test and contract tests under `test/support/` when present |
| Fixtures and match loading | `api_fixture_*`, `fixture_model_test.dart`, `mock_fixture_repository_test.dart`, and affected match or Home widget tests |
| Teams, seasons, standings | Matching repository or catalog tests plus affected team-screen tests |
| Home aggregation and feeds | `home_*`, `mock_home_repository_test.dart`, and `home_content_service_test.dart` |
| Community and posts | `mock_post_repository_test.dart`, `community_post_repository_test.dart`, `post_report_repository_test.dart`, and community widget tests |
| Theme or shared styles | Theme controller test plus every affected screen theme test |
| Routing or shared application shell | Navigation tests, affected screen tests, and `widget_test.dart` |
| Player screens and comparison | Player repository or model tests and `player_*` widget tests |

Use `rg --files test` and search imports or symbols when the mapping is unclear; filenames are guidance rather than a substitute for dependency inspection.

## Responsive UI checks

For layout changes, exercise at least:

- Compact: `320x568`
- Taller: `430x932`

Check for render overflow, clipped content, inaccessible controls, broken safe areas, and unexpected scrolling. Reuse existing test harnesses where possible instead of adding tests that only mirror implementation details.

## When to run the full suite

Run `./tool/verify.sh` without test paths when a change touches shared core code, routing, repository contracts, provider selection, multiple feature areas, or release readiness. Also run it after focused failures reveal wider coupling.

Report commands and results exactly. If environment or pre-existing failures prevent completion, record what passed and what remains unverified.
