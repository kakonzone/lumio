import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ad_manager.dart';
import '../config/ad_config.dart';
import '../config/legal_config.dart';
import '../services/ad_consent_service.dart';
import '../theme/app_theme.dart';

/// Change personalized vs limited ads (drawer → Ads & privacy).
class AdsPrivacyScreen extends StatefulWidget {
  const AdsPrivacyScreen({super.key});

  @override
  State<AdsPrivacyScreen> createState() => _AdsPrivacyScreenState();
}

class _AdsPrivacyScreenState extends State<AdsPrivacyScreen> {
  bool _loading = true;
  bool? _personalized;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AdConsentService.instance.load();
    if (!mounted) return;
    setState(() {
      _personalized = AdConsentService.instance.hasGrantedConsent
          ? true
          : AdConsentService.instance.hasDeniedConsent
              ? false
              : null;
      _loading = false;
    });
  }

  Future<void> _apply(bool personalized) async {
    setState(() => _loading = true);
    await AdConsentService.instance.setConsent(granted: personalized);
    if (!mounted) return;
    setState(() {
      _personalized = personalized;
      _loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          personalized
              ? 'Personalized ads enabled'
              : 'Limited ads only — opted out of sale where applicable',
        ),
      ),
    );
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Ad choices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.txt,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lumio is free with ads. Your choice controls LevelPlay '
                  'GDPR/CCPA flags for this device. It does not remove ads.',
                  style: TextStyle(fontSize: 14, color: context.txt2, height: 1.4),
                ),
                const SizedBox(height: 24),
                _ChoiceTile(
                  title: 'Personalized ads',
                  subtitle: 'Allow ad partners to use data for relevance',
                  selected: _personalized == true,
                  onTap: () => _apply(true),
                ),
                const SizedBox(height: 12),
                _ChoiceTile(
                  title: 'Limited ads only',
                  subtitle: 'Non-personalized ads; opt out of sale (CCPA)',
                  selected: _personalized == false,
                  onTap: () => _apply(false),
                ),
                if (_personalized == null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'You have not chosen yet — pick an option above.',
                    style: TextStyle(fontSize: 13, color: context.txt3),
                  ),
                ],
                if (AdConfig.hasLevelPlayRewardedUnit &&
                    AdManager.instance.adsEnabled) ...[
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
                            setState(() => _loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  earned
                                      ? 'Ad-free for ${AdConfig.adFreeMinutesAfterRewarded} minutes'
                                      : 'Video not completed — try again later',
                                ),
                              ),
                            );
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
    leading: Icon(icon, color: AppColors.accent),
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

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.bg2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.accent : context.txt3,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.txt,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: context.txt3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
