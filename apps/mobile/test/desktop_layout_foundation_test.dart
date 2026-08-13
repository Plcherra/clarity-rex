import 'package:clarity/core/layout/clarity_adaptive_overlay.dart';
import 'package:clarity/core/layout/clarity_breakpoints.dart';
import 'package:clarity/features/shell/presentation/home_shell_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

Future<void> _showAdaptiveOverlay(
  WidgetTester tester, {
  required Size size,
  required Key bodyKey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  late BuildContext overlayContext;
  await tester.pumpWidget(
    wrapWithTestProviders(
      Builder(
        builder: (context) {
          overlayContext = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );

  showClarityAdaptiveOverlay<void>(
    context: overlayContext,
    builder: (_) => SizedBox(
      key: bodyKey,
      height: 120,
      child: const Text('overlay'),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('clarity breakpoints match shell compact and wide bands', () {
    expect(clarityLayoutMediumBreakpoint, homeShellCompactBreakpoint);
    expect(clarityLayoutWideBreakpoint, 1100);
    expect(clarityFinanceContentMaxWidth, 1920);
    expect(clarityAssistantContentMaxWidth, 1920);
    expect(clarityProfileContentMaxWidth, 1920);
    expect(clarityChatColumnMaxWidth, 960);
  });

  testWidgets('isClarityDesktopLayout false below 800 and true at 1280', (
    tester,
  ) async {
    late bool compactDesktop;
    late bool wideDesktop;

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      wrapWithTestProviders(
        Builder(
          builder: (context) {
            compactDesktop = isClarityDesktopLayout(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(compactDesktop, isFalse);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      wrapWithTestProviders(
        Builder(
          builder: (context) {
            wideDesktop = isClarityDesktopLayout(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(wideDesktop, isTrue);
    expect(clarityLayoutSizeOf, isNotNull);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('ShellContentConstraints respects per-surface max width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrapWithTestProviders(
        const ShellContentConstraints(
          maxWidth: clarityProfileContentMaxWidth,
          child: SizedBox(
            key: Key('profile-body'),
            width: double.infinity,
            height: 100,
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(
      find.byKey(const Key('profile-body')),
    );
    expect(box.size.width, lessThanOrEqualTo(clarityProfileContentMaxWidth));
  });

  testWidgets('showClarityAdaptiveOverlay uses dialog at 1280px', (
    tester,
  ) async {
    await _showAdaptiveOverlay(
      tester,
      size: const Size(1280, 800),
      bodyKey: const Key('adaptive-dialog-body'),
    );

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const Key('adaptive-dialog-body')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('showClarityAdaptiveOverlay uses a sheet below 800px', (
    tester,
  ) async {
    await _showAdaptiveOverlay(
      tester,
      size: const Size(390, 844),
      bodyKey: const Key('adaptive-sheet-body'),
    );

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('adaptive-sheet-body')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('adaptive overlay helper is width-only', (tester) async {
    late bool compactUsesDialog;
    late bool desktopUsesDialog;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              compactUsesDialog = clarityAdaptiveOverlayUsesDialog(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(compactUsesDialog, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              desktopUsesDialog = clarityAdaptiveOverlayUsesDialog(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(desktopUsesDialog, isTrue);
  });

  testWidgets('HomeShellAdaptiveScaffold dock remains at 1920px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
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
            key: Key('shell-body-1920'),
            color: Colors.red,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsNothing);
    final bodyBox = tester.renderObject<RenderBox>(
      find.byKey(const Key('shell-body-1920')),
    );
    expect(bodyBox.size.height, greaterThan(600));
    final dockBox = tester.renderObject<RenderBox>(find.byType(NavigationBar));
    expect(dockBox.size.width, lessThanOrEqualTo(homeShellDockMaxWidth));
  });
}
