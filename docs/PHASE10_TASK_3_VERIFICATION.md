# Phase 10 — Task 3 verification (legal)

## Grep

```bash
grep -rE 'lumio\.app/(privacy|terms|data-deletion)' lib/
```

## Manual

1. Drawer → **Ads & privacy**
2. Tap Privacy, Terms, Contact, Data deletion — each opens browser or mail app
3. Cold install → consent dialog → tap inline Privacy / Terms links

## Analyze

```bash
flutter analyze lib/config/legal_config.dart lib/screens/ads_privacy_screen.dart lib/widgets/ad_consent_dialog.dart
```
