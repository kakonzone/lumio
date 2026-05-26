# Device test — Task 4 (8px bottom / vertical overflow)

**READY_FOR_DEVICE_TEST**

---

## Root cause fixed

The drawer “hamburger” was a **68px-tall** `Column` (three bars + gaps) inside a **40px** top row → bottom `RenderFlex` overflow (~8–28px depending on DPI).

| Change | File |
|--------|------|
| Menu → `Icon(Icons.menu_rounded)` in `SizedBox(height: 40)` | `shell_app_bar.dart` |
| Outer `Column` → `mainAxisSize: MainAxisSize.min` | `shell_app_bar.dart` |
| Side slots → explicit `height: _topBarHeight` | `shell_app_bar.dart` |
| Bottom nav bar height 62/66 (was 60/64) | `main_shell_bottom_nav.dart` |

---

## Run

```bash
flutter run --dart-define=ADS_TEST_MODE=true
```

Watch console on:

- HOME (menu icon, not three bars)
- **Favourites** (back + title + subtitle)
- Bottom navigation (all five tabs)

---

## Steps (physical Android)

1. Cold start → HOME — no yellow/black overflow strip under app bar.
2. Open **Favourites** from shell — subtitle under title must not overflow.
3. Tap each bottom tab — no overflow on nav labels.
4. Optional: smallest-width emulator (320dp) — repeat steps 1–3.

---

## Pass / fail criteria

| # | Criterion | Pass |
|---|-----------|------|
| 1 | No `RenderFlex overflowed` (especially **bottom** / 8px) in console | ☐ |
| 2 | Menu icon visible and opens drawer | ☐ |
| 3 | Favourites header readable, subtitle ellipsized | ☐ |
| 4 | `flutter test test/widget/shell_app_bar_overflow_test.dart` passes | ☐ |

**Automated:**

```bash
flutter test test/widget/shell_app_bar_overflow_test.dart
```

**Task 4 result:** ☐ PASS ☐ FAIL — Tester: __________ Date: __________
