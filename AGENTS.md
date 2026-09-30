# Project Working Agreement

## Approval before changes

- For every new request that would create, modify, or delete a file, or generate code intended for use, first inspect the relevant files without changing them.
- Before making any change, explain to the user in plain language: the concept and expected behavior; which files would change and why; the key language syntax or API calls involved, with a short illustrative snippet when useful; and how the result will be checked.
- Then explicitly ask for approval and stop. Do not edit files, generate a patch, run a command that writes project files, or implement the change until the user approves that concrete proposal.
- An approval covers only the described change and its normal tests/formatting. If the approach, files, or scope materially change, explain the difference and ask for approval again. Do not treat approval from a previous task or chat as blanket permission.
- Read-only inspection and discussion are allowed before approval. A syntax snippet used only to explain the proposal is allowed; do not present it as a completed implementation.
- After approval, implement the approved change, verify it, and report what changed. Preserve unrelated user changes.

This agreement applies to future work in this repository, including new chat sessions that load this `AGENTS.md`.

## Engineering and workflow

- Implement responsive layouts for general screen sizes rather than targeting a specific device.
- After approved UI changes, test compact and taller screens and check for overflow.
- After approved changes, run formatting, focused tests, static analysis, and broader regression tests when appropriate.
- Treat user-provided screenshots as the visual source of truth when they conflict with the current implementation.
- After completing a meaningful group of changes, recommend a commit message automatically.
- Prefer concise implementations. Avoid unnecessary one-use helpers, excessive abstraction, and duplicated constants.
- Do not commit or push changes. The user handles Git operations; recommend an appropriate commit message after each meaningful change.
- Prefer platform-native system interfaces for permissions and other OS-owned interactions; do not imitate one platform's UI on another.
- When implementing a feature without a backend, keep local persistence behind a replaceable abstraction and clearly document limitations such as missing synchronization or real-time updates.
- Preserve architectural boundaries: presentation and core modules should depend on abstractions or domain-facing APIs rather than concrete mock, API, database, or cache implementations.
- Before implementing client models or integrations, verify assumptions against the actual backend schema and response contracts; do not assume an endpoint or field exists.
- Keep stable domain entities separate from contextual data such as rankings, statistics, seasons, user-specific state, and screen-specific aggregates.
- Perform architectural refactors incrementally, preserve existing behavior, and add focused contract or regression tests before replacing implementations.
- Isolate temporary workarounds behind a clear boundary, document their limitations and removal condition, and avoid spreading them across the codebase.

## Learning and Documentation

- When explaining this codebase to a beginner, start with the overall structure and runtime flow; show code examples last.
- For learning quizzes, use the format: Problem → Answer → Explanation.
- During an interactive quiz, do not reveal the full answer until every question is answered correctly. Identify the misunderstood concept and provide a focused hint instead.
- When asked for a code-learning playground, place it under `docs/` as a standalone HTML file and do not modify application code unless explicitly requested.
