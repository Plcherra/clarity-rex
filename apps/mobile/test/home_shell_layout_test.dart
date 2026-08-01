import 'package:clarity/core/layout/clarity_breakpoints.dart';
import 'package:clarity/features/shell/presentation/home_shell_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  test('isHomeShellCompactWidth respects 800px breakpoint', () {
    expect(homeShellCompactBreakpoint, 800);
    expect(homeShellMaxContentWidth, clarityFinanceContentMaxWidth);
    expect(homeShellDockMaxWidth, 600);
  });

  testWidgets('HomeShellAdaptiveScaffold uses centered dock at 1280px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrapWithTestProviders(
        HomeShellAdaptiveScaffold(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
          body: const ColoredBox(
            key: Key('shell-body'),
            color: Colors.red,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 2);
    final dockBox = tester.renderObject<RenderBox>(find.byType(NavigationBar));
    expect(dockBox.size.width, lessThanOrEqualTo(homeShellDockMaxWidth));
    // Dock must not consume the scaffold body (was a full-height Align bug).
    final bodyBox = tester.renderObject<RenderBox>(
      find.byKey(const Key('shell-body')),
    );
    expect(bodyBox.size.height, greaterThan(400));
  });

  testWidgets(
    'HomeShellAdaptiveScaffold uses full-width bottom nav below 800px',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithTestProviders(
          HomeShellAdaptiveScaffold(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
            ],
            body: const Placeholder(),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      final barBox = tester.renderObject<RenderBox>(find.byType(NavigationBar));
      // Full-bleed bar matches the compact viewport (not the centered dock).
      expect(barBox.size.width, closeTo(390, 1));
    },
  );

  testWidgets(
    'FinanceContentConstraints caps child width on ultra-wide screens',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const key = Key('finance-child');
      await tester.pumpWidget(
        const MaterialApp(
          home: FinanceContentConstraints(
            child: SizedBox(key: key, width: double.infinity, height: 100),
          ),
        ),
      );

      final box = tester.renderObject<RenderBox>(find.byKey(key));
      // Clamp to viewport minus gutters when preferred max exceeds available width.
      expect(
        box.size.width,
        clarityClampedContentWidth(
          tester.element(find.byKey(key)),
          homeShellMaxContentWidth,
        ),
      );
    },
  );
}
