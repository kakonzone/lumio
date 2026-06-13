# Lumio IPTV App - Agent Documentation

This file contains project-specific commands, learnings, and guidelines for AI agents working on the Lumio IPTV Flutter project.

## Project Overview

Lumio is a Flutter IPTV streaming application with multi-channel live TV, VOD, news, and sports content. The app uses:
- Flutter (Dart) for mobile UI
- Provider for state management
- Firebase for analytics, crashlytics, and messaging
- Appwrite for backend/channel catalog
- Multiple ad networks (Adsterra, Unity Ads, LevelPlay deprecated)
- HLS video streaming via media_kit

## Verification Commands

After any code changes, run this verification sequence:

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
```

**Important:** The codebase has pre-existing build errors unrelated to recent changes. Focus on ensuring no new errors are introduced.

## Pre-existing Issues

The following files have syntax errors that existed before Phase 5-8 work:
- `lib/screens/player/player_controls_bar.dart:815` - Missing '}' and semicolon
- `lib/services/notification_service.dart:25-26` - Invalid static modifier placement
- `lib/services/unity_ads_service.dart:320,332,361,364,368` - Callback syntax errors (expected identifier)

These files are tracked but require separate fixes as they predate the refactoring work.

## Key Directories

- `lib/screens/` - UI screens (TV, news, live TV, player, etc.)
- `lib/widgets/` - Reusable UI components
- `lib/services/` - Business logic services (Appwrite, Firebase, ad networks)
- `lib/ads/` - Ad implementation (ad network SDKs, waterfall, analytics)
- `lib/security/` - Security features (SSL pinning, play integrity, blocked apps)
- `lib/utils/` - Utility helpers (retry, sound manager, Easter eggs)
- `lib/config/` - Configuration (app config, ad config, security config)
- `android/app/src/main/res/xml/network_security_config.xml` - Network security policy

## Important Files

### Configuration
- `lib/config/app_config.dart` - Environment-loaded constants via --dart-define
- `lib/config/ad_config.dart` - Ad network configuration
- `lib/security/security_config.dart` - Security settings (HMAC secret, SSL pins, etc.)

### Key Services
- `lib/services/appwrite_service.dart` - Appwrite database/channel catalog
- `lib/services/firebase_bootstrap.dart` - Firebase initialization
- `lib/services/kill_switch_service.dart` - Remote app shutdown
- `lib/services/catalog_service.dart` - Channel catalog aggregation

### Performance
- `lib/utils/retry.dart` - Centralized retry helper with exponential backoff
- `lib/utils/m3u_merge_parser.dart` - M3U playlist parsing (moved to isolates)
- `lib/core/performance_tuning.dart` - Performance optimization settings

### UI
- `lib/screens/splash_screen.dart` - App initialization screen
- `lib/screens/player/player_screen.dart` - Video player screen
- `lib/widgets/offline_banner.dart` - Global connectivity status banner
- `lib/screens/generic_error_screen.dart` - Error screen for init failures

## Constraints

### DO NOT TOUCH
- `lib/ads/direct_link_rotator.dart` - Active in production
- Any files marked as "DO NOT MODIFY" in code comments

### NO NEW PACKAGES
New package additions require explicit written approval. Check existing dependencies before suggesting new packages.

### Environment Variables
Key --dart-define flags:
- `LUMIO_BACKEND_BASE_URL` - Backend API URL
- `LUMIO_BACKEND_APP_KEY` - Backend API key
- `STREAM_TOKEN_BASE_URL` - Signed stream token endpoint
- `REMOTE_CHANNELS_URL` - Cloudflare Worker channel catalog
- `LUMIO_HMAC_SECRET` - HMAC secret for request signing
- `SCANNED_IPTV_JIO_CHANNELS_URL` - JioTV channels URL
- `SCANNED_IPTV_SCAN_PLAYLIST_URL` - Scan playlist URL
- `SCANNED_IPTV_JIO_STREAM_BASE` - JioTV stream base URL

## Learnings from Phases 5-8

### Phase 5: Performance
- Added `addAutomaticKeepAlives: true` to ListView.builder widgets in search and live TV screens
- Moved M3U parsing to isolates using `compute()` to avoid blocking UI thread
- Applied `dart fix --apply` to resolve lint issues (unused imports, prefer_final_fields, etc.)
- Note: `context.select` optimization caused type compatibility issues in tv_screen.dart and was reverted

### Phase 6: Security
- Moved hardcoded IPTV URLs to environment-loaded constants in AppConfig
- Added kDebugMode guards to localhost URLs in api_service.dart and background_service.dart
- Audited and cleaned network_security_config.xml (removed test domains like api.example.com, invalid.local)
- Moved localhost to debug-overrides section in network security config
- Added integrity-check log in FirebaseBootstrap for empty hmacSecret in release mode

### Phase 7: Missing Features & Polish
- Created OfflineBanner widget using connectivity_plus for global connectivity status
- Created RetryHelper utility with exponential backoff for network operations
- Integrated RetryHelper into AppwriteService.fetchChannels()
- Created GenericErrorScreen for fatal initialization failures
- Wired GenericErrorScreen into SplashScreen error path
- Converted 13 TODO/FIXME comments to ISSUE: tags with GitHub issue placeholders
- Verified audioplayers is actively used in sound_manager.dart infrastructure

### Phase 8: Documentation
- Applied dart format across entire codebase
- Documented pre-existing syntax errors that require separate fixes
- Created AGENTS.md for future agent reference

## Code Style

- Use dart format for all code
- Prefer const constructors where lint suggests
- Avoid unused imports and variables
- Comment out rather than delete deprecated code with clear deprecation notices
- Use ISSUE: tags instead of TODO/FIXME for future work

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/appwrite_channel_parse_test.dart

# Run tests with coverage
flutter test --coverage
```

## Build Variants

```bash
# Debug build
flutter build apk --debug

# Release build (requires signing config)
flutter build apk --release

# Build for specific platforms
flutter build apk --split-per-abi
```

## Common Issues

### Flutter analyze shows warnings but no errors
This is expected. The codebase has pre-existing warnings/info messages. Focus on ensuring no new errors are introduced.

### Build fails with pre-existing errors
If build fails with errors in player_controls_bar.dart, notification_service.dart, or unity_ads_service.dart, these are pre-existing and not caused by recent changes.

### Context compatibility
When using `context.select`, be aware that it has stricter type checking than `context.watch`. If type errors occur, revert to context.watch.

### Isolate usage
When moving code to isolates with `compute()`, ensure the function is top-level and all parameters are serializable (no callbacks or closures).

## Contact

For questions about this project, refer to:
- Main repository: Lumio IPTV
- Documentation: See docs/ directory
- Issue tracking: GitHub issues
