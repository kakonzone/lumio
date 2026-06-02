import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/special_link_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shell_app_bar.dart';
import 'special_link_list_screen.dart';

/// Home → Special Link → GITUN (third-party GitHub sports playlists).
class SpecialLinkHubScreen extends StatelessWidget {
  const SpecialLinkHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShellAppBar(
            showBack: true,
            title: SpecialLinkConfig.hubTitle,
            subtitle: 'Third-party sports playlists only',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Home, Sports, Live and all categories use only your GitHub playlist '
                  '(allchannelking.m3u8). Update that repo anytime — pull to refresh in the app.',
                  style: GF.body(fontSize: 12, color: context.txt3, height: 1.35),
                ),
                const SizedBox(height: 12),
                Text(
                  'GITUN: third-party GitHub playlists — sports channels only. '
                  'Your allchannelking repo is not mixed in.',
                  style: GF.body(fontSize: 12, color: context.txt3, height: 1.35),
                ),
                const SizedBox(height: 16),
                _SourceCard(
                  title: SpecialLinkConfig.gitunTitle,
                  subtitle: 'Sports channels · third-party GitHub',
                  emoji: '📡',
                  gradient: const [
                    Color(0xFF0D47A1),
                    Color(0xFF1565C0),
                    Color(0xFF00838F),
                  ],
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const SpecialLinkListScreen.gitun(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _SourceCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GF.head(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GF.body(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
