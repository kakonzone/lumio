// lib/widgets/settings/settings_row.dart
import 'package:flutter/material.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A settings row widget with icon, title, optional subtitle, and trailing widget.
///
/// Features:
/// - 56px height for consistent touch targets
/// - Leading icon (Phosphor regular weight, 20px, TextSecondary)
/// - Title (body size)
/// - Optional subtitle (caption, TextTertiary)
/// - Trailing: value + chevron, Switch, or just chevron
/// - Full row width tap area
/// - 1px border divider between rows
class SettingsRow extends StatelessWidget {
  /// Leading icon (Phosphor icon)
  final IconData leadingIcon;

  /// Main title text (body size)
  final String title;

  /// Optional subtitle text (caption, TextTertiary)
  final String? subtitle;

  /// Optional value text to display (caption, TextSecondary)
  final String? value;

  /// Optional trailing widget (Switch, custom widget, etc.)
  final Widget? trailing;

  /// Callback when row is tapped
  final VoidCallback? onTap;

  /// Whether this is the last row in a section (no bottom divider)
  final bool isLast;

  const SettingsRow({
    super.key,
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.isLast = false,
  });

  /// Create a row with a switch control
  factory SettingsRow.switchRow({
    Key? key,
    required IconData leadingIcon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return SettingsRow(
      key: key,
      leadingIcon: leadingIcon,
      title: title,
      subtitle: subtitle,
      trailing: _SwitchWidget(
        value: value,
        onChanged: onChanged,
      ),
      isLast: isLast,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: tokens.AppTokens.surface1,
          border: isLast
              ? null
              : const Border(
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
              // Leading icon
              Icon(
                leadingIcon,
                size: 20,
                color: tokens.AppTokens.textSecondary,
              ),
              SizedBox(width: tokens.SpacingTokens.s16),

              // Title and subtitle
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tokens.TypographyTokens.bodyPrimary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: tokens.SpacingTokens.s4),
                      Text(
                        subtitle!,
                        style: tokens.TypographyTokens.captionTertiary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing content
              if (trailing != null)
                trailing!
              else if (value != null) ...[
                Text(
                  value!,
                  style: tokens.TypographyTokens.captionSecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(width: tokens.SpacingTokens.s8),
                Icon(
                  PhosphorIcons.caretRight(),
                  size: 16,
                  color: tokens.AppTokens.textTertiary,
                ),
              ] else if (onTap != null) ...[
                Icon(
                  PhosphorIcons.caretRight(),
                  size: 16,
                  color: tokens.AppTokens.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Switch widget for settings rows
class _SwitchWidget extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchWidget({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.9,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
