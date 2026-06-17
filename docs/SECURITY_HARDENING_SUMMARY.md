# Anti-Tamper / Anti-Clone Hardening Implementation Summary

This document summarizes the comprehensive security hardening implemented to prevent app cloning and tampering.

## Implemented Security Features

### 1. Play Integrity API Verification ✅

**Files Created:**
- `android/app/src/main/kotlin/com/kakonzone/lumio/PlayIntegrityBridge.kt` - Kotlin Play Integrity API bridge
- `lib/security/play_integrity_service.dart` - Dart Play Integrity service

**Features:**
- Verifies device integrity (MEETS_DEVICE_INTEGRITY)
- Verifies app integrity (MEETS_BASIC_INTEGRITY)
- Verifies Play Store recognition (PLAY_RECOGNIZED)
- Token caching with 10-minute TTL
- Backend token validation
- Configured via `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` dart-define

**Integration:**
- Added to MainActivity method channel
- Initialized in main.dart before app launch
- Backend verification required for API access

### 2. APK Signature Verification ✅

**Files Enhanced:**
- `android/app/src/main/kotlin/com/kakonzone/lumio/MainActivity.kt` - Signature retrieval method
- `lib/security/anti_clone_service.dart` - Signature verification logic
- `lib/security/security_config.dart` - Expected signature configuration

**Features:**
- Retrieves actual APK signature from device
- Compares against expected SHA-256 fingerprint
- Configured via `expectedApkSignatureSha256` in SecurityConfig
- Fails app launch if signature mismatch
- Package name verification

**Implementation:**
- Platform channel method: `getApkSignatureSha256()`
- Platform channel method: `getPackageName()`
- Automatic verification on app start

### 3. Package Name Verification ✅

**Files Enhanced:**
- `lib/security/security_config.dart` - Expected package name
- `lib/security/anti_clone_service.dart` - Package name verification

**Features:**
- Verifies package name matches expected value
- Configured via `expectedPackageName` in SecurityConfig
- Prevents app repackaging with different package name
- Fails app launch if package name mismatch

**Configuration:**
```dart
static const String expectedPackageName = 'com.kakonzone.lumio';
```

### 4. Root/Jailbreak Detection ✅

**Files Enhanced:**
- `lib/security/security_manager.dart` - Existing root detection
- `lib/security/anti_clone_service.dart` - Comprehensive device integrity checks

**Detection Methods:**
- Root binary detection (`/system/xbin/su`, etc.)
- Magisk detection (`/sbin/.magisk`, `/data/adb/magisk`)
- Emulator detection
- Debugger detection (`TracerPid`)
- Frida detection (`frida` in `/proc/self/maps`, port 27042)
- Xposed/LSPosed detection

**Features:**
- Periodic background checks (60-second watchdog)
- Soft-block mode (degraded functionality vs hard exit)
- Configurable via `strictModeInRelease` in SecurityConfig
- Debug mode bypass capability

### 5. Code Obfuscation ✅

**Files Enhanced:**
- `android/app/proguard-rules.pro` - ProGuard rules
- `android/app/build.gradle.kts` - R8 full mode configuration
- `scripts/build_release_obfuscated.sh` - Build script

**Obfuscation Features:**
- R8 full mode enabled
- ProGuard rules for aggressive optimization
- Dart obfuscation support (--obfuscate flag)
- String encryption (adaptclassstrings)
- Resource file name obfuscation (adaptresourcefilenames)
- Stack trace line number removal (anti-debugging)

**Build Configuration:**
```gradle
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(...)
    }
}
```

**ProGuard Rules:**
- Flutter engine preservation
- Firebase/Play Services preservation
- Native method preservation
- Security class obfuscation
- Ad network SDK preservation
- Logging removal in release

### 6. TLS Certificate Pinning ✅

**Files Enhanced:**
- `lib/security/ssl_pinning.dart` - Existing SSL pinning implementation
- `lib/security/security_config.dart` - Pin configuration

**Pinning Features:**
- SPKI SHA-256 certificate pinning
- Primary + backup pin support
- Host-specific pinning
- Stream token API pinning
- Ad network pinning
- Automatic pin validation on all secure connections

**Configuration:**
```dart
static const String sslPinPrimary = String.fromEnvironment('SSL_PIN_PRIMARY');
static const String sslPinBackup = String.fromEnvironment('SSL_PIN_BACKUP');
```

**Supported Hosts:**
- Stream token API
- Supersonic
- Adsterra

### 7. Per-Install UUID Watermarking ✅

**Files Created:**
- `lib/security/install_watermark_service.dart` - Install watermarking service
- `android/app/src/main/kotlin/com/kakonzone/lumio/MainActivity.kt` - Encrypted storage

**Features:**
- Unique UUID per installation
- Encrypted storage (AndroidX Security)
- Device fingerprint generation
- Backend registration on first run
- API quota management per install
- Signature-based request authentication

**Backend Integration:**
- Install registration endpoint
- Quota checking endpoint
- Install ID header requirement for API calls
- Rate limiting per installation

### 8. Backend Verification Documentation ✅

**Files Created:**
- `docs/BACKEND_VERIFICATION.md` - Complete backend setup guide
- `scripts/build_release_obfuscated.sh` - Release build script

**Documentation Covers:**
- Play Integrity API setup
- APK signature allowlist
- Install watermarking system
- TLS certificate pinning extraction
- Combined security verification
- Security headers
- Monitoring and alerting
- Build configuration
- Testing procedures

## Security Architecture

### Layered Defense Strategy

```
┌─────────────────────────────────────────────────┐
│         Application Layer (Dart)                  │
│  - AntiCloneService                              │
│  - InstallWatermarkService                       │
│  - PlayIntegrityService                          │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│      Native Layer (Kotlin/JNI)                   │
│  - PlayIntegrityBridge                           │
│  - Encrypted SharedPreferences                    │
│  - Native Security Checks                        │
│  - Signature Verification                         │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│         Backend Verification                     │
│  - Integrity Token Validation                    │
│  - Signature Allowlist                           │
│  - Install Quota Management                       │
│  - API Rate Limiting                             │
└─────────────────────────────────────────────────┘
```

## Security Verification Flow

### App Startup
1. SecurityManager.initialize() - Root, emulator, debugger, Frida checks
2. AntiCloneService.initialize() - Play Integrity, signature, package name
3. InstallWatermarkService.initialize() - UUID generation and storage
4. Backend registration (production only)

### API Calls
1. Install watermark validation (X-Install-ID header)
2. Quota check
3. Play Integrity token validation (if required)
4. Certificate pin validation (TLS)

### Failure Modes
- **Root/Debuggable:** App exits (strict mode) or degraded functionality
- **Signature Mismatch:** App refuses to run
- **Package Name Mismatch:** App refuses to run
- **Integrity Failure:** API access denied
- **Quota Exceeded:** HTTP 429 rate limit
- **Certificate Pin Mismatch:** Connection refused

## Configuration Required

### Environment Variables / Dart-Defines

```bash
# Security
LUMIO_HMAC_SECRET="your-hmac-secret"
PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER="123456789"

# SSL Pinning
SSL_PIN_PRIMARY="base64sha256pin1"
SSL_PIN_BACKUP="base64sha256pin2"
SSL_PIN_STREAM_TOKEN_PRIMARY="base64sha256pin1"
SSL_PIN_STREAM_TOKEN_BACKUP="base64sha256pin2"

# Backend
INTEGRITY_VERIFICATION_ENDPOINT="https://api.example.com"
```

### Security Configuration

In `lib/security/security_config.dart`:
```dart
static const String expectedApkSignatureSha256 = 'YOUR_APK_SHA256';
static const String expectedPackageName = 'com.kakonzone.lumio';
static const int playIntegrityCloudProjectNumber = 123456789;
```

## Build Commands

### Development Build
```bash
flutter run --dart-define-from-file=secrets.json
```

### Release Build (Obfuscated)
```bash
./scripts/build_release_obfuscated.sh
```

Or manually:
```bash
flutter build apk \
  --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --split-per-abi \
  --dart-define=SSL_PIN_PRIMARY=$SSL_PIN_PRIMARY \
  --dart-define=SSL_PIN_BACKUP=$SSL_PIN_BACKUP
```

## Monitoring Recommendations

Monitor these metrics in your backend:
1. Failed integrity verifications (sudden spikes = attacks)
2. Unknown APK signatures (new clones)
3. Abnormal API usage patterns
4. Rate limit violations by install ID
5. Certificate pinning failures
6. Root detection bypass attempts

## Security Checklist

- [x] Play Integrity API integrated
- [x] APK signature verification implemented
- [x] Package name verification implemented
- [x] Root/jailbreak detection enhanced
- [x] Code obfuscation configured (R8 + ProGuard + Dart)
- [x] TLS certificate pinning active
- [x] Per-install watermarking implemented
- [x] Backend verification documented
- [x] Build script created
- [ ] Configure actual APK signature SHA-256
- [ ] Set Play Integrity cloud project number
- ] Configure backend verification endpoints
- [ ] Set up monitoring and alerting
- [ ] Test all security features in production

## Important Notes

### Development vs Production
- All security checks bypassed in debug mode
- Use `--dart-define=LUMIO_SIDELOAD_DEV=true` for local testing
- Strict mode enabled only in release builds

### False Positives
- Root detection has legitimate use cases (enterprise devices)
- Consider VPN users (currently disabled by default)
- Allow manual override if needed for specific use cases

### Maintenance
- Update APK signature when changing signing keys
- Rotate certificate pins before expiry
- Monitor Play Integrity API quota limits
- Keep debug symbols secure for crash reporting

## Troubleshooting

### Play Integrity API Issues
- Ensure cloud project number is correct
- Verify Play Integrity API is enabled in Google Cloud Console
- Check network connectivity for token requests

### Certificate Pinning Issues
- Extract pins using provided commands
- Configure primary + backup pins
- Test with valid certificates

### Build Issues
- Ensure signing credentials are configured
- Verify R8/ProGuard compatibility
- Check dart-define syntax

## Support

For security issues or questions, refer to:
- `docs/BACKEND_VERIFICATION.md` - Backend setup guide
- `docs/security/` - Additional security documentation
- AGENTS.md - Project-specific guidelines

## Security Team Contact

Security issues: security@lumio.app
Backend issues: backend@lumio.app
