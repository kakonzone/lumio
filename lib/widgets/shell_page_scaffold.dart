import 'package:flutter/material.dart';

import '../core/performance_tuning.dart';
import '../theme/app_theme.dart';
import 'shell_app_bar.dart';

/// Fixed shell bar + scroll body (single [SafeArea] on the bar only).
class ShellPageScaffold extends StatelessWidget {
  const ShellPageScaffold({
    super.key,
    required this.appBar,
    required this.slivers,
    this.onRefresh,
  });

  final ShellAppBar appBar;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: PerformanceTuning.listCacheExtent,
      slivers: [
        if (appBar.subtitle != null &&
            appBar.showBack &&
            appBar.hideSubtitleInBar)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                appBar.subtitle!,
                style: TextStyle(fontSize: 12, color: context.txt3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ...slivers,
      ],
    );

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          appBar,
          Expanded(
            child: onRefresh == null
                ? scroll
                : RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: onRefresh!,
                    child: scroll,
                  ),
          ),
        ],
      ),
    );
  }
}
