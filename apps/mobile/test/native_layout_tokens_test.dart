import 'package:clarity/core/layout/clarity_breakpoints.dart';
import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/core/layout/finance_content_constraints.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shellContentGutterFor is 0 only when native compact', () {
    expect(
      ClarityNativeLayout.shellContentGutterFor(nativeCompact: true),
      0.0,
    );
    // Narrow web / wide: same desktop gutter — gate is !kIsWeb, not width alone.
    expect(
      ClarityNativeLayout.shellContentGutterFor(nativeCompact: false),
      clarityDesktopContentGutter,
    );
  });

  testWidgets('native compact: shell gutter 0 and content ≈ viewport', (
    tester,
  ) async {
    const viewport = Size(390, 844);
    late double gutter;
    late double clamped;
    late bool active;
    late bool rexNative;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: viewport),
          child: Builder(
            builder: (context) {
              active = ClarityNativeLayout.active(context);
              rexNative = RexUiTokens.isNativeCompactChrome(context);
              gutter = ClarityNativeLayout.shellContentGutter(context);
              clamped = clarityClampedContentWidth(
                context,
                homeShellMaxContentWidth,
                gutter: gutter,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // VM / device tests are non-web; phone width activates native compact.
    expect(kIsWeb, isFalse);
    expect(active, isTrue);
    expect(rexNative, isTrue);
    expect(gutter, 0.0);
    expect(clamped, closeTo(viewport.width, 0.5));
  });

  testWidgets('native compact ShellContentConstraints is full-bleed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const key = Key('shell-child');
    await tester.pumpWidget(
      const MaterialApp(
        home: ShellContentConstraints(
          child: SizedBox(key: key, width: double.infinity, height: 80),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byKey(key));
    expect(box.size.width, closeTo(390, 0.5));
  });

  testWidgets('wide layout keeps 24px shell gutter and clamp', (tester) async {
    const viewport = Size(1280, 900);
    late double gutter;
    late double clamped;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: viewport),
          child: Builder(
            builder: (context) {
              expect(ClarityNativeLayout.active(context), isFalse);
              expect(RexUiTokens.isNativeCompactChrome(context), isFalse);
              gutter = ClarityNativeLayout.shellContentGutter(context);
              clamped = clarityClampedContentWidth(
                context,
                homeShellMaxContentWidth,
                gutter: gutter,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(gutter, clarityDesktopContentGutter);
    expect(clamped, viewport.width - clarityDesktopContentGutter * 2);
  });

  testWidgets('wide ShellContentConstraints unchanged at 1280', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const key = Key('wide-shell-child');
    await tester.pumpWidget(
      const MaterialApp(
        home: ShellContentConstraints(
          child: SizedBox(key: key, width: double.infinity, height: 80),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byKey(key));
    expect(
      box.size.width,
      closeTo(1280 - clarityDesktopContentGutter * 2, 0.5),
    );
  });

  testWidgets(
    'compact chrome without native gate keeps desktop shell gutter math',
    (tester) async {
      // Simulates narrow web: width < 800 but nativeCompact == false.
      const viewport = Size(390, 844);
      late double compactChromeGutter;
      late double clamped;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: viewport),
            child: Builder(
              builder: (context) {
                expect(RexUiTokens.isCompactChrome(context), isTrue);
                compactChromeGutter = ClarityNativeLayout.shellContentGutterFor(
                  nativeCompact: false,
                );
                clamped = clarityClampedContentWidth(
                  context,
                  homeShellMaxContentWidth,
                  gutter: compactChromeGutter,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(compactChromeGutter, clarityDesktopContentGutter);
      expect(clamped, viewport.width - clarityDesktopContentGutter * 2);
    },
  );

  testWidgets('native layout page helpers only densify when active', (
    tester,
  ) async {
    late double pageGutterNative;
    late double pageGutterWide;
    late int titleCharsNative;
    late int previewLinesNative;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              pageGutterNative = ClarityNativeLayout.pageGutter(context);
              titleCharsNative = ClarityNativeLayout.listTitleMaxChars(context);
              previewLinesNative =
                  ClarityNativeLayout.listPreviewMaxLines(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              pageGutterWide = ClarityNativeLayout.pageGutter(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(pageGutterNative, 10);
    expect(pageGutterWide, clarityDesktopContentGutter);
    expect(titleCharsNative, 28);
    expect(previewLinesNative, 0);
  });
}
