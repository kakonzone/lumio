import 'package:flutter/material.dart';

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
              ],
            ),
    );
  }
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
