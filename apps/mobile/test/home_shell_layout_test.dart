import 'package:clarity/core/layout/finance_content_constraints.dart';
import 'package:clarity/features/shell/presentation/home_shell_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  test('isHomeShellCompactWidth respects 800px breakpoint', () {
    expect(homeShellCompactBreakpoint, 800);
    expect(homeShellMaxContentWidth, greaterThanOrEqualTo(1200));
    expect(homeShellMaxContentWidth, lessThanOrEqualTo(1400));
  });

  testWidgets('HomeShellAdaptiveScaffold uses NavigationRail at 1280px', (
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
          railDestinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home),
              label: Text('Home'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person),
              label: Text('Profile'),
            ),
          ],
          body: const Placeholder(),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('HomeShellAdaptiveScaffold uses bottom nav below 800px', (
    tester,
  ) async {
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
          railDestinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home),
              label: Text('Home'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person),
              label: Text('Profile'),
            ),
          ],
          body: const Placeholder(),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('FinanceContentConstraints caps child width on ultra-wide screens', (
    tester,
  ) async {
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
    expect(box.size.width, homeShellMaxContentWidth);
  });
}
