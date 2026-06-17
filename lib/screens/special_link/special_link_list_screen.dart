import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model.dart';
import '../../provider/app_provider.dart';
import '../../services/special_link/gitun_playlist_service.dart';
import '../../utils/priority_broadcasters.dart';
import '../../services/special_link/special_link_cache.dart';
import '../../utils/channel_player.dart';
import '../../ads/ad_manager.dart';
import '../../ads/widgets/lazy_adsterra_strip.dart';
import '../../widgets/ad_list_injector.dart';
import '../../widgets/channel_list_tile.dart';
import '../../widgets/list_skeletons.dart';
import '../../widgets/shell_app_bar.dart';
import '../../widgets/shell_page_scaffold.dart';

/// GITUN sports channels only — no hub copy, no subtitles.
class SpecialLinkListScreen extends StatefulWidget {
  const SpecialLinkListScreen({super.key});

  const SpecialLinkListScreen.gitun({super.key});

  @override
  State<SpecialLinkListScreen> createState() => _SpecialLinkListScreenState();
}

class _SpecialLinkListScreenState extends State<SpecialLinkListScreen> {
  bool _loading = true;
  List<ChannelModel> _channels = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);

    try {
      if (!forceRefresh) {
        final cached = await SpecialLinkCache.instance.readGitunChannels();
        if (cached != null && cached.isNotEmpty && mounted) {
          final sorted = PriorityBroadcasters.sort(cached);
          context.read<AppProvider>().setGitunChannels(sorted);
          setState(() {
            _channels = sorted;
            _loading = false;
          });
        }
      }

      final list = await GitunPlaylistService.instance.loadGitunChannels(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final sorted = PriorityBroadcasters.sort(list);
      context.read<AppProvider>().setGitunChannels(sorted);
      setState(() {
        _channels = sorted;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final countLabel =
        _channels.isEmpty ? 'GITUN playlists' : '${_channels.length} channels';

    return ShellPageScaffold(
      onRefresh: () => _load(forceRefresh: true),
      appBar: ShellAppBar(
        showBack: true,
        blendWithScaffold: true,
        title: 'Special Link',
        subtitle: countLabel,
      ),
      slivers: [
        if (AdManager.instance.showAdsterraWebViewSlots)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: LazyAdsterraBanner728(placement: 'special_link_top'),
            ),
          ),
        if (_loading)
          const SliverToBoxAdapter(child: ChannelListSkeleton())
        else if (_channels.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          )
        else
          AdListInjector.buildSeparatedChannelSliver(
            itemCount: _channels.length,
            screen: AdListScreen.defaultList,
            placementPrefix: 'special_link_list',
            itemBuilder: (ctx, i) {
              final ch = _channels[i];
              return ChannelListTile(
                channel: ch,
                onTap: () => openChannelPlayer(
                  context,
                  channel: ch,
                  browseCategory: 'GITUN',
                ),
              );
            },
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}
