---
name: onetouch-ui-change
description: Implement or review OneTouch Flutter UI, themes, screenshots, responsive layouts, navigation-facing widgets, and visual regressions. Use for screen and widget work; do not use for data-only or backend-contract changes.
---

# OneTouch UI Change

Keep the requested visual behavior consistent with the app's existing theme and navigation patterns.

- Inspect the target screen, its extracted feature widgets, shared styles, and related widget tests before editing.
- Treat a user-provided screenshot as the visual source of truth when it conflicts with the current implementation.
- Implement responsive behavior for a range of screen sizes rather than one device. Exercise at least a compact `320x568` view and a taller `430x932` view when the affected UI can be widget-tested.
- Check scrolling, clipping, text wrapping, safe areas, keyboard insets, and overflow at relevant sizes.
- Reuse the existing theme extensions and shared styles. Keep light and dark modes working when the affected surface supports both.
- Use platform-native permission and OS-owned interfaces instead of imitating another platform's UI.
- Preserve navigation contracts and stable keys used by existing tests unless the requested behavior requires changing them.

After implementation, consult `docs/testing-guide.md` and run the relevant widget tests through `./tool/verify.sh`.
