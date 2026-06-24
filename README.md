# Lumio Sports TV

A Flutter-based IPTV streaming application for live TV, VOD, news, and sports content.

## Features

- **Live TV Streaming**: Multi-channel live television with HLS support
- **Sports Coverage**: Live scores, schedules, and match updates from ESPN and Cricbuzz
- **VOD Library**: Video-on-demand content catalog
- **News Feed**: Real-time news from BBC Sport and ESPN
- **Multi-network Ads**: Adsterra, Unity Ads, and Monetag integration
- **Background Tasks**: Periodic score refresh, match polling, and cache cleanup
- **Offline Support**: Connectivity status banner and caching
- **Security**: SSL pinning, play integrity, and blocked apps detection

## Tech Stack

- **Framework**: Flutter 3.41.6 (Dart SDK >=3.0.0)
- **State Management**: Provider
- **Networking**: Dio 5.9.2 (migrated from http package)
- **Video Player**: media_kit with native Android libraries
- **Backend**: Appwrite for channel catalog and configuration
- **Analytics**: Firebase (analytics, crashlytics, messaging)
- **Ads**: Unity Ads, Adsterra, LevelPlay (IronSource), Monetag

## Development Setup

### Prerequisites

- Flutter SDK 3.41.6 or higher
- Android SDK with API level 33+
- Dart SDK >=3.0.0

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/lumio.git
cd lumio
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure secrets (see `docs/SECRETS.md`):
```bash
cp secrets.json.template secrets.json
# Edit secrets.json with your configuration
```

4. Run the app:
```bash
flutter run --dart-define-from-file=secrets.json
```

## Building

### Debug APK
```bash
flutter build apk --debug
```

### Release APK (split per ABI)
```bash
flutter build apk --release --split-per-abi --dart-define-from-file=secrets.json
```

### Release App Bundle
```bash
flutter build appbundle --release --dart-define-from-file=secrets.json
```

## Configuration

### Environment Variables

Key configuration is loaded via `--dart-define` flags or `secrets.json`:

- `LUMIO_BACKEND_BASE_URL`: Backend API URL
- `LUMIO_BACKEND_APP_KEY`: Backend API key
- `STREAM_TOKEN_BASE_URL`: Signed stream token endpoint
- `REMOTE_CHANNELS_URL`: Cloudflare Worker channel catalog
- `APPWRITE_MAIN_PROJECT_ID`: Appwrite project ID
- `APPWRITE_MAIN_ENDPOINT`: Appwrite endpoint

See `docs/SECRETS.md` for the complete configuration reference.

### Ad Configuration

Ads are disabled by default in debug builds. Enable for testing:

```bash
flutter run --dart-define=ADS_ENABLED=true
```

Or set in `secrets.json`:
```json
{
  "ADS_ENABLED": "true"
}
```

## Testing

Run all tests:
```bash
flutter test
```

Run tests with coverage:
```bash
flutter test --coverage
```

## Code Quality

Run analyzer:
```bash
flutter analyze
```

Format code:
```bash
dart format .
```

## CI/CD

GitHub Actions workflows:

- **CI**: Runs on push to main and feature branches - analyzes code, runs tests, builds debug APK
- **Release**: Builds release APK on push to main, publishes to Appwrite, creates GitHub release

## Project Structure

```
lib/
├── config/          # Configuration (app config, ad config, security config)
├── core/            # Core utilities (logging, performance, player helpers)
├── data/            # Data models and channel sources
├── models/          # Domain models
├── screens/         # UI screens (TV, news, live TV, player, etc.)
├── services/        # Business logic services (Appwrite, Firebase, ad networks)
├── widgets/         # Reusable UI components
├── ads/             # Ad implementation (SDKs, waterfall, analytics)
├── security/        # Security features (SSL pinning, play integrity)
└── utils/           # Utility helpers (retry, sound manager, Easter eggs)
```

## Documentation

- `docs/SECRETS.md`: Configuration and secrets management
- `docs/APPWRITE_WORLD_CUP_CARDS.md`: Appwrite featured events setup
- `AGENTS.md`: Project-specific guidelines for AI agents

## License

Proprietary - All rights reserved.

## Support

For support, contact: support@lumio.app
