import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/widgets/main_shell_bottom_nav.dart';

void main() {
  testWidgets('MainShellBottomNav no overflow at 360x640', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 640)),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MainShellBottomNav(
              currentIndex: 0,
              onTap: (_) {},
              liveChannelCount: 12,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('MainShellBottomNav no overflow at 320px width', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 640)),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MainShellBottomNav(
              currentIndex: 2,
              onTap: (_) {},
              liveChannelCount: 99,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
