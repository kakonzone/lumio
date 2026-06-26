import 'package:flutter/material.dart';

/// Exposes the root [MainShell] scaffold actions to nested screens (e.g. TV home).
class ShellScope extends InheritedWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback openDrawer;
  const ShellScope({
    super.key,
    required this.scaffoldKey,
    required this.openDrawer,
    required super.child,
  });

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  static ShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ShellScope not found above $context');
    if (scope == null) {
      throw FlutterError(
        'ShellScope not found in widget tree.\n'
        'Ensure ShellScope wraps the widget calling ShellScope.of().\n'
        'Offending widget: ${context.widget.runtimeType}',
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey ||
      openDrawer != oldWidget.openDrawer;
}
