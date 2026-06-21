import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/favorites_provider.dart';
import '../provider/channel_catalog_provider.dart';
import '../utils/channel_player.dart';
import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_banner.dart';
import '../config/ad_config.dart';
import '../widgets/shell_app_bar.dart';
import '../widgets/shell_page_scaffold.dart';
import '../widgets/ad_list_injector.dart';
import '../widgets/channel_list_tile.dart';
import '../widgets/empty_states/empty_state.dart';
import '../ads/adsterra/adsterra_native.dart';
import '../ads/utils/lazy_ad_viewport.dart';
import '../theme/tokens/colors.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favProv = context.read<FavoritesProvider>();
    final catalogProv = context.read<ChannelCatalogProvider>();
    final favorites = favProv.getFavoriteChannels(catalogProv.channels);

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
            child: EmptyState.favorites(),
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
            // Inject native ad at index 3
            if (i == 3 && AdManager.instance.showAdsterraWebViewSlots) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: LazyAdViewport(
                  placeholderHeight: 100,
                  builder: () => AdsterraNativeBanner(
                    placement: 'favorites_list_0',
                    height: 100,
                    userVisible: AdConfig.playerAdsUserVisible,
                  ),
                ),
              );
            }

            final ch = favorites[i];
            return ChannelListTile(
              channel: ch,
              onTap: () => openChannelPlayer(
                context,
                channel: ch,
              ),
              onLongPress: () async {
                await favProv.removeFavorite(ch.id);
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
                  color: AppTokens.accent,
                  size: 20,
                ),
                onPressed: () => favProv.removeFavorite(ch.id),
              ),
            );
          },
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}
