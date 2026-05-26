# Shelf dev server relocation (R16)

## Decision

**Relocate** — the Shelf mock API is still useful for local channel/match JSON during development, but it must not live under `lib/` with a `main()` that could be confused with the mobile entrypoint.

## Changes

| Before | After |
|--------|-------|
| `lib/server/server.dart` (`main()`) | **Deleted** |
| — | `bin/dev_server.dart` — run with `dart run bin/dev_server.dart` |
| Routes unchanged | `lib/routes/api_routes.dart` |

`shelf` / `shelf_router` / `shelf_cors_headers` remain in `pubspec.yaml` for the dev binary only; Flutter APK builds do not invoke `bin/dev_server.dart`.

## Verify

```bash
dart run bin/dev_server.dart
curl http://localhost:8080/health
```

APK size: compare `flutter build apk --analyze-size` before/after if needed; impact is minimal (Shelf not tree-shaken into app if unused).
