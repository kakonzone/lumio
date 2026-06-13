import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal_config.dart';
import '../services/ad_consent_service.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart' as tokens;

/// Minimal first-launch consent (not a full CMP).
class AdConsentDialog {
  AdConsentDialog._();

  static Future<void> showIfNeeded(BuildContext context) async {
    await AdConsentService.instance.load();
    if (!AdConsentService.instance.needsConsentPrompt) return;
    if (!context.mounted) return;

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Semantics(
        label: 'Ads and privacy consent',
        child: AlertDialog(
          title: const Text('Ads & privacy'),
          content: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 14, height: 1.45, color: context.txt2),
              children: [
                const TextSpan(
                  text:
                      'Lumio is free with ads. You can accept personalized ads '
                      'or continue with limited, non-personalized ads only.\n\n'
                      'See our ',
                ),
                _linkSpan(ctx, 'Privacy Policy', LegalConfig.privacyPolicyUrl),
                const TextSpan(text: ' and '),
                _linkSpan(
                    ctx, 'Terms of Service', LegalConfig.termsOfServiceUrl),
                const TextSpan(
                  text:
                      '.\n\nChange your choice anytime from the menu → Ads & privacy.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Limited ads only'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.AppTokens.accent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );

    await AdConsentService.instance.setConsent(granted: granted == true);
  }

  static TextSpan _linkSpan(BuildContext context, String label, String url) {
    return TextSpan(
      text: label,
      style: const TextStyle(
        color: tokens.AppTokens.accent,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
    );
  }
}
