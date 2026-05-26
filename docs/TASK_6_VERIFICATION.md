# TASK 6 — Remove flutter_inappwebview

```bash
grep flutter_inappwebview pubspec.yaml   # must be absent / commented
grep -r flutter_inappwebview lib/        # no imports
flutter test test/build_hygiene_test.dart
```

**PASS** when hygiene test passes and `webview_flutter` remains for Adsterra.
