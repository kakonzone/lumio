import 'package:flutter/material.dart';
import '../models/model.dart';

/// Widget that displays stream security status as a lock/unlock icon.
///
/// Shows:
/// - 🔒 Green lock for HTTPS (secure)
/// - 🔒 Blue lock for proxied streams (HTTPS via proxy)
/// - 🔓 Red unlocked for HTTP cleartext (insecure)
/// - ❓ Gray question mark for unknown status
class StreamSecurityBadge extends StatelessWidget {
  final StreamSecurity security;
  final double size;
  final bool showLabel;

  const StreamSecurityBadge({
    super.key,
    required this.security,
    this.size = 16,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _getSecurityInfo();

    Widget iconWidget = Icon(
      icon,
      size: size,
      color: color,
    );

    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: size * 0.75,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return iconWidget;
  }

  /// Returns (icon, color, label) for the given security status.
  (IconData, Color, String) _getSecurityInfo() {
    switch (security) {
      case StreamSecurity.secure:
        return (Icons.lock, Colors.green.shade600, 'Secure');

      case StreamSecurity.proxied:
        return (Icons.lock, Colors.blue.shade600, 'Proxied');

      case StreamSecurity.cleartext:
        return (Icons.lock_open, Colors.red.shade600, 'Insecure');

      case StreamSecurity.unknown:
        return (Icons.help_outline, Colors.grey.shade600, 'Unknown');
    }
  }

  /// Creates a badge from a ChannelModel.
  factory StreamSecurityBadge.fromChannel(
    ChannelModel channel, {
    Key? key,
    double size = 16,
    bool showLabel = false,
  }) {
    return StreamSecurityBadge(
      key: key,
      security: channel.inferredStreamSecurity,
      size: size,
      showLabel: showLabel,
    );
  }

  /// Returns tooltip text explaining the security status.
  String get tooltip {
    switch (security) {
      case StreamSecurity.secure:
        return 'Stream uses HTTPS - encrypted and secure';
      case StreamSecurity.proxied:
        return 'Stream uses HTTP proxied through HTTPS';
      case StreamSecurity.cleartext:
        return 'Stream uses HTTP cleartext - unencrypted';
      case StreamSecurity.unknown:
        return 'Stream security status unknown';
    }
  }
}

/// Compact version of StreamSecurityBadge that only shows the icon.
class StreamSecurityIcon extends StatelessWidget {
  final StreamSecurity security;
  final double size;

  const StreamSecurityIcon({
    super.key,
    required this.security,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final badge = StreamSecurityBadge(
      security: security,
      size: size,
      showLabel: false,
    );

    return Tooltip(
      message: badge.tooltip,
      child: badge,
    );
  }

  /// Creates an icon from a ChannelModel.
  factory StreamSecurityIcon.fromChannel(
    ChannelModel channel, {
    Key? key,
    double size = 14,
  }) {
    return StreamSecurityIcon(
      key: key,
      security: channel.inferredStreamSecurity,
      size: size,
    );
  }
}

/// Widget that shows security status in a pill/badge format.
class StreamSecurityPill extends StatelessWidget {
  final StreamSecurity security;
  final bool showBorder;

  const StreamSecurityPill({
    super.key,
    required this.security,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _getSecurityInfo();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: showBorder ? Border.all(color: color, width: 1) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns (icon, color, label) for the given security status.
  (IconData, Color, String) _getSecurityInfo() {
    switch (security) {
      case StreamSecurity.secure:
        return (Icons.lock, Colors.green.shade600, 'SECURE');
      case StreamSecurity.proxied:
        return (Icons.lock, Colors.blue.shade600, 'PROXIED');
      case StreamSecurity.cleartext:
        return (Icons.lock_open, Colors.red.shade600, 'HTTP');
      case StreamSecurity.unknown:
        return (Icons.help_outline, Colors.grey.shade600, '?');
    }
  }

  /// Creates a pill from a ChannelModel.
  factory StreamSecurityPill.fromChannel(
    ChannelModel channel, {
    Key? key,
    bool showBorder = true,
  }) {
    return StreamSecurityPill(
      key: key,
      security: channel.inferredStreamSecurity,
      showBorder: showBorder,
    );
  }
}
