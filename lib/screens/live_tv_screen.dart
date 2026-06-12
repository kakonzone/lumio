// lib/screens/live_tv_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/live/category_rail.dart';
import 'package:lumio_tv/widgets/live/channel_list.dart';
import 'package:lumio_tv/widgets/live/epg_timeline.dart';
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Live TV screen with 3-panel layout
/// 
/// Landscape layout:
/// - LEFT PANEL (240px): Category rail
/// - CENTER PANEL (320px): Channel list with filter chips
/// - RIGHT PANEL (fills remaining): EPG timeline
/// 
/// Portrait mode:
/// - Single column with tabs: Categories | Channels | Guide
class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  String _selectedCategoryId = 'all';
  String _selectedChannelId = 'channel1';

  // Mock data
  late final List<CategoryItem> _categories;
  late final List<ChannelItem> _channels;
  late final List<EpgProgram> _programs;

  @override
  void initState() {
    super.initState();
    _categories = CategoryItem.getDefaultCategories();
    _channels = _generateMockChannels();
    _programs = EpgProgram.generateMockPrograms();
  }

  @override
  Widget build(BuildContext context) {
    // Check orientation
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      return _buildPortraitLayout();
    } else {
      return _buildLandscapeLayout();
    }
  }

  /// Landscape layout: 3-panel design
  Widget _buildLandscapeLayout() {
    return Scaffold(
      backgroundColor: tokens.AppTokens.background,
      body: Row(
        children: [
          // LEFT PANEL: Category rail (240px)
          CategoryRail(
            categories: _categories,
            selectedCategoryId: _selectedCategoryId,
            onCategoryTap: (categoryId) {
              setState(() {
                _selectedCategoryId = categoryId;
              });
            },
          ),

          // CENTER PANEL: Channel list (320px)
          ChannelList(
            channels: _channels,
            selectedChannelId: _selectedChannelId,
            onChannelTap: (channelId) {
              setState(() {
                _selectedChannelId = channelId;
              });
            },
            onFavoriteToggle: (channelId) {
              // Toggle favorite logic
              setState(() {
                final channel = _channels.firstWhere((ch) => ch.id == channelId);
                final index = _channels.indexOf(channel);
                _channels[index] = ChannelItem(
                  id: channel.id,
                  name: channel.name,
                  logoUrl: channel.logoUrl,
                  currentProgram: channel.currentProgram,
                  programProgress: channel.programProgress,
                  isLive: channel.isLive,
                  isFavorite: !channel.isFavorite,
                );
              });
            },
            onSearchChanged: (query) {
              // Search logic
            },
          ),

          // RIGHT PANEL: EPG timeline (fills remaining)
          Expanded(
            child: EpgTimeline(
              programs: _programs,
              onProgramTap: (program) {
                _showProgramDetails(program);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Portrait layout: Single column with tabs
  Widget _buildPortraitLayout() {
    return Scaffold(
      backgroundColor: tokens.AppTokens.background,
      appBar: AppBar(
        backgroundColor: tokens.AppTokens.surface1,
        title: Text('Live TV'),
        bottom: TabBar(
          tabs: [
            Tab(text: Strings.epgTabCategories),
            Tab(text: Strings.epgTabChannels),
            Tab(text: Strings.epgTabGuide),
          ],
          labelStyle: tokens.TypographyTokens.labelPrimary,
          unselectedLabelStyle: tokens.TypographyTokens.labelSecondary,
          indicatorColor: tokens.AppTokens.accent,
          indicatorWeight: 3,
        ),
      ),
      body: TabBarView(
        children: [
          // Categories tab
          _buildPortraitCategories(),
          
          // Channels tab
          _buildPortraitChannels(),
          
          // Guide tab
          _buildPortraitGuide(),
        ],
      ),
    );
  }

  Widget _buildPortraitCategories() {
    return ListView.builder(
      addAutomaticKeepAlives: true,
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isSelected = category.id == _selectedCategoryId;

        return Pressable(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedCategoryId = category.id;
            });
          },
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isSelected ? tokens.AppTokens.surface2 : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: tokens.AppTokens.border,
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.SpacingTokens.s16,
              ),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    size: 24,
                    color: isSelected
                        ? tokens.AppTokens.accent
                        : tokens.AppTokens.textSecondary,
                  ),
                  SizedBox(width: tokens.SpacingTokens.s16),
                  Text(
                    category.label,
                    style: isSelected
                        ? tokens.TypographyTokens.bodyAccent
                        : tokens.TypographyTokens.bodyPrimary,
                  ),
                  Spacer(),
                  Icon(
                    PhosphorIcons.caretRight(),
                    size: 20,
                    color: tokens.AppTokens.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortraitChannels() {
    return Column(
      children: [
        // Filter chips (horizontal scroll)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.all(tokens.SpacingTokens.s16),
          child: Row(
            children: [
              portraitFilterChip(Strings.epgFilterAll),
              SizedBox(width: tokens.SpacingTokens.s8),
              portraitFilterChip(Strings.epgFilterLive),
              SizedBox(width: tokens.SpacingTokens.s8),
              portraitFilterChip(Strings.epgFilterFavorites),
              SizedBox(width: tokens.SpacingTokens.s8),
              portraitFilterChip(Strings.epgFilterRecentlyWatched),
            ],
          ),
        ),

        // Channel list
        Expanded(
          child: ListView.builder(
            addAutomaticKeepAlives: true,
            itemCount: _channels.length,
            itemBuilder: (context, index) {
              final channel = _channels[index];
              final isSelected = channel.id == _selectedChannelId;

              return Pressable(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedChannelId = channel.id;
                  });
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  // Toggle favorite
                },
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.AppTokens.surface2 : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: tokens.AppTokens.border,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.SpacingTokens.s16,
                    ),
                    child: Row(
                      children: [
                        // Logo
                        portraitChannelLogo(channel.logoUrl, channel.name),
                        SizedBox(width: tokens.SpacingTokens.s12),

                        // Channel info
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel.name,
                                style: tokens.TypographyTokens.bodyPrimary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: tokens.SpacingTokens.s4),
                              Text(
                                channel.currentProgram ?? Strings.channelNoProgram,
                                style: tokens.TypographyTokens.captionSecondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Favorite icon
                        Icon(
                          channel.isFavorite
                              ? PhosphorIcons.heart()
                              : PhosphorIcons.heartBreak(),
                          size: 24,
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
    );
  }

  Widget _buildPortraitGuide() {
    return Column(
      children: [
        // Time markers header
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: tokens.AppTokens.surface1,
            border: Border(
              bottom: BorderSide(
                color: tokens.AppTokens.border,
                width: 1,
              ),
            ),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.SpacingTokens.s8,
            ),
            itemCount: 24,
            itemBuilder: (context, index) {
              return Container(
                width: 80,
                alignment: Alignment.center,
                child: Text(
                  '${index.toString().padLeft(2, '0')}:00',
                  style: tokens.TypographyTokens.captionSecondary,
                ),
              );
            },
          ),
        ),

        // Programs list
        Expanded(
          child: ListView.builder(
            addAutomaticKeepAlives: true,
            itemCount: _programs.length,
            itemBuilder: (context, index) {
              final program = _programs[index];
              return portraitProgramBlock(program);
            },
          ),
        ),
      ],
    );
  }

  Widget portraitChannelLogo(String? logoUrl, String channelName) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.RadiusTokens.sm),
        child: logoUrl != null
            ? Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return logoFallback(channelName);
                },
              )
            : logoFallback(channelName),
      ),
    );
  }

  Widget portraitProgramBlock(EpgProgram program) {
    return Pressable(
      onTap: () => _showProgramDetails(program),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: tokens.SpacingTokens.s16,
          vertical: tokens.SpacingTokens.s8,
        ),
        padding: EdgeInsets.all(tokens.SpacingTokens.s12),
        decoration: BoxDecoration(
          color: tokens.AppTokens.surface2,
          borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
          border: Border(
            left: BorderSide(
              color: program.isLive
                  ? tokens.AppTokens.accent
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              program.title,
              style: tokens.TypographyTokens.bodyPrimary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: tokens.SpacingTokens.s8),
            Row(
              children: [
                if (program.isLive) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.SpacingTokens.s8,
                      vertical: tokens.SpacingTokens.s4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.AppTokens.liveRed,
                      borderRadius: BorderRadius.circular(tokens.RadiusTokens.xs),
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
                  SizedBox(width: tokens.SpacingTokens.s8),
                ],
                Text(
                  program.timeRange,
                  style: tokens.TypographyTokens.captionSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget portraitFilterChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.SpacingTokens.s16,
        vertical: tokens.SpacingTokens.s8,
      ),
      decoration: BoxDecoration(
        color: tokens.AppTokens.surface2,
        borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
        border: Border.all(
          color: tokens.AppTokens.border,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: tokens.TypographyTokens.labelPrimary,
      ),
    );
  }

  Widget logoFallback(String channelName) {
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

  void _showProgramDetails(EpgProgram program) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: tokens.AppTokens.surface2,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.RadiusTokens.lg),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(tokens.SpacingTokens.s16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Strings.epgProgramDetails,
                      style: tokens.TypographyTokens.titlePrimary,
                    ),
                    IconButton(
                      icon: Icon(PhosphorIcons.x()),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Program info
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.SpacingTokens.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.title,
                      style: tokens.TypographyTokens.headingPrimary,
                    ),
                    SizedBox(height: tokens.SpacingTokens.s8),
                    Text(
                      program.timeRange,
                      style: tokens.TypographyTokens.bodySecondary,
                    ),
                    if (program.description != null) ...[
                      SizedBox(height: tokens.SpacingTokens.s16),
                      Text(
                        program.description!,
                        style: tokens.TypographyTokens.bodyPrimary,
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: tokens.SpacingTokens.s24),

              // Actions
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.SpacingTokens.s16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          // Record functionality
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.AppTokens.accent,
                            borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  PhosphorIcons.record(),
                                  size: 20,
                                  color: Colors.white,
                                ),
                                SizedBox(width: tokens.SpacingTokens.s8),
                                Text(
                                  Strings.epgRecord,
                                  style: tokens.TypographyTokens.labelPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.SpacingTokens.s12),
                    Expanded(
                      child: Pressable(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          // Reminder functionality
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.AppTokens.surface3,
                            borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  PhosphorIcons.bell(),
                                  size: 20,
                                  color: tokens.AppTokens.textPrimary,
                                ),
                                SizedBox(width: tokens.SpacingTokens.s8),
                                Text(
                                  Strings.epgReminder,
                                  style: tokens.TypographyTokens.labelPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: tokens.SpacingTokens.s16),
            ],
          ),
        ),
      ),
    );
    HapticFeedback.lightImpact();
  }

  /// Generate mock channel data
  List<ChannelItem> _generateMockChannels() {
    return [
      ChannelItem(
        id: 'channel1',
        name: 'BBC One',
        logoUrl: null,
        currentProgram: 'Morning News',
        programProgress: 0.3,
        isLive: true,
        isFavorite: false,
      ),
      ChannelItem(
        id: 'channel2',
        name: 'CNN International',
        logoUrl: null,
        currentProgram: 'World News Today',
        programProgress: 0.7,
        isLive: true,
        isFavorite: true,
      ),
      ChannelItem(
        id: 'channel3',
        name: 'ESPN',
        logoUrl: null,
        currentProgram: 'Sports Center',
        programProgress: 0.1,
        isLive: true,
        isFavorite: false,
      ),
      ChannelItem(
        id: 'channel4',
        name: 'National Geographic',
        logoUrl: null,
        currentProgram: 'Wildlife Documentary',
        programProgress: 0.0,
        isLive: false,
        isFavorite: true,
      ),
      ChannelItem(
        id: 'channel5',
        name: 'Discovery Channel',
        logoUrl: null,
        currentProgram: 'Science Show',
        programProgress: 0.0,
        isLive: false,
        isFavorite: false,
      ),
    ];
  }
}