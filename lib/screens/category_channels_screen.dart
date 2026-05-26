import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/channel_player.dart';
import '../widgets/add_favorite_dialog.dart';
import '../widgets/shell_app_bar.dart';
import '../ads/ad_placement_config.dart';
import '../widgets/ad_list_injector.dart';
import '../widgets/channel_list_tile.dart';

/// Channel list for a category (Sports, Bangla, Movies, …).
class CategoryChannelsScreen extends StatefulWidget {
  final String categoryName;
  final String categoryIcon;

  const CategoryChannelsScreen({
    super.key,
    required this.categoryName,
    this.categoryIcon = '📺',
  });

  @override
  State<CategoryChannelsScreen> createState() => _CategoryChannelsScreenState();
}

int _hubAwareSort(ChannelModel a, ChannelModel b) {
  final ha = a.hubGroupId;
  final hb = b.hubGroupId;
  if (ha != null && ha == hb) {
    if (a.isHubParent != b.isHubParent) {
      return a.isHubParent ? -1 : 1;
    }
    return a.name.compareTo(b.name);
  }
  if (a.isHubParent != b.isHubParent) {
    return a.isHubParent ? -1 : 1;
  }
  return a.name.compareTo(b.name);
}

class _CategoryChannelsScreenState extends State<CategoryChannelsScreen> {
  List<ChannelModel> _channelsFor(AppProvider prov) {
    final list = prov
        .byCategory(widget.categoryName)
        .where((c) => c.streamUrl.isNotEmpty)
        .toList();
    list.sort(_hubAwareSort);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final channels = prov
        .byCategory(widget.categoryName)
        .where((c) => c.streamUrl.isNotEmpty)
        .toList()
      ..sort(_hubAwareSort);

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShellAppBar(
            showBack: true,
            title: widget.categoryName,
            subtitle: channels.isEmpty
                ? 'No live channels'
                : '${channels.length} channels • Hold to add favourite',
          ),
          Expanded(
            child: channels.isEmpty
                ? Center(
                    child: Text(
                      'No channels in ${widget.categoryName}',
                      style: TextStyle(color: context.txt3),
                    ),
                  )
                : AdListInjector.buildSeparatedChannelList(
                    itemCount: channels.length,
                    interval: AdPlacementConfig.channelListNativeInterval,
                    placementPrefix: 'category_list',
                    itemBuilder: (ctx, i) {
                      final ch = channels[i];
                      return ChannelListTile(
                        channel: ch,
                        onTap: () => openChannelPlayer(
                          context,
                          channel: ch,
                          browseCategory: widget.categoryName,
                        ),
                        onLongPress: () => showAddFavoriteDialog(context, ch),
                        trailing: prov.isFavorite(ch.id)
                            ? const Icon(
                                Icons.favorite,
                                color: AppColors.accent,
                                size: 18,
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
