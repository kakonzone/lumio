import 'package:flutter/material.dart';

import '../../config/special_link_config.dart';
import '../../models/model.dart';
import '../../services/special_link/gitun_playlist_service.dart';
import '../../utils/priority_broadcasters.dart';
import '../../services/special_link/special_link_cache.dart';
import '../../theme/app_theme.dart';
import '../../utils/channel_player.dart';
import '../../widgets/channel_list_tile.dart';
import '../../widgets/list_skeletons.dart';
import '../../widgets/shell_app_bar.dart';

/// Channel list from GITUN third-party GitHub playlists (not the main app catalog).
class SpecialLinkListScreen extends StatefulWidget {
  const SpecialLinkListScreen({super.key});

  const SpecialLinkListScreen.gitun({super.key});

  @override
  State<SpecialLinkListScreen> createState() => _SpecialLinkListScreenState();
}

class _SpecialLinkListScreenState extends State<SpecialLinkListScreen> {
  bool _loading = true;
  String? _error;
  List<ChannelModel> _channels = const [];
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!forceRefresh) {
        final cached = await SpecialLinkCache.instance.readGitunChannels();
        if (cached != null && cached.isNotEmpty && mounted) {
          setState(() {
            _channels = cached;
            _fromCache = true;
            _loading = false;
          });
        }
      }

      final list = await GitunPlaylistService.instance.loadGitunChannels(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _channels = PriorityBroadcasters.sort(list);
        _loading = false;
        if (forceRefresh) _fromCache = false;
        if (list.isEmpty) {
          _error =
              'No GITUN channels loaded. Pull to refresh — check internet and third-party GitHub playlists.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load playlist: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellAppBar(
            showBack: true,
            title: SpecialLinkConfig.gitunTitle,
            subtitle: _fromCache
                ? '${_channels.length} cached channels'
                : '${_channels.length} channels',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: AppColors.liveRed, fontSize: 12),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => _load(forceRefresh: true),
              child: _loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [ChannelListSkeleton()],
                    )
                  : _channels.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.35,
                              child: Center(
                                child: Text(
                                  'No channels',
                                  style: TextStyle(color: context.txt3),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _channels.length,
                          itemBuilder: (ctx, i) {
                            final ch = _channels[i];
                            return ChannelListTile(
                              channel: ch,
                              onTap: () => openChannelPlayer(
                                context,
                                channel: ch,
                                browseCategory: SpecialLinkConfig.gitunTitle,
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
