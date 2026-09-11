# Project Working Agreement

## Scope and autonomy

- For explanation, review, diagnosis, or planning requests, inspect the relevant files and report the result without editing unless the user also asks for a change.
- When the user explicitly asks to build, change, or fix something, make reversible in-scope local edits and run relevant validation without requesting another approval.
- Ask before destructive or irreversible actions, external writes, new production dependencies, backend contract changes, broad architectural refactors, or a material expansion of scope.
- If the requirements materially change during implementation, summarize the consolidated scope before continuing.
- Preserve unrelated user changes in the working tree. Do not commit or push; the user handles Git operations.

## Engineering baseline

- Prefer concise implementations. Avoid unnecessary one-use helpers, excessive abstraction, and duplicated constants.
- Verify actual backend schemas and response contracts before implementing client integrations; do not assume an endpoint or field exists.
- Prefer platform-native interfaces for permissions and other OS-owned interactions.
- Use the matching repository skill under `.agents/skills/` for UI, data-layer, verification, or learning work.
- Use `./tool/verify.sh [test paths...]` for standard validation when applicable.
- After a meaningful change, report changed behavior, validation performed, remaining limitations, and a suggested commit message.
