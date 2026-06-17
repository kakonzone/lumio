# Backend Verification for Anti-Clone Protection

This document explains how to set up backend verification for the Lumio app's anti-clone protection system.

## Overview

The app implements multiple security layers that require backend verification:

1. **Play Integrity API Token Verification** - Validates device and app integrity
2. **APK Signature Fingerprint Allowlist** - Verifies app authenticity
3. **Install Watermarking** - Tracks per-install API quota
4. **Certificate Pinning** - Ensures secure TLS connections

## 1. Play Integrity API Token Verification

### Google Cloud Console Setup

1. Enable Play Integrity API in Google Cloud Console
2. Note your cloud project number (used in app configuration)
3. Configure the API key restrictions

### Backend Verification Endpoint

```
POST /api/v1/verify-integrity
Content-Type: application/json

{
  "integrityToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Backend Verification Logic

```javascript
const { PlayIntegrity } = require('@google-cloud/play-integrity');
const client = new PlayIntegrity();

async function verifyIntegrityToken(token) {
  try {
    const response = await client.decodeIntegrityToken(token);
    const verdict = response.tokenPayload;

    // Check required integrity verdicts
    const meetsRequirements = 
      verdict.deviceIntegrity === 'MEETS_DEVICE_INTEGRITY' &&
      verdict.appIntegrity === 'MEETS_BASIC_INTEGRITY' &&
      verdict.accountDetails === 'PLAY_RECOGNIZED';

    if (!meetsRequirements) {
      return {
        valid: false,
        reason: 'Integrity verdict does not meet requirements',
        deviceIntegrity: verdict.deviceIntegrity,
        appIntegrity: verdict.appIntegrity,
        accountDetails: verdict.accountDetails
      };
    }

    return {
      valid: true,
      deviceIntegrity: verdict.deviceIntegrity,
      appIntegrity: verdict.appIntegrity,
      accountDetails: verdict.accountDetails
    };
  } catch (error) {
    return {
      valid: false,
      error: error.message
    };
  }
}
```

### Required Verdicts

- **MEETS_DEVICE_INTEGRITY** - Device passes basic integrity checks (not rooted, not emulator)
- **MEETS_BASIC_INTEGRITY** - App is installed by Play Store and signed by correct key
- **PLAY_RECOGNIZED** - Google Play account is associated with device

## 2. APK Signature Fingerprint Allowlist

### Extract APK Signature

```bash
# Get SHA-256 fingerprint of release APK
keytool -list -v -keystore your-release.jks -alias your_alias
```

### Backend Allowlist Configuration

```javascript
const ALLOWED_APK_SIGNATURES = [
  'A1:B2:C3:D4:E5:F6:7:8:9:A:B:C:D:E:F...', // Production release
  'B1:C2:D3:E4:F5:A6:B7:C8:D9:E:F:A:B:C:D:E:F...', // Beta release
];

function verifyApkSignature(signature) {
  if (!ALLOWED_APK_SIGNATURES.includes(signature)) {
    return {
      valid: false,
      reason: 'Unrecognized APK signature'
    };
  }
  return { valid: true };
}
```

### Backend Signature Verification Endpoint

```
POST /api/v1/verify-signature
Content-Type: application/json

{
  "apkSignature": "A1:B2:C3:D4:E5:F6:7:8:9:A:B:C:D:E:F...",
  "packageName": "com.kakonzone.lumio"
}
```

## 3. Install Watermarking System

### Registration Endpoint

```
POST /api/v1/register-install
Content-Type: application/json

{
  "installId": "550e8400-e29b-41d4-a716-446655440000",
  "deviceFingerprint": "a1b2c3d4e5f6...",
  "appVersion": "1.1.0",
  "timestamp": "2024-06-16T10:30:00Z",
  "signature": "sha256hash"
}
```

### Backend Registration Logic

```javascript
const installDatabase = new Map();

function registerInstall(installData) {
  const { installId, deviceFingerprint, signature } = installData;

  // Verify signature
  if (!verifySignature(installData)) {
    return { success: false, reason: 'Invalid signature' };
  }

  // Check for duplicate registrations
  if (installDatabase.has(installId)) {
    // Update existing
    const existing = installDatabase.get(installId);
    existing.lastSeen = Date.now();
    return { success: true, isNew: false };
  }

  // Create new registration
  installDatabase.set(installId, {
    deviceFingerprint,
    createdAt: Date.now(),
    lastSeen: Date.now(),
    apiQuota: 10000,
    quotaReset: Date.now() + 24 * 60 * 60 * 1000 // 24 hours
  });

  return { success: true, isNew: true };
}
```

### Quota Management

```javascript
function checkApiQuota(installId) {
  const install = installDatabase.get(installId);
  
  if (!install) {
    return { allowed: false, reason: 'Unknown installation' };
  }

  // Reset quota if period elapsed
  if (Date.now() > install.quotaReset) {
    install.apiQuota = 10000;
    install.quotaReset = Date.now() + 24 * 60 * 60 * 1000;
  }

  if (install.apiQuota <= 0) {
    return {
      allowed: false,
      reason: 'Quota exceeded',
      resetTime: new Date(install.quotaReset).toISOString()
    };
  }

  return {
    allowed: true,
    remaining: install.apiQuota,
    resetTime: new Date(install.quotaReset).toISOString()
  };
}

function consumeApiQuota(installId) {
  const install = installDatabase.get(installId);
  if (install && install.apiQuota > 0) {
    install.apiQuota--;
    install.lastSeen = Date.now();
  }
}
```

### API Middleware

```javascript
function requireValidInstall(req, res, next) {
  const installId = req.headers['x-install-id'];
  
  if (!installId) {
    return res.status(401).json({ error: 'Missing install ID' });
  }

  const quota = checkApiQuota(installId);
  
  if (!quota.allowed) {
    return res.status(429).json({
      error: 'Rate limit exceeded',
      resetTime: quota.resetTime
    });
  }

  // Attach install info to request
  req.installId = installId;
  req.installInfo = installDatabase.get(installId);
  
  consumeApiQuota(installId);
  next();
}

// Apply to protected routes
app.use('/api/v1/protected/*', requireValidInstall);
```

## 4. Certificate Pinning Configuration

### Extract Certificate Pins

```bash
# Extract SHA-256 pin for a domain
openssl s_client -connect api.example.com:443 -showcerts | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64
```

### Environment Configuration

Set the following environment variables or dart-define values:

```bash
# Stream token API pins
SSL_PIN_STREAM_TOKEN_PRIMARY="base64sha256pin1"
SSL_PIN_STREAM_TOKEN_BACKUP="base64sha256pin2"

# Backend API pins
SSL_PIN_PRIMARY="base64sha256pin1"
SSL_PIN_BACKUP="base64sha256pin2"

# Ad network pins
SSL_PIN_ADSTERRA_PRIMARY="base64sha256pin1"
SSL_PIN_ADSTERRA_BACKUP="base64sha256pin2"
```

## 5. Combined Security Verification

### Comprehensive Security Check Endpoint

```
POST /api/v1/comprehensive-security-check
Content-Type: application/json

{
  "integrityToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "apkSignature": "A1:B2:C3:D4:E5:F6:7:8:9:A:B:C:D:E:F...",
  "packageName": "com.kakonzone.lumio",
  "installId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Backend Combined Verification

```javascript
async function comprehensiveSecurityCheck(data) {
  const results = {
    integrity: await verifyIntegrityToken(data.integrityToken),
    signature: verifyApkSignature(data.apkSignature),
    package: verifyPackageName(data.packageName),
    install: verifyInstallId(data.installId)
  };

  const allValid = Object.values(results).every(r => r.valid !== false);

  if (!allValid) {
    return {
      valid: false,
      checks: results
    };
  }

  return {
    valid: true,
    checks: results
  };
}
```

## 6. Security Headers

Add these headers to all API responses:

```http
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'
```

## 7. Monitoring and Alerting

Set up monitoring for:

- Failed integrity verifications (spikes may indicate attacks)
- Unknown APK signatures (new cloned versions)
- Abnormal API usage patterns
- Rate limit violations
- Certificate pinning failures

## 8. Build Configuration

### Flutter Release Build

```bash
flutter build apk \
  --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --split-per-abi
```

### Gradle Release Build

```bash
cd android
./gradlew assembleRelease
```

This will apply:
- R8 full mode optimization
- ProGuard obfuscation
- Code shrinking
- Resource shrinking

## 9. Security Checklist

- [ ] Play Integrity API enabled in Google Cloud Console
- [ ] Cloud project number configured in app
- [ ] APK signature allowlist configured in backend
- [ ] Install watermarking endpoints implemented
- [ ] TLS certificate pins extracted and configured
- [ ] Security headers configured on backend
- [ ] Monitoring and alerting set up
- [ ] Rate limiting implemented
- [ ] Quota management configured
- [ ] Obfuscation enabled in release builds

## 10. Testing

### Test Play Integrity Verification

```bash
# Test with known good token
curl -X POST https://api.example.com/api/v1/verify-integrity \
  -H "Content-Type: application/json" \
  -d '{"integrityToken": "known_good_token"}'
```

### Test APK Signature Verification

```bash
# Get current APK signature
adb shell dumpsys package com.kakonzone.lumio | grep signatures

# Test against backend
curl -X POST https://api.example.com/api/v1/verify-signature \
  -H "Content-Type: application/json" \
  -d '{"apkSignature": "current_signature", "packageName": "com.kakonzone.lumio"}'
```

### Test Certificate Pinning

```bash
# Test with valid certificate
curl https://api.example.com/api/v1/endpoint

# Test with invalid certificate (should fail)
curl --insecure https://api.example.com/api/v1/endpoint
```

## Support

For security issues or questions, contact the security team at security@lumio.app
