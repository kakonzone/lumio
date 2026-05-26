# TASK 7 — Portable ad debug paths

```bash
grep -r '/home/kakonzone' lib/
# PASS: no output

flutter test test/utils/ad_debug_log_test.dart
```

Logs write to app documents: `lumio_ad_debug.log` via `path_provider` (release skips file I/O).
