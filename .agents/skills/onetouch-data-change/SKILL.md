---
name: onetouch-data-change
description: Change OneTouch domain models, repositories, providers, mock catalogs, persistence, API transport models, or backend integrations. Use when work crosses the presentation-to-data boundary or depends on an external response contract.
---

# OneTouch Data Change

Preserve the data boundaries summarized in `docs/project-map.md`.

- Verify the actual backend schema and response contract before adding or changing client fields. Read only the relevant contract document under `docs/`; distinguish current behavior from proposals and migration plans.
- Keep stable domain entities separate from transport DTOs and contextual data such as rankings, statistics, seasons, user state, and screen aggregates.
- Make presentation and core code depend on repository abstractions or domain-facing APIs, not concrete mock, HTTP, database, or cache implementations.
- Keep implementation selection in a neutral provider or composition root. Only mock implementations may import mock catalogs.
- Put local persistence behind a replaceable abstraction and document missing synchronization or real-time behavior.
- Refactor incrementally. Add or update focused contract and regression tests before replacing an implementation.
- Isolate temporary compatibility caches and workarounds behind one boundary; record their limitation and removal condition.

Use `docs/testing-guide.md` to select focused tests, then validate with `./tool/verify.sh`.
