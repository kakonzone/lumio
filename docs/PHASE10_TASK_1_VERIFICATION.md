# Phase 10 — Task 1 verification (stream token)

## Unit tests

```bash
cd /path/to/lumio
flutter test test/services/stream_token_service_test.dart
```

## Analyze

```bash
flutter analyze lib/services/stream_token_service.dart lib/services/channel_resolver.dart lib/config/app_config.dart
```

## Device logcat (protected channel)

```bash
adb logcat -c
adb logcat | grep -E 'StreamToken|ChannelResolver'
```

**Expected on starshare / protected tap:**

```
[StreamToken] fetched for <channelId>, expires in 3600s
```

**When `STREAM_TOKEN_BASE_URL` unset (debug only):**

```
[StreamToken] BASE_URL not set — protected channels disabled
```

**Public HTTP channel:** no `[StreamToken] fetched` line.

## Release gate

Release build without `STREAM_TOKEN_BASE_URL` throws at startup in `main()`.
