import 'package:clarity/core/layout/clarity_breakpoints.dart';
import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/theme/clarity_radius.dart';
import 'package:clarity/theme/clarity_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('native finance page gutter is 10; wide keeps desktop tokens', (
    tester,
  ) async {
    late double nativeGutter;
    late double wideGutter;
    late EdgeInsets nativeCardPad;
    late double nativeRadius;
    late double wideRadius;
    late double nativeSectionGap;
    late double wideSectionGap;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              expect(ClarityNativeLayout.active(context), isTrue);
              nativeGutter = ClarityNativeLayout.pageGutter(context);
              nativeCardPad = ClarityNativeLayout.cardPadding(context);
              nativeRadius = ClarityNativeLayout.cardRadius(context);
              nativeSectionGap = ClarityNativeLayout.sectionGap(context);
              expect(ClarityNativeLayout.moduleEdgeInset(context), 0);
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
              expect(ClarityNativeLayout.active(context), isFalse);
              wideGutter = ClarityNativeLayout.pageGutter(context);
              wideRadius = ClarityNativeLayout.cardRadius(context);
              wideSectionGap = ClarityNativeLayout.sectionGap(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(nativeGutter, 10);
    expect(wideGutter, clarityDesktopContentGutter);
    expect(nativeCardPad, const EdgeInsets.all(12));
    expect(nativeRadius, ClarityRadius.medium);
    expect(wideRadius, ClarityRadius.card);
    expect(nativeSectionGap, 14);
    expect(wideSectionGap, ClaritySpacing.xl);
  });

  test('inactive nativeCompact keeps desktop shell gutter for finance paths', () {
    expect(
      ClarityNativeLayout.shellContentGutterFor(nativeCompact: false),
      clarityDesktopContentGutter,
    );
    expect(
      ClarityNativeLayout.shellContentGutterFor(nativeCompact: true),
      0.0,
    );
  });
}
