# Device test — Task 3 (shell_app_bar RenderFlex overflow)

**READY_FOR_DEVICE_TEST**

---

## What changed

| Area | Fix |
|------|-----|
| `_buildRightActions` Row (~line 201) | Wrapped in `FittedBox(scaleDown)` via `_fitRightActions` |
| Center brand | Horizontal padding + `OverflowSafeText` / `FittedBox` on LUMIO+TV |
| Fav badge count | `maxLines: 1` + `TextOverflow.ellipsis` |

File: `lib/widgets/shell_app_bar.dart`

---

## Run

```bash
flutter run --dart-define=ADS_TEST_MODE=true
```

Watch console while navigating:

- HOME (center LUMIO+TV brand)
- Category screen with back + long title
- Narrow device or split-screen (<360dp width)

---

## Steps (physical Android)

1. Open app on a **narrow** phone (or enable display size / small width emulator).
2. Visit **HOME** — confirm top bar shows menu, brand, theme, favorites, bell with no yellow/black overflow stripes.
3. Open **Categories** or any screen with **back** + long title in `ShellAppBar`.
4. Rotate or resize — no horizontal overflow in app bar.

---

## Pass / fail criteria

| # | Criterion | Pass |
|---|-----------|------|
| 1 | No `RenderFlex overflowed` in `flutter run` / logcat during steps above | ☐ |
| 2 | Right actions remain tappable (theme, favorites) | ☐ |
| 3 | Long titles ellipsize, not clip under icons | ☐ |
| 4 | `flutter test test/widget/shell_app_bar_overflow_test.dart` passes | ☐ |

**Automated check:**

```bash
flutter test test/widget/shell_app_bar_overflow_test.dart
```

**Task 3 result:** ☐ PASS ☐ FAIL — Tester: __________ Date: __________
