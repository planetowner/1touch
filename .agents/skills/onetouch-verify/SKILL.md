---
name: onetouch-verify
description: Validate OneTouch Flutter changes with formatting, focused tests, static analysis, responsive checks, and proportionate regression testing. Use after code changes or when asked to check project health.
---

# OneTouch Verification

Read `docs/testing-guide.md`, inspect the changed paths, and choose the smallest meaningful test set first.

- Run `./tool/verify.sh <test files...>` for focused validation. The script checks formatting and static analysis before the selected tests.
- Run `./tool/verify.sh` for the full suite when changes affect shared core behavior, routing, repository contracts, multiple features, or release readiness.
- For UI changes, cover compact and taller screens and check for Flutter overflow exceptions when relevant.
- Broaden or repeat tests only when new edits, failures, shared dependencies, or unresolved risk justify it.
- Do not hide failures caused by the current change. Clearly separate pre-existing failures or environment limitations from regressions.
- Report the exact commands run, their result, and any checks not run.
