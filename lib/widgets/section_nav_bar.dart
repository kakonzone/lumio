import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Horizontal pill navigation — theme-aware for Sports, News, and similar screens.
class SectionNavBar extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;
  final double height;

  const SectionNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final label = items[i];
          final active = label == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(label);
            },
            borderRadius: BorderRadius.circular(22),
            splashColor: AppColors.accent.withValues(alpha: 0.15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: active
                    ? LinearGradient(
                        colors: isDark
                            ? [AppColors.accent, const Color(0xFFE65100)]
                            : [const Color(0xFFFF7A2E), AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: active
                    ? null
                    : (isDark ? context.bg3 : context.bg2),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: active
                      ? Colors.transparent
                      : (isDark
                          ? context.brd
                          : AppColors.borderLight),
                  width: 1,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha: isDark ? 0.35 : 0.28,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: GoogleFonts.barlow(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active
                      ? Colors.white
                      : (isDark ? context.txt2 : context.txt2),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          );
        },
      ),
    );
  }
}

/// Quick stats row under section headers (Live / Sports counts).
class ScreenStatChips extends StatelessWidget {
  final List<({IconData icon, String label})> chips;

  const ScreenStatChips({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((c) => _StatChip(icon: c.icon, label: c.label)).toList(),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.bg3,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.brd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.barlow(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.txt2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen hero header with icon row + title (Sports / News style).
class SectionScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? leadingIcons;

  const SectionScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcons,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.accent.withValues(alpha: 0.12),
                  Colors.transparent,
                ]
              : [
                  AppColors.accentLight,
                  Colors.transparent,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingIcons != null && leadingIcons!.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: leadingIcons!,
            ),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            style: GoogleFonts.barlowCondensed(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: context.txt,
              height: 1.05,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: context.txt3,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
