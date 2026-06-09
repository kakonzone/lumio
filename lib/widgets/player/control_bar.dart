// lib/widgets/player/control_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:lumio_tv/l10n/strings.dart' as strings;
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/theme/tokens/motion.dart' as tokens;
import 'package:lumio_tv/utils/haptic_helpers.dart' as haptics;

/// Player control bar with editorial layout.
/// 
/// Features:
/// - Top bar: back arrow, channel name, cast + PiP icons
/// - Bottom: scrubber (4px, accent color), time labels, control row
/// - Control row: rewind 10s | play/pause (64px) | forward 10s
/// - Bottom-right: quality, audio, subtitle, fullscreen icons
class ControlBar extends StatefulWidget {
  final String channelName;
  final String currentProgram;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final VoidCallback? onBack;
  final VoidCallback? onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final VoidCallback? onSeek;
  final VoidCallback? onQualityTap;
  final VoidCallback? onAudioTap;
  final VoidCallback? onSubtitleTap;
  final VoidCallback? onFullscreenTap;
  final VoidCallback? onCastTap;
  final VoidCallback? onPiPTap;
  final bool showQuality;
  final bool showAudio;
  final bool showSubtitles;

  const ControlBar({
    super.key,
    required this.channelName,
    required this.currentProgram,
    required this.position,
    required this.duration,
    required this.isPlaying,
    this.onBack,
    this.onPlayPause,
    this.onRewind,
    this.onForward,
    this.onSeek,
    this.onQualityTap,
    this.onAudioTap,
    this.onSubtitleTap,
    this.onFullscreenTap,
    this.onCastTap,
    this.onPiPTap,
    this.showQuality = true,
    this.showAudio = true,
    this.showSubtitles = true,
  });

  @override
  State<ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<ControlBar> with SingleTickerProviderStateMixin {
  double _scrubberPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _updateScrubberPosition();
  }

  @override
  void didUpdateWidget(ControlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position || oldWidget.duration != widget.duration) {
      _updateScrubberPosition();
    }
  }

  void _updateScrubberPosition() {
    if (widget.duration.inMilliseconds > 0) {
      setState(() {
        _scrubberPosition = widget.position.inMilliseconds / widget.duration.inMilliseconds;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(hours * 60);
    final seconds = duration.inSeconds.remainder(minutes * 60);
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top bar
        _TopBar(
          channelName: widget.channelName,
          onBack: widget.onBack,
          onCastTap: widget.onCastTap,
          onPiPTap: widget.onPiPTap,
        ),
        
        const SizedBox(height: tokens.SpacingTokens.s32),
        
        // Scrubber with time labels
        _Scrubber(
          position: widget.position,
          duration: widget.duration,
          scrubberPosition: _scrubberPosition,
          onSeek: widget.onSeek,
        ),
        
        const SizedBox(height: tokens.SpacingTokens.s24),
        
        // Control row
        _ControlRow(
          isPlaying: widget.isPlaying,
          onPlayPause: widget.onPlayPause,
          onRewind: widget.onRewind,
          onForward: widget.onForward,
          onQualityTap: widget.onQualityTap,
          onAudioTap: widget.onAudioTap,
          onSubtitleTap: widget.onSubtitleTap,
          onFullscreenTap: widget.onFullscreenTap,
          showQuality: widget.showQuality,
          showAudio: widget.showAudio,
          showSubtitles: widget.showSubtitles,
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String channelName;
  final VoidCallback? onBack;
  final VoidCallback? onCastTap;
  final VoidCallback? onPiPTap;

  const _TopBar({
    required this.channelName,
    this.onBack,
    this.onCastTap,
    this.onPiPTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Back arrow
        IconButton(
          onPressed: () {
            haptics.buttonPress();
            onBack?.call();
          },
          icon: const Icon(PhosphorIcons.chevron_left),
          color: tokens.AppTokens.textPrimary,
          iconSize: 24,
        ),
        
        const SizedBox(width: tokens.SpacingTokens.s16),
        
        // Channel name
        Expanded(
          child: Text(
            channelName,
            style: tokens.TypographyTokens.titlePrimary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Cast + PiP icons
        Row(
          children: [
            IconButton(
              onPressed: () {
                haptics.buttonPress();
                onCastTap?.call();
              },
              icon: const Icon(PhosphorIcons.television_simple),
              color: tokens.AppTokens.textPrimary,
              iconSize: 24,
            ),
            IconButton(
              onPressed: () {
                haptics.buttonPress();
                onPiPTap?.call();
              },
              icon: const Icon(PhosphorIcons.picture_in_picture),
              color: tokens.AppTokens.textPrimary,
              iconSize: 24,
            ),
          ],
        ),
      ],
    );
  }
}

class _Scrubber extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final double scrubberPosition;
  final VoidCallback? onSeek;

  const _Scrubber({
    required this.position,
    required this.duration,
    required this.scrubberPosition,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scrubber (4px accent color)
        SizedBox(
          height: 4,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayColor: tokens.AppTokens.accent.withOpacity(0.2),
              activeTrackColor: tokens.AppTokens.accent,
              inactiveTrackColor: tokens.AppTokens.surface3,
            ),
            child: Slider(
              value: scrubberPosition,
              onChanged: (value) {
                onSeek?.call(Duration(
                  milliseconds: (value * duration.inMilliseconds).round(),
                ));
              },
            ),
          ),
        ),
        
        const SizedBox(height: tokens.SpacingTokens.s12),
        
        // Time labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                _formatDuration(position),
                style: tokens.TypographyTokens.captionSecondary,
            ),
            Text(
                _formatDuration(duration),
                style: tokens.TypographyTokens.captionSecondary,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(hours * 60);
    final seconds = duration.inSeconds.remainder(minutes * 60);
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ControlRow extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final VoidCallback? onQualityTap;
  final VoidCallback? onAudioTap;
  final VoidCallback? onSubtitleTap;
  final VoidCallback? onFullscreenTap;
  final bool showQuality;
  final bool showAudio;
  final bool showSubtitles;

  const _ControlRow({
    required this.isPlaying,
    this.onPlayPause,
    this.onRewind,
    this.onForward,
    this.onQualityTap,
    this.onAudioTap,
    this.onSubtitleTap,
    this.onFullscreenTap,
    this.showQuality = true,
    this.showAudio = true,
    this.showSubtitles = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Rewind 10s
        IconButton(
          onPressed: () {
            haptics.lightImpact();
            onRewind?.call();
          },
          icon: const Icon(PhosphorIcons.globe_hemisphere_west),
          color: tokens.AppTokens.textPrimary,
          iconSize: 32,
        ),
        
        const SizedBox(width: tokens.SpacingTokens.s24),
        
        // Play/Pause (oversized 64px)
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: tokens.AppTokens.surface2,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () {
              haptics.mediumImpact();
              onPlayPause?.call();
            },
            icon: Icon(
              isPlaying ? PhosphorIcons.pause : PhosphorIcons.play,
              size: 32,
              color: tokens.AppTokens.textPrimary,
            ),
          ),
        ),
        
        const SizedBox(width: tokens.SpacingTokens.s24),
        
        // Forward 10s
        IconButton(
          onPressed: () {
            haptics.lightImpact();
            onForward?.call();
          },
          icon: const Icon(PhosphorIcons.globe_hemisphere_east),
          color: tokens.AppTokens.textPrimary,
          iconSize: 32,
        ),
        
        const Spacer(),
        
        // Quality, Audio, Subtitle, Fullscreen icons
        Row(
          children: [
            if (showQuality)
              IconButton(
                onPressed: () {
                  haptics.buttonPress();
                  onQualityTap?.call();
                },
                icon: const Icon(PhosphorIcons.faders),
                color: tokens.AppTokens.textPrimary,
                iconSize: 24,
              ),
            if (showAudio)
              IconButton(
                onPressed: () {
                  haptics.buttonPress();
                  onAudioTap?.call();
                },
                icon: const Icon(PhosphorIcons.speaker_high),
                color: tokens.AppTokens.textPrimary,
                iconSize: 24,
              ),
            if (showSubtitles)
              IconButton(
                onPressed: () {
                  haptics.buttonPress();
                  onSubtitleTap?.call();
                },
                icon: const Icon(PhosphorIcons.captions),
                color: tokens.AppTokens.textPrimary,
                iconSize: 24,
              ),
            IconButton(
              onPressed: () {
                haptics.buttonPress();
                onFullscreenTap?.call();
              },
              icon: const Icon(PhosphorIcons.corners_out),
              color: tokens.AppTokens.textPrimary,
              iconSize: 24,
            ),
          ],
        ),
      ],
    );
  }
}
