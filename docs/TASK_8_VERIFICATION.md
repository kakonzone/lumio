# TASK 8 — aggressive_mode Remote Config

```bash
flutter test test/ads/aggressive_mode_test.dart
```

Device: set RC `aggressive_mode=true`, cold start — expect:

```
[AdManager] init OK aggressive_mode=true
[Placement] aggressive_mode=true
```

Cooldowns use `AdTriggerManager.scaledCooldownSeconds` (×0.7 when aggressive).
