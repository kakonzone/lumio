# Post-audit sprint — verification snippets

## TASK 1 — Duplicate load race

```bash
adb logcat -c && adb logcat -s flutter | grep -E 'rewarded loading|627|already in flight'
```

**Pass:** No `errorCode=627`; second call logs `load skipped — already in flight`.

## TASK 2 — Firebase reserved names

```bash
adb logcat -s flutter | grep -i 'reserved'
grep -rE "logEvent.*name:\s*['\"]ad_(click|impression)" lib/ || echo OK
```

**Pass:** Zero reserved-name errors; grep empty.

## TASK 3 — WebView cache

```bash
adb logcat -s flutter | grep AdsterraCache
```

**Pass:** Same placement shows 1 miss then repeated `hit`.

## TASK 4 — Player rebuilds

```bash
adb logcat -s flutter | grep 'PlayerScreen] rebuild'
```

**Pass:** Fewer rebuilds during buffering; ads in isolated `PlayerAdSlot`.

## TASK 5 — No-fill backoff

```bash
adb logcat -s flutter | grep -E 'no-fill backoff|lumio_levelplay_fill_attempt'
```

**Pass:** After consecutive `509`, next load delayed ≥ 30s.

## TASK 6 — Lifecycle

```bash
adb logcat -s flutter | grep 'disposed before paint'
```

**Pass:** Back during load → impression suppressed log.

## TASK 7 — Diagnostics

Build with `DIAGNOSTICS_ENABLED=true`, 7-tap version in drawer.
