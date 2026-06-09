import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/model.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart' as tokens;
import '../widgets/channel_avatar.dart';

/// Category emoji for player related list rows.
String categoryEmoji(String cat) {
  switch (cat.toLowerCase()) {
    case 'sports':
      return '🏆';
    case 'bangladesh':
      return '🇧🇩';
    case 'pakistan':
      return '🇵🇰';
    case 'hindi':
      return '🇮🇳';
    case 'english':
      return '🇬🇧';
    case 'movies':
      return '🎬';
    case 'kids':
      return '🧒';
    case 'kdrama':
      return '🇰🇷';
    default:
      return '📺';
  }
}

class PlayerRelatedCard extends StatelessWidget {
  const PlayerRelatedCard({
    super.key,
    required this.channel,
    required this.isPlaying,
    required this.onTap,
  });

  final ChannelModel channel;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showLive = context.select<AppProvider, bool>(
      (p) => p.isStreamLive(channel),
    );
    final checking = context.select<AppProvider, bool>(
      (p) => p.isStreamHealthPending(channel),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isPlaying
                ? tokens.AppTokens.accent.withValues(alpha: 0.08)
                : const Color(0xFF131318),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPlaying
                  ? tokens.AppTokens.accent.withValues(alpha: 0.55)
                  : const Color(0xFF22222E),
              width: isPlaying ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            ChannelAvatar(channel: channel, size: 44, borderRadius: 10),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: GF.body(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    channel.currentShow.isEmpty
                        ? channel.category
                        : channel.currentShow,
                    style: GF.body(
                      color: context.txt3,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isPlaying)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.AppTokens.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PLAYING',
                  style: GF.head(
                    color: tokens.AppTokens.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else if (checking)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.AppTokens.accent,
                ),
              )
            else if (showLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.AppTokens.accentMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PlayerLiveDot(),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: GF.head(
                        color: tokens.AppTokens.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.AppTokens.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tokens.AppTokens.accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class PlayerSpinner extends StatelessWidget {
  const PlayerSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 42,
        height: 42,
        child: CircularProgressIndicator(
          color: tokens.AppTokens.accent,
          strokeWidth: 3,
        ),
      );
}

class PlayerTransportBtn extends StatelessWidget {
  const PlayerTransportBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
  });

  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (label != null) {
      child = TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(48, 40),
        ),
        child: Text(
          label!,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      );
    } else {
      child = IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 26),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      );
    }
    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

class PlayerConnectingDots extends StatefulWidget {
  const PlayerConnectingDots({super.key});

  @override
  State<PlayerConnectingDots> createState() => _PlayerConnectingDotsState();
}

class _PlayerConnectingDotsState extends State<PlayerConnectingDots> {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: tokens.AppTokens.accent.withValues(
                    alpha: 0.35 + (i * 0.2),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }
}

class PlayerLiveDot extends StatefulWidget {
  const PlayerLiveDot({super.key});

  @override
  State<PlayerLiveDot> createState() => _PlayerLiveDotState();
}

class _PlayerLiveDotState extends State<PlayerLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.2).animate(_ctrl),
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: tokens.AppTokens.accent,
            shape: BoxShape.circle,
          ),
        ),
      );
}

class PlayerErrorPanel extends StatelessWidget {
  const PlayerErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Color(0xFF555555), size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.AppTokens.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ]);
}
