// lib/widgets/live/epg_timeline.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';

/// EPG timeline widget for right panel in Live TV screen
///
/// Features:
/// - Horizontal timeline with time markers (every 30 min)
/// - "Now" red vertical line, animated to current time
/// - Program blocks: rounded rect, Surface2, with program title + time
/// - Live program block has accent left border
/// - Tap program: details bottom sheet with description + record/reminder options
/// - Horizontal scroll independent of channel scroll
class EpgTimeline extends StatefulWidget {
  final List<EpgProgram> programs;
  final Function(EpgProgram) onProgramTap;
  final ScrollController? scrollController;

  const EpgTimeline({
    super.key,
    required this.programs,
    required this.onProgramTap,
    this.scrollController,
  });

  @override
  State<EpgTimeline> createState() => _EpgTimelineState();
}

class _EpgTimelineState extends State<EpgTimeline> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll to current time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNow();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final minutesFromStart = now.difference(startOfDay).inMinutes;

    // Approximate scroll position (30 minutes = 100px)
    final scrollPosition = (minutesFromStart / 30) * 100;

    _scrollController.animateTo(
      scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.AppTokens.background,
      child: Column(
        children: [
          // Time markers header
          _TimeMarkers(),

          // Timeline content
          Expanded(
            child: Stack(
              children: [
                // Programs
                SingleChildScrollView(
                  controller: widget.scrollController ?? _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    height: double.infinity,
                    width: _calculateTotalWidth(),
                    child: Stack(
                      children: [
                        // Time grid lines
                        _TimeGrid(),

                        // Program blocks
                        ...widget.programs.asMap().entries.map((entry) {
                          final program = entry.value;
                          return Positioned(
                            left: program.startOffset,
                            top: 0,
                            bottom: 0,
                            width: program.width,
                            child: _ProgramBlock(
                              program: program,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onProgramTap(program);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // "Now" indicator (red vertical line)
                Positioned(
                  left: _calculateNowOffset(),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: tokens.AppTokens.liveRed,
                      boxShadow: [
                        BoxShadow(
                          color:
                              tokens.AppTokens.liveRed.withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalWidth() {
    // 24 hours = 48 half-hour slots * 100px per slot = 4800px
    return 4800.0;
  }

  double _calculateNowOffset() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final minutesFromStart = now.difference(startOfDay).inMinutes;
    return (minutesFromStart / 30) * 100;
  }
}

/// Time markers header widget
class _TimeMarkers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final times = _generateTimeMarkers();

    return Container(
      height: 32,
      decoration: const BoxDecoration(
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
        itemCount: times.length,
        itemBuilder: (context, index) {
          return Container(
            width: 100,
            padding: const EdgeInsets.symmetric(
              horizontal: tokens.SpacingTokens.s8,
              vertical: tokens.SpacingTokens.s8,
            ),
            child: Text(
              times[index],
              style: tokens.TypographyTokens.captionSecondary,
            ),
          );
        },
      ),
    );
  }

  List<String> _generateTimeMarkers() {
    final times = <String>[];
    for (var hour = 0; hour < 24; hour++) {
      times.add('${hour.toString().padLeft(2, '0')}:00');
      if (hour < 23) {
        times.add('${hour.toString().padLeft(2, '0')}:30');
      }
    }
    return times;
  }
}

/// Time grid lines widget
class _TimeGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: List.generate(48, (index) {
          return Positioned(
            left: (index * 100.0) - 0.5,
            top: 0,
            bottom: 0,
            child: Container(
              width: 1,
              decoration: BoxDecoration(
                color: tokens.AppTokens.border.withValues(alpha: 0.3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Program block widget
class _ProgramBlock extends StatelessWidget {
  final EpgProgram program;
  final VoidCallback onTap;

  const _ProgramBlock({
    required this.program,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: tokens.SpacingTokens.s4,
          horizontal: tokens.SpacingTokens.s4,
        ),
        decoration: BoxDecoration(
          color: tokens.AppTokens.surface2,
          borderRadius: BorderRadius.circular(tokens.RadiusTokens.sm),
          border: Border(
            left: BorderSide(
              color:
                  program.isLive ? tokens.AppTokens.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: tokens.SpacingTokens.s8,
          vertical: tokens.SpacingTokens.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Program title
            Text(
              program.title,
              style: tokens.TypographyTokens.captionPrimary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: tokens.SpacingTokens.s4),

            // Time
            Row(
              children: [
                if (program.isLive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: tokens.SpacingTokens.s4,
                      vertical: tokens.SpacingTokens.s4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.AppTokens.liveRed,
                      borderRadius:
                          BorderRadius.circular(tokens.RadiusTokens.xs),
                    ),
                    child: const Text(
                      Strings.liveIndicator,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: tokens.SpacingTokens.s4),
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
}

/// EPG program data model
class EpgProgram {
  final String id;
  final String channelId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isLive;

  EpgProgram({
    required this.id,
    required this.channelId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.isLive = false,
  });

  /// Calculate horizontal offset for timeline
  double get startOffset {
    final startOfDay = DateTime(startTime.year, startTime.month, startTime.day);
    final minutesFromStart = startTime.difference(startOfDay).inMinutes;
    return (minutesFromStart / 30) * 100;
  }

  /// Calculate width for timeline
  double get width {
    final duration = endTime.difference(startTime);
    final minutes = duration.inMinutes;
    return (minutes / 30) * 100;
  }

  /// Get formatted time range
  String get timeRange {
    final start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  /// Create mock programs for testing
  static List<EpgProgram> generateMockPrograms() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return [
      EpgProgram(
        id: '1',
        channelId: 'channel1',
        title: 'Morning News',
        startTime: startOfDay.add(const Duration(hours: 6)),
        endTime: startOfDay.add(const Duration(hours: 8)),
        isLive: false,
      ),
      EpgProgram(
        id: '2',
        channelId: 'channel1',
        title: 'Live Sports Update',
        startTime: startOfDay.add(const Duration(hours: 8)),
        endTime: startOfDay.add(const Duration(hours: 10)),
        isLive: true,
      ),
      EpgProgram(
        id: '3',
        channelId: 'channel1',
        title: 'Documentary: Wildlife',
        startTime: startOfDay.add(const Duration(hours: 10)),
        endTime: startOfDay.add(const Duration(hours: 12)),
        isLive: false,
      ),
      EpgProgram(
        id: '4',
        channelId: 'channel1',
        title: 'Afternoon Talk Show',
        startTime: startOfDay.add(const Duration(hours: 12)),
        endTime: startOfDay.add(const Duration(hours: 14)),
        isLive: false,
      ),
      EpgProgram(
        id: '5',
        channelId: 'channel1',
        title: 'Live Football Match',
        startTime: startOfDay.add(const Duration(hours: 14)),
        endTime: startOfDay.add(const Duration(hours: 17)),
        isLive: true,
      ),
      EpgProgram(
        id: '6',
        channelId: 'channel1',
        title: 'Evening News',
        startTime: startOfDay.add(const Duration(hours: 17)),
        endTime: startOfDay.add(const Duration(hours: 19)),
        isLive: false,
      ),
      EpgProgram(
        id: '7',
        channelId: 'channel1',
        title: 'Prime Time Drama',
        startTime: startOfDay.add(const Duration(hours: 19)),
        endTime: startOfDay.add(const Duration(hours: 21)),
        isLive: false,
      ),
      EpgProgram(
        id: '8',
        channelId: 'channel1',
        title: 'Late Night Movie',
        startTime: startOfDay.add(const Duration(hours: 21)),
        endTime: startOfDay.add(const Duration(hours: 23)),
        isLive: false,
      ),
    ];
  }
}
