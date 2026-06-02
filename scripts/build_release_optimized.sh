#!/bin/bash
# Build optimized release APK with size reduction
# This script builds separate APKs for each architecture for smaller downloads

set -e

echo "🔨 Building optimized release APKs..."
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build release APK with split-per-abi
echo "📱 Building release APKs (split by ABI)..."
flutter build apk --release \
  --split-per-abi \
  --target-platform android-arm64 \
  --obfuscate \
  --split-debug-info=./build/app/outputs/symbols

echo ""
echo "✅ Build complete!"
echo ""
echo "📊 APK sizes:"
ls -lh build/app/outputs/flutter-apk/*.apk | awk '{print $9, $5}'
echo ""
echo "💡 Tips:"
echo "  - arm64-v8a APK is for most modern devices (recommended)"
echo "  - armeabi-v7a APK is for older devices"
echo "  - Upload both to Play Store for automatic delivery"
echo ""
echo "📦 For App Bundle (Play Store):"
echo "  flutter build appbundle --release"
echo ""
echo "🔤 For font optimization (optional):"
echo "  pip install fonttools brotli"
echo "  python3 scripts/font_subset.py"
