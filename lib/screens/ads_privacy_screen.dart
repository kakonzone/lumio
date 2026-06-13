import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ad_manager.dart';
import '../config/ad_config.dart';
import '../config/legal_config.dart';
import '../services/ad_consent_service.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart';

/// Change personalized vs limited ads (drawer → Ads & privacy).
class AdsPrivacyScreen extends StatefulWidget {
  const AdsPrivacyScreen({super.key});

  @override
  State<AdsPrivacyScreen> createState() => _AdsPrivacyScreenState();
}

class _AdsPrivacyScreenState extends State<AdsPrivacyScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AdConsentService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg2,
        foregroundColor: context.txt,
        title: const Text('Ads & privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (AdConfig.hasUnityConfig && AdManager.instance.adsEnabled) ...[
            const SizedBox(height: 28),
            Text(
              'Ad-free time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.txt,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Watch one short video to hide banner and list ads for '
              '${AdConfig.adFreeMinutesAfterRewarded} minutes.',
              style: TextStyle(fontSize: 14, color: context.txt2, height: 1.4),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      final earned =
                          await AdManager.instance.showRewardedForAdFree(
                        trigger: 'privacy_rewarded_ad_free',
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            earned
                                ? 'Ad-free for ${AdConfig.adFreeMinutesAfterRewarded} minutes'
                                : 'Video not completed — try again later',
                          ),
                        ),
                      );
                      setState(() => _loading = false);
                    },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Watch ad for ad-free time'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Legal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.txt,
            ),
          ),
          const SizedBox(height: 8),
          _legalTile(
            context,
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            url: LegalConfig.privacyPolicyUrl,
          ),
          _legalTile(
            context,
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            url: LegalConfig.termsOfServiceUrl,
          ),
          _legalTile(
            context,
            icon: Icons.mail_outline,
            title: 'Contact support',
            url: 'mailto:${LegalConfig.contactEmail}',
          ),
          _legalTile(
            context,
            icon: Icons.delete_outline,
            title: 'Data deletion request',
            url: LegalConfig.dataDeletionUrl,
          ),
        ],
      ),
    );
  }
}

Widget _legalTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String url,
}) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppTokens.accent),
    title: Text(title, style: TextStyle(color: context.txt)),
    subtitle: Text(
      url,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: context.txt3),
    ),
    onTap: () async {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    },
  );
}
