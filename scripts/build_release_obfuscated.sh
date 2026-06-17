#!/bin/bash
# Build obfuscated release APK with full security hardening

set -e

echo "🔒 Building obfuscated release APK with security hardening..."

# Check for required environment variables
if [ -z "$RELEASE_STORE_FILE" ] || [ -z "$RELEASE_STORE_PASSWORD" ] || [ -z "$RELEASE_KEY_ALIAS" ] || [ -z "$RELEASE_KEY_PASSWORD" ]; then
    echo "❌ Missing signing credentials. Set required environment variables:"
    echo "   RELEASE_STORE_FILE"
    echo "   RELEASE_STORE_PASSWORD"
    echo "   RELEASE_KEY_ALIAS"
    echo "   RELEASE_KEY_PASSWORD"
    exit 1
fi

# Check for security configuration
if [ -z "$SSL_PIN_PRIMARY" ] || [ -z "$SSL_PIN_BACKUP" ]; then
    echo "❌ Missing SSL pin configuration. Set SSL_PIN_PRIMARY and SSL_PIN_BACKUP"
    exit 1
fi

# Check for Play Integrity configuration
if [ -z "$PLAY_INTEGRITY_PROJECT_NUMBER" ]; then
    echo "❌ Missing Play Integrity project number. Set PLAY_INTEGRITY_PROJECT_NUMBER"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build obfuscated release APK
echo "🔨 Building obfuscated release APK..."
flutter build apk \
    --release \
    --obfuscate \
    --split-debug-info=build/symbols \
    --split-per-abi \
    --dart-define=SSL_PIN_PRIMARY=$SSL_PIN_PRIMARY \
    --dart-define=SSL_PIN_BACKUP=$SSL_PIN_BACKUP \
    --dart-define=PLAY_INTEGRITY_PROJECT_NUMBER=$PLAY_INTEGRITY_PROJECT_NUMBER \
    --dart-define=LUMIO_HMAC_SECRET=$LUMIO_HMAC_SECRET

echo "✅ Build complete!"
echo ""
echo "📱 APK files:"
ls -lh build/app/outputs/flutter-apk/app-*.apk
echo ""
echo "🔐 Debug symbols:"
ls -lh build/symbols/
echo ""
echo "🔒 Security features enabled:"
echo "  - Code obfuscation (--obfuscate)"
echo "  - Debug symbol separation (--split-debug-info)"
echo "  - R8 full mode optimization"
echo "  - ProGuard rules applied"
echo "  - APK signature verification"
echo "  - Play Integrity API verification"
echo "  - TLS certificate pinning"
echo "  - Install watermarking"
echo ""
echo "⚠️  IMPORTANT:"
echo "  1. Keep the debug symbols (build/symbols/) safe for crash reporting"
echo "  2. Test the APK thoroughly before distribution"
echo "  3. Verify Play Integrity token validation in backend"
echo "  4. Monitor backend for security events"