// lib/widgets/settings/settings_section.dart
import 'package:flutter/material.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/settings/settings_row.dart';

/// A settings section widget with header and grouped rows.
///
/// Features:
/// - Section header with caption size, weight 600, uppercase, letterSpacing 0.08em
/// - 24px top padding, 8px bottom padding, 16px horizontal padding
/// - Surface1 background, radius md for row group
/// - 1px border dividers between rows
/// - 24px gap between sections
class SettingsSection extends StatelessWidget {
  /// Section title (displayed as header)
  final String title;

  /// List of setting rows in this section
  final List<Widget> rows;

  const SettingsSection({
    super.key,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(
            top: tokens.SpacingTokens.s24,
            bottom: tokens.SpacingTokens.s8,
            left: tokens.SpacingTokens.s16,
            right: tokens.SpacingTokens.s16,
          ),
          child: Text(
            title.toUpperCase(),
            style: tokens.TypographyTokens.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.AppTokens.textTertiary,
              letterSpacing: 0.08,
            ),
          ),
        ),

        // Row group with Surface1 background and radius
        Container(
          decoration: BoxDecoration(
            color: tokens.AppTokens.surface1,
            borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                // Mark last row to hide bottom divider
                if (rows[i] is SettingsRow)
                  (rows[i] as SettingsRow)
                      .copyWith(isLast: i == rows.length - 1)
                else
                  rows[i],
              ],
            ],
          ),
        ),

        // Gap between sections
        const SizedBox(height: tokens.SpacingTokens.s24),
      ],
    );
  }
}

/// Extension to add copyWith method to SettingsRow
extension SettingsRowCopyWith on SettingsRow {
  SettingsRow copyWith({bool? isLast}) {
    return SettingsRow(
      key: key,
      leadingIcon: leadingIcon,
      title: title,
      subtitle: subtitle,
      value: value,
      trailing: trailing,
      onTap: onTap,
      isLast: isLast ?? this.isLast,
    );
  }
}
