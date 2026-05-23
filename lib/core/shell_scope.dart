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
    return scope!;
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey;
}
