import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/provider/app_provider.dart';
import 'package:lumio_tv/provider/user_state_provider.dart';
import 'package:lumio_tv/widgets/shell_app_bar.dart';
import 'package:provider/provider.dart';

Widget _wrapShellAppBar({
  required double width,
  required Widget child,
}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, 800)),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserStateProvider()),
        ChangeNotifierProvider(
          create: (ctx) => AppProvider(ctx.read<UserStateProvider>()),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets('ShellAppBar no overflow at 320px width', (tester) async {
    await tester.pumpWidget(
      _wrapShellAppBar(
        width: 320,
        child: const ShellAppBar(centerLumioTvBrand: true),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Favourites header no vertical overflow at 320px', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 640)),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserStateProvider()),
            ChangeNotifierProvider(
              create: (ctx) => AppProvider(ctx.read<UserStateProvider>()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ShellAppBar(
                    showBack: true,
                    title: 'Favourites',
                    subtitle: 'Long subtitle that should wrap without blowing layout',
                  ),
                  Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShellAppBar no overflow with back title at 360px', (tester) async {
    await tester.pumpWidget(
      _wrapShellAppBar(
        width: 360,
        child: const ShellAppBar(
          showBack: true,
          title: 'Very Long Channel Category Name That Should Ellipsize',
          subtitle: 'Subtitle line that must not blow out the app bar layout',
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
