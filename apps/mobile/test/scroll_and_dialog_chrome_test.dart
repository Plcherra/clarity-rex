import 'package:clarity/core/layout/clarity_scroll_behavior.dart';
import 'package:clarity/core/layout/web_centered_dialog.dart';
import 'package:clarity/theme/clarity_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact scrollbar theme is thin and auto-hiding', () {
    final scheme = ClarityTheme.dark().colorScheme;
    final theme = clarityScrollbarTheme(scheme, desktop: false);

    expect(theme.thumbVisibility?.resolve(const {}), isFalse);
    expect(theme.thickness?.resolve(const {}), 4.0);
  });

  test('desktop scrollbar theme keeps a visible 8px thumb', () {
    final scheme = ClarityTheme.dark().colorScheme;
    final theme = clarityScrollbarTheme(scheme, desktop: true);

    expect(theme.thumbVisibility?.resolve(const {}), isTrue);
    expect(theme.thickness?.resolve(const {}), 8.0);
  });

  testWidgets('compact width uses bouncing physics and thin scrollbar tokens', (
    tester,
  ) async {
    late ScrollPhysics physics;
    late ScrollbarThemeData scrollbar;
    late bool desktopChrome;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              desktopChrome = clarityScrollUsesDesktopChrome(context);
              physics = clarityScrollPhysics(context);
              scrollbar = clarityScrollbarThemeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(desktopChrome, isFalse);
    expect(physics, isA<BouncingScrollPhysics>());
    expect(scrollbar.thickness?.resolve(const {}), 4.0);
  });

  testWidgets('desktop width uses clamping physics and a visible thumb', (
    tester,
  ) async {
    late ScrollPhysics physics;
    late ScrollbarThemeData scrollbar;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              physics = clarityScrollPhysics(context);
              scrollbar = clarityScrollbarThemeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(physics, isA<ClampingScrollPhysics>());
    expect(scrollbar.thumbVisibility?.resolve(const {}), isTrue);
    expect(scrollbar.thickness?.resolve(const {}), 8.0);
  });

  testWidgets('compact wrapWebCenteredDialog does not extra-constrain the child', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              return wrapWebCenteredDialog(
                context,
                const Text('dialog-body'),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('dialog-body'), findsOneWidget);
    expect(_hasCenteredDialogConstraint(tester), isFalse);
  });

  testWidgets('desktop wrapWebCenteredDialog centers and constrains', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              return wrapWebCenteredDialog(
                context,
                const Text('dialog-body'),
                maxWidth: 420,
                maxHeight: 560,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('dialog-body'), findsOneWidget);
    expect(_hasCenteredDialogConstraint(tester), isTrue);
    expect(
      find.ancestor(
        of: find.text('dialog-body'),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );
  });
}

bool _hasCenteredDialogConstraint(WidgetTester tester) {
  return tester
      .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
      .any(
        (box) =>
            box.constraints.maxWidth == 420 && box.constraints.maxHeight == 560,
      );
}
