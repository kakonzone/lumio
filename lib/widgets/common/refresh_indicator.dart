// lib/widgets/common/refresh_indicator.dart
import 'package:flutter/material.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;

/// Custom refresh indicator that matches app design
///
/// Features:
/// - Accent color for indicator
/// - Background color matching app theme
/// - Smooth animation
class AppRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;
  final Color? backgroundColor;

  const AppRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? tokens.AppTokens.accent,
      backgroundColor: backgroundColor ?? tokens.AppTokens.surface2,
      displacement: 40,
      strokeWidth: 3,
      child: child,
    );
  }
}

/// Load more indicator for pagination
class LoadMoreIndicator extends StatelessWidget {
  final Future<void> Function() onLoadMore;
  final bool isLoading;
  final bool hasMore;
  final Widget? loadingWidget;
  final Widget? noMoreWidget;

  const LoadMoreIndicator({
    super.key,
    required this.onLoadMore,
    required this.isLoading,
    required this.hasMore,
    this.loadingWidget,
    this.noMoreWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return noMoreWidget ??
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No more items',
              style: TextStyle(
                color: tokens.AppTokens.textTertiary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          );
    }

    if (isLoading) {
      return loadingWidget ??
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: tokens.AppTokens.accent,
              ),
            ),
          );
    }

    return SizedBox(
      height: 60,
      child: Center(
        child: TextButton(
          onPressed: onLoadMore,
          child: const Text(
            'Load more',
            style: TextStyle(
              color: tokens.AppTokens.accent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// End of list indicator
class EndOfListIndicator extends StatelessWidget {
  final String message;

  const EndOfListIndicator({
    super.key,
    this.message = 'You\'ve reached the end',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 1,
            color: tokens.AppTokens.border,
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: const TextStyle(
              color: tokens.AppTokens.textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 1,
            color: tokens.AppTokens.border,
          ),
        ],
      ),
    );
  }
}
