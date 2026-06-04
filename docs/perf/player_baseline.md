# Player baseline (2026-06-04T13:12:54+06:00)

lib/core/performance_tuning.dart:70:  static int get playerBufferMb =>
lib/core/performance_tuning.dart:77:  static int get playerBufferBytes => playerBufferMb * 1024 * 1024;
lib/core/performance_tuning.dart:92:      'playerBuf=${playerBufferMb}MB',
lib/screens/player_screen.dart:230:      data: {'bufferMb': PerformanceTuning.playerBufferMb},
lib/screens/player_screen.dart:268:        if (mounted) _probeRelatedChannels();
lib/screens/player_screen.dart:318:  void _probeRelatedChannels() {
lib/screens/player_screen.dart:698:          unawaited(_prewarmMpvFilters());
lib/screens/player_screen.dart:926:  Future<void> _configureMpvOnce() async {
lib/screens/player_screen.dart:937:      await n.setProperty('hwdec', 'auto-safe');
lib/screens/player_screen.dart:953:  Future<void> _prewarmMpvFilters() async {
lib/screens/player_screen.dart:967:      location: 'player_screen.dart:_prewarmMpvFilters',
lib/screens/player_screen.dart:999:      await _configureMpvOnce();
lib/screens/player_screen.dart:1118:        message: 'vf scale applied',
lib/screens/player_screen.dart:1389:      if (mounted && !_probeInFlight) _probeRelatedChannels();

## Key symbols (pre–WC hotfix)

| Symbol | File | Line |
|--------|------|------|
| `_configureMpvOnce()` | `lib/screens/player_screen.dart` | 926 |
| `_probeRelatedChannels()` | `lib/screens/player_screen.dart` | 318 |
| `_prewarmMpvFilters()` | `lib/screens/player_screen.dart` | 953 |
| Quality prefs / default | `preferred_quality_height`, `_selectedTargetHeight` (0=Auto) | 172–173, 273–279 |
| `vf scale` via `_applyMpvHeightCap` | `lib/screens/player_screen.dart` | 1093–1102 |
| `playerBufferMb` | `lib/core/performance_tuning.dart` | 70–74 |
