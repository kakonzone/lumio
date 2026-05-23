import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/channel_player.dart';
import '../widgets/shell_app_bar.dart';
import '../widgets/channel_list_tile.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final favorites = prov.favoriteChannels;

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShellAppBar(
            showBack: true,
            title: 'Favourites',
            subtitle: favorites.isEmpty
                ? 'Long-press a channel to add'
                : '${favorites.length} saved channel${favorites.length == 1 ? '' : 's'}',
          ),
          Expanded(
            child: favorites.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
          ),
        ],
      ),
    );
  }
}
