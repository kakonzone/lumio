import 'package:flutter/material.dart';

import '../services/ad_consent_service.dart';
import '../theme/app_theme.dart';

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
      builder: (ctx) => AlertDialog(
        title: const Text('Ads & privacy'),
        content: const Text(
          'Lumio is free with ads. You can accept personalized ads '
          'or continue with limited, non-personalized ads only.\n\n'
          'Change your choice anytime from the menu → Ads & privacy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Limited ads only'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    await AdConsentService.instance.setConsent(granted: granted == true);
  }
}
