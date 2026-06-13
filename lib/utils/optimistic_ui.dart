import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;

/// Optimistic UI utilities
///
/// Provides patterns for instant UI feedback with background sync.
/// When operations fail, UI reverts with user notification.
class OptimisticUI {
  /// Favorite toggle with optimistic update
  ///
  /// Updates UI instantly, syncs in background, reverts on failure.
  static Future<bool> toggleFavorite(
    BuildContext context, {
    required bool currentFavorite,
    required Future<bool> Function() syncOperation,
    required String itemId,
  }) async {
    // Optimistic update
    final newFavorite = !currentFavorite;

    // Haptic feedback
    HapticFeedback.lightImpact();

    try {
      // Sync in background
      final result = await syncOperation();

      if (result != newFavorite) {
        // Server disagreed, revert
        HapticFeedback.heavyImpact();
        _showRevertToast(context, 'favorite status');
        return currentFavorite;
      }

      return newFavorite;
    } catch (e) {
      // Failed, revert
      HapticFeedback.heavyImpact();
      _showRevertToast(context, 'favorite');
      return currentFavorite;
    }
  }

  /// Mark watched with optimistic update
  ///
  /// Updates UI instantly, syncs silently in background.
  static Future<void> markWatched({
    required Future<void> Function() syncOperation,
  }) async {
    // Optimistic update (instant)
    HapticFeedback.lightImpact();

    try {
      // Sync silently in background
      await syncOperation();
    } catch (e) {
      // Silent failure - already marked as watched
      // No user notification needed for this operation
    }
  }

  /// Add to list with undo snackbar
  ///
  /// Instant update with 3-second undo timeout.
  static void addToListWithUndo(
    BuildContext context, {
    required String itemName,
    required Future<void> Function() syncOperation,
    required VoidCallback onRevert,
  }) {
    // Optimistic update
    HapticFeedback.lightImpact();

    // Show snackbar with undo
    final snackBar = SnackBar(
      content: Text('$itemName added'),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          HapticFeedback.lightImpact();
          onRevert();
        },
      ),
      backgroundColor: tokens.AppTokens.surface2,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    // Sync in background
    syncOperation().catchError((e) {
      // On failure, revert automatically
      HapticFeedback.heavyImpact();
      onRevert();
      _showRevertToast(context, 'list addition');
    });
  }

  /// Settings toggle with optimistic update
  ///
  /// Instant update, syncs silently, reverts on failure.
  static Future<bool> toggleSetting({
    required bool currentValue,
    required Future<bool> Function() syncOperation,
  }) async {
    // Optimistic update
    final newValue = !currentValue;
    HapticFeedback.lightImpact();

    try {
      // Sync silently
      final result = await syncOperation();

      if (result != newValue) {
        // Server disagreed, revert
        HapticFeedback.heavyImpact();
        return currentValue;
      }

      return newValue;
    } catch (e) {
      // Failed, revert
      HapticFeedback.heavyImpact();
      return currentValue;
    }
  }

  /// Show revert toast notification
  static void _showRevertToast(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not update $action'),
        backgroundColor: tokens.AppTokens.danger,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Widget wrapper for optimistic favorite toggle
class OptimisticFavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final Future<bool> Function() onToggle;
  final String itemId;
  final Widget Function(bool isFavorite) iconBuilder;

  const OptimisticFavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    required this.itemId,
    required this.iconBuilder,
  });

  @override
  State<OptimisticFavoriteButton> createState() =>
      _OptimisticFavoriteButtonState();
}

class _OptimisticFavoriteButtonState extends State<OptimisticFavoriteButton> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
  }

  Future<void> _handleToggle() async {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    final result = await OptimisticUI.toggleFavorite(
      context,
      currentFavorite: widget.isFavorite,
      syncOperation: widget.onToggle,
      itemId: widget.itemId,
    );

    setState(() {
      _isFavorite = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleToggle,
      child: widget.iconBuilder(_isFavorite),
    );
  }
}

/// Widget wrapper for optimistic settings toggle
class OptimisticToggle extends StatefulWidget {
  final bool value;
  final Future<bool> Function() onChanged;
  final String label;

  const OptimisticToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  State<OptimisticToggle> createState() => _OptimisticToggleState();
}

class _OptimisticToggleState extends State<OptimisticToggle> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  Future<void> _handleChanged(bool newValue) async {
    setState(() {
      _value = newValue;
    });

    final result = await OptimisticUI.toggleSetting(
      currentValue: widget.value,
      syncOperation: widget.onChanged,
    );

    setState(() {
      _value = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(widget.label),
      value: _value,
      onChanged: _handleChanged,
    );
  }
}
