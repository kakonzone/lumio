// lib/widgets/live/channel_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Channel list widget for center panel in Live TV screen
///
/// Features:
/// - 320px wide
/// - Search/filter input at top
/// - Filter chips: All | Live | Favorites | Recently Watched
/// - Channel rows: 64px height
///   - Logo (48x48, Surface3 fallback)
///   - Channel name (label size)
///   - Current program (caption, TextSecondary)
///   - Mini progress bar showing program progress
/// - Active channel: Surface2 background
/// - Long press: favorite toggle with haptic
class ChannelList extends StatefulWidget {
  final List<ChannelItem> channels;
  final String selectedChannelId;
  final Function(String) onChannelTap;
  final Function(String) onFavoriteToggle;
  final Function(String) onSearchChanged;

  const ChannelList({
    super.key,
    required this.channels,
    required this.selectedChannelId,
    required this.onChannelTap,
    required this.onFavoriteToggle,
    required this.onSearchChanged,
  });

  @override
  State<ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<ChannelList> {
  String _selectedFilter = Strings.epgFilterAll;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleFilterChange(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    HapticFeedback.selectionClick();
  }

  void _handleSearchChanged(String query) {
    widget.onSearchChanged(query);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: tokens.AppTokens.background,
        border: Border(
          right: BorderSide(
            color: tokens.AppTokens.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search input
          Padding(
            padding: EdgeInsets.all(tokens.SpacingTokens.s16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: tokens.AppTokens.surface2,
                borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
              ),
              child: TextField(
                controller: _searchController,
                style: tokens.TypographyTokens.bodyPrimary,
                decoration: InputDecoration(
                  hintText: Strings.channelSearchPlaceholder,
                  hintStyle: tokens.TypographyTokens.bodySecondary,
                  prefixIcon: Icon(
                    PhosphorIcons.magnifyingGlass(),
                    size: 20,
                    color: tokens.AppTokens.textSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: tokens.SpacingTokens.s12,
                  ),
                ),
                onChanged: _handleSearchChanged,
              ),
            ),
          ),

          // Filter chips
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.SpacingTokens.s16,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: Strings.epgFilterAll,
                    isSelected: _selectedFilter == Strings.epgFilterAll,
                    onTap: () => _handleFilterChange(Strings.epgFilterAll),
                  ),
                  SizedBox(width: tokens.SpacingTokens.s8),
                  _FilterChip(
                    label: Strings.epgFilterLive,
                    isSelected: _selectedFilter == Strings.epgFilterLive,
                    onTap: () => _handleFilterChange(Strings.epgFilterLive),
                  ),
                  SizedBox(width: tokens.SpacingTokens.s8),
                  _FilterChip(
                    label: Strings.epgFilterFavorites,
                    isSelected: _selectedFilter == Strings.epgFilterFavorites,
                    onTap: () =>
                        _handleFilterChange(Strings.epgFilterFavorites),
                  ),
                  SizedBox(width: tokens.SpacingTokens.s8),
                  _FilterChip(
                    label: Strings.epgFilterRecentlyWatched,
                    isSelected:
                        _selectedFilter == Strings.epgFilterRecentlyWatched,
                    onTap: () =>
                        _handleFilterChange(Strings.epgFilterRecentlyWatched),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: tokens.SpacingTokens.s16),

          // Channel list
          Expanded(
            child: ListView.builder(
              itemCount: widget.channels.length,
              itemBuilder: (context, index) {
                final channel = widget.channels[index];
                final isSelected = channel.id == widget.selectedChannelId;

                return Pressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onChannelTap(channel.id);
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    widget.onFavoriteToggle(channel.id);
                  },
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tokens.AppTokens.surface2
                          : Colors.transparent,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.SpacingTokens.s16,
                      ),
                      child: Row(
                        children: [
                          // Channel logo
                          _ChannelLogo(
                            imageUrl: channel.logoUrl,
                            channelName: channel.name,
                          ),
                          SizedBox(width: tokens.SpacingTokens.s12),

                          // Channel info
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Channel name
                                Text(
                                  channel.name,
                                  style: tokens.TypographyTokens.labelPrimary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: tokens.SpacingTokens.s4),

                                // Current program
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        channel.currentProgram ??
                                            Strings.channelNoProgram,
                                        style: tokens
                                            .TypographyTokens.captionSecondary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (channel.isLive) ...[
                                      SizedBox(width: tokens.SpacingTokens.s8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: tokens.SpacingTokens.s4,
                                          vertical: tokens.SpacingTokens.s4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.AppTokens.liveRed,
                                          borderRadius: BorderRadius.circular(
                                              tokens.RadiusTokens.xs),
                                        ),
                                        child: Text(
                                          Strings.liveIndicator,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // Progress bar (if program has progress)
                                if (channel.programProgress != null &&
                                    channel.programProgress! > 0) ...[
                                  SizedBox(height: tokens.SpacingTokens.s4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        tokens.RadiusTokens.xs),
                                    child: LinearProgressIndicator(
                                      value: channel.programProgress,
                                      backgroundColor:
                                          tokens.AppTokens.surface3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        tokens.AppTokens.accent,
                                      ),
                                      minHeight: 2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Favorite indicator
                          Icon(
                            channel.isFavorite
                                ? PhosphorIcons.heart()
                                : PhosphorIcons.heartBreak(),
                            size: 20,
                            color: channel.isFavorite
                                ? tokens.AppTokens.accent
                                : tokens.AppTokens.textTertiary,
                          ),
                        ],
                      ),
                    ),
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

/// Channel logo widget with loading/error states
class _ChannelLogo extends StatelessWidget {
  final String? imageUrl;
  final String channelName;

  const _ChannelLogo({
    this.imageUrl,
    required this.channelName,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.RadiusTokens.sm),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _LogoFallback(channelName),
                errorWidget: (context, url, error) =>
                    _LogoFallback(channelName),
              )
            : _LogoFallback(channelName),
      ),
    );
  }
}

/// Fallback logo when image not available or loading
class _LogoFallback extends StatelessWidget {
  final String channelName;

  const _LogoFallback(this.channelName);

  @override
  Widget build(BuildContext context) {
    final initial = channelName.isNotEmpty ? channelName[0].toUpperCase() : '?';

    return Container(
      color: tokens.AppTokens.surface3,
      child: Center(
        child: Text(
          initial,
          style: tokens.TypographyTokens.labelSecondary,
        ),
      ),
    );
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.SpacingTokens.s12,
          vertical: tokens.SpacingTokens.s4,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.AppTokens.accentMuted
              : tokens.AppTokens.surface2,
          borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
          border: Border.all(
            color:
                isSelected ? tokens.AppTokens.accent : tokens.AppTokens.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: isSelected
              ? tokens.TypographyTokens.captionAccent
              : tokens.TypographyTokens.captionPrimary,
        ),
      ),
    );
  }
}

/// Channel item data model
class ChannelItem {
  final String id;
  final String name;
  final String? logoUrl;
  final String? currentProgram;
  final double? programProgress;
  final bool isLive;
  final bool isFavorite;

  ChannelItem({
    required this.id,
    required this.name,
    this.logoUrl,
    this.currentProgram,
    this.programProgress,
    this.isLive = false,
    this.isFavorite = false,
  });
}
