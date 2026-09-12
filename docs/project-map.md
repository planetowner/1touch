# OneTouch Project Map

This document is a navigation aid for the current Flutter client. It describes implemented repository structure, not a promise that proposed backend work already exists.

## Runtime flow

`lib/main.dart` is the application entry point:

1. Flutter bindings are initialized.
2. The saved theme is loaded through `AppThemeController`.
3. The team catalog and local user team preferences are initialized.
4. The player repository restores followed-player state.
5. Firebase initialization is attempted with `lib/firebase_options.dart`.
6. `MyApp` starts with a `GoRouter` route tree.

The main indexed shell exposes Home, Players, Team, and Community tabs. Match, search, profile, notification, comparison, onboarding, and authentication screens use standalone routes.

## Source layout

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | Startup, router, and application shell |
| `lib/screens/` | Full screens and screen-specific tabs |
| `lib/features/` | Reusable or extracted presentation widgets |
| `lib/comm_pages/` | Community, profile, search, and notification pages |
| `lib/SignComps/` | Authentication presentation |
| `lib/core/` | Themes, shared styling, and user preference state |
| `lib/models/` | Domain-facing entities and screen aggregates |
| `lib/data/` | Repository boundaries, providers, mock data, and API implementations |
| `test/` | Unit, repository-contract, and widget regression tests |
| `assets/`, `TeamLogos/` | Runtime images, SVGs, videos, fonts, and animations |

## Data flow and boundaries

The intended direction is:

```text
screen/widget -> repository interface -> selected implementation -> external or mock data
                         |
                         `-> domain model -> screen/widget
```

- Repository interfaces provide the domain-facing boundary.
- `*_repository_provider.dart` files select the active implementation and act as composition roots.
- Mock implementations and catalogs live under `mock/` or use a `mock_` prefix.
- API transport models and mappers remain separate from stable domain models.
- Screens should not import mock catalogs, HTTP clients, databases, or caches directly.

## Current implementation status

Most catalog-oriented providers still select mock implementations, including
teams, players, competitions, seasons, standings, current form, transfers,
trophies, posts, best eleven, and the primary fixture catalog.

The Home aggregate and authenticated current-user profile now use API-backed
repositories configured through `ApiConfig`.

The fixture area is in an incremental API migration:

- `lib/data/fixtures/api/` contains an HTTP repository, transport responses, and mapping code.
- `fixture_repository_provider.dart` exposes the mock-backed
  `fixtureRepository` for complete-catalog consumers and the API-backed
  `fixtureDetailRepository` for query-specific Match screens.
- Match navigation passes its already displayed `Fixture` as transient route
  data for immediate rendering. Direct links without route data load the
  fixture through `GET /v1/fixtures/{fixture_id}`.
- Match Preview and Head-to-Head use the API-backed query repository.
- Synchronous selectors currently coexist with asynchronous loaders and an in-memory compatibility cache.
- See `docs/fixture-cache-migration-plan.md` before extending that cache or switching the provider.

Other live or local integrations are deliberately separate:

- Firebase is initialized at startup. Match live chat uses Firebase Authentication and Realtime Database directly.
- Authentication screens remain mock behavior; `docs/authentication.md` describes the intended production design.
- Theme and user team preferences, including followed teams and players, use
  local state and `shared_preferences`. Profile editing must remain local until
  matching backend write endpoints are deployed.
- Home highlights and news use a feed-backed `HomeContentService`; the Home
  aggregate itself is API-backed.

## Documentation routing

Read only the document relevant to the task:

| Topic | Document |
| --- | --- |
| Authentication architecture and status | `docs/authentication.md` |
| Development startup and named-user launch modes | `docs/development-launch-modes.md` |
| Verified backend loader endpoints | `docs/backend-loader-reference.md` |
| Fixture-detail fields and display rules | `docs/fixture-detail-display-contract.md` |
| Fixture cache limitations and removal | `docs/fixture-cache-migration-plan.md` |
| Flutter 3.47 migration | `docs/flutter-3.47-migration-notes.md` |
| Frontend performance opportunities | `docs/frontend-optimization-notes.md` |
| Focused and full validation | `docs/testing-guide.md` |

Treat documents labeled as plans, prompts, notes, or proposed contracts as non-authoritative until they are verified against the active backend and code.
