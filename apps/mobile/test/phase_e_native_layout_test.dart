import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('native Knows/Goals/Overview/Profile gutters match pageGutter', (
    tester,
  ) async {
    expect(kIsWeb, isFalse);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late double pageGutter;
    late EdgeInsets pagePad;
    late EdgeInsets listPad;
    late EdgeInsets cardPad;
    late double sectionGap;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(ClarityNativeLayout.active(context), isTrue);
            pageGutter = ClarityNativeLayout.pageGutter(context);
            pagePad = ClarityNativeLayout.pagePadding(context, top: 8, bottom: 8);
            listPad = ClarityNativeLayout.listRowPadding(context);
            cardPad = ClarityNativeLayout.cardPadding(context);
            sectionGap = ClarityNativeLayout.sectionGap(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(pageGutter, 10);
    expect(pagePad.left, 10);
    expect(pagePad.right, 10);
    expect(listPad.left, 10);
    expect(listPad.top, 8);
    expect(cardPad.left, 12);
    expect(sectionGap, 14);
  });

  testWidgets('wide layout keeps desktop gutters for Phase E surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late double pageGutter;
    late EdgeInsets listPad;
    late EdgeInsets cardPad;
    late bool native;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            native = ClarityNativeLayout.active(context);
            pageGutter = ClarityNativeLayout.pageGutter(context);
            listPad = ClarityNativeLayout.listRowPadding(context);
            cardPad = ClarityNativeLayout.cardPadding(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(native, isFalse);
    expect(pageGutter, 24);
    expect(listPad.left, greaterThan(10));
    expect(cardPad.left, greaterThan(12));
  });
}
