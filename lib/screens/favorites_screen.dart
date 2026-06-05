import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/channel_player.dart';
import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_banner.dart';
import '../config/ad_config.dart';
import '../widgets/shell_app_bar.dart';
import '../widgets/shell_page_scaffold.dart';
import '../widgets/ad_list_injector.dart';
import '../widgets/channel_list_tile.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final favorites = prov.favoriteChannels;

    if (favorites.isEmpty) {
      return ShellPageScaffold(
        appBar: ShellAppBar(
          showBack: true,
          blendWithScaffold: true,
          hideSubtitleInBar: true,
          title: 'Favourites',
          subtitle: 'Long-press a channel to add',
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 56,
                    color: context.txt3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favourites yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.txt,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Categories → Sports or Bangla → hold a channel → Add',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.txt3,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ShellPageScaffold(
      appBar: ShellAppBar(
        showBack: true,
        blendWithScaffold: true,
        hideSubtitleInBar: true,
        title: 'Favourites',
        subtitle:
            '${favorites.length} saved channel${favorites.length == 1 ? '' : 's'}',
      ),
      slivers: [
        if (AdManager.instance.showAdsterraWebViewSlots)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AdsterraBanner728(placement: 'favorites_top'),
            ),
          ),
        AdListInjector.buildSeparatedChannelSliver(
          itemCount: favorites.length,
          screen: AdListScreen.favorites,
          placementPrefix: 'favorites_list',
          itemBuilder: (ctx, i) {
            final ch = favorites[i];
            return ChannelListTile(
              channel: ch,
              onTap: () => openChannelPlayer(
                context,
                channel: ch,
              ),
              onLongPress: () async {
                await prov.removeFavorite(ch.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${ch.name} removed'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              trailing: IconButton(
                icon: const Icon(
                  Icons.favorite,
                  color: AppColors.accent,
                  size: 20,
                ),
                onPressed: () => prov.removeFavorite(ch.id),
              ),
            );
          },
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}
