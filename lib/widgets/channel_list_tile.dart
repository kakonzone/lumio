import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/model.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';
import '../theme/channel_list_style.dart';
import '../theme/tokens/colors.dart' as tokens;
import 'channel_avatar.dart';

/// Channel row — solid surface card, LIVE pill, category chip (no gradients).
class ChannelListTile extends StatelessWidget {
  final ChannelModel channel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const ChannelListTile({
    super.key,
    required this.channel,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({bool showLive, bool checking, bool isPendingTap})>(
      selector: (_, p) => (
        showLive: p.isStreamLive(channel),
        checking: p.isStreamHealthPending(channel),
        isPendingTap: p.isPendingChannelTapChannel(channel),
      ),
      builder: (context, state, _) {
        final showLive = state.showLive;
        final checking = state.checking;
        final isPendingTap = state.isPendingTap;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap?.call();
            },
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: ChannelListStyle.card(
                context: context,
                showLive: showLive,
                isPendingTap: isPendingTap,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    if (showLive)
                      Container(
                        width: 3,
                        height: 44,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: tokens.AppTokens.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ChannelAvatar(channel: channel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color:
                                  isPendingTap ? tokens.AppTokens.accent : context.txt,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: ChannelListStyle.categoryChip(
                                  context,
                                  channel.category,
                                ),
                                child: Text(
                                  channel.categoryIcon,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  channel.hasMultipleUserStreams
                                      ? '${channel.userStreamLinks.length} links · tap to play'
                                      : channel.currentShow.isEmpty
                                          ? channel.category
                                          : channel.currentShow,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.txt3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (checking)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: tokens.AppTokens.accent,
                          ),
                        ),
                      )
                    else if (showLive)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: ChannelListStyle.liveBadge(),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
