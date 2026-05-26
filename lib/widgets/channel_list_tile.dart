import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';
import 'channel_avatar.dart';

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
    final prov = context.watch<AppProvider>();
    final showLive = prov.isStreamLive(channel);
    final checking = prov.isStreamHealthPending(channel);
    final isPendingTap = prov.isPendingChannelTapChannel(channel);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isPendingTap ? AppColors.accentDim : context.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPendingTap ? AppColors.accent : context.brd,
            width: isPendingTap ? 2 : 1,
          ),
        ),
        child: Row(children: [
          ChannelAvatar(channel: channel),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPendingTap ? AppColors.accent : context.txt,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  channel.currentShow.isEmpty
                      ? channel.category
                      : channel.currentShow,
                  style: TextStyle(fontSize: 11, color: context.txt3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (checking)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            )
          else if (showLive)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '● LIVE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}
