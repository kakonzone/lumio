# Phase 10 — Task 2 verification (SSL pinning)

## Unit tests

```bash
flutter test test/security/ssl_pinning_test.dart
```

## Analyze

```bash
flutter analyze lib/security/ssl_pinning.dart lib/network/secure_dio.dart lib/main.dart
```

## Logcat

```bash
adb logcat | grep -E '\[SSL\]'
```

| Build | Pin | Expected |
|-------|-----|----------|
| Release | Correct | `[SSL] pin verified host=...` |
| Release | Wrong define | `[SSL] pin mismatch — connection rejected` |
| Debug | Any | No reject (pinning skipped) |

## PEM check

```bash
find assets -name '*.pem' 2>/dev/null | wc -l
# Expected: 0
```
