# Project Working Agreement

1. Before editing files, explain the intended changes and wait for explicit user approval.
2. Read-only inspection is allowed before approval.
3. If requirements change before implementation, present the consolidated plan and request approval again.
4. Implement responsive layouts for general screen sizes rather than targeting a specific device.
5. After approved UI changes, test compact and taller screens and check for overflow.
6. After approved changes, run formatting, focused tests, static analysis, and broader regression tests when appropriate.
7. Treat user-provided screenshots as the visual source of truth when they conflict with the current implementation.
8. After completing a meaningful group of changes, recommend a commit message automatically.
9. Prefer concise implementations. Avoid unnecessary one-use helpers, excessive abstraction, and duplicated constants.
10. Do not commit or push changes. The user handles Git operations; recommend an appropriate commit message after each meaningful change.
11. Prefer platform-native system interfaces for permissions and other OS-owned interactions; do not imitate one platform's UI on another.
12. When implementing a feature without a backend, keep local persistence behind a replaceable abstraction and clearly document limitations such as missing synchronization or real-time updates.
13. Preserve architectural boundaries: presentation and core modules should depend on abstractions or domain-facing APIs rather than concrete mock, API, database, or cache implementations.
14. Before implementing client models or integrations, verify assumptions against the actual backend schema and response contracts; do not assume an endpoint or field exists.
15. Keep stable domain entities separate from contextual data such as rankings, statistics, seasons, user-specific state, and screen-specific aggregates.
16. Perform architectural refactors incrementally, preserve existing behavior, and add focused contract or regression tests before replacing implementations.
17. Isolate temporary workarounds behind a clear boundary, document their limitations and removal condition, and avoid spreading them across the codebase.

## Learning and Documentation

- When explaining this codebase to a beginner, start with the overall structure and runtime flow; show code examples last.
- For learning quizzes, use the format: Problem → Answer → Explanation.
- During an interactive quiz, do not reveal the full answer until every question is answered correctly. Identify the misunderstood concept and provide a focused hint instead.
- When asked for a code-learning playground, place it under `docs/` as a standalone HTML file and do not modify application code unless explicitly requested.
