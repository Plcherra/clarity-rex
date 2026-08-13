@TestOn('browser')
library;

import 'package:clarity/core/layout/clarity_breakpoints.dart';
import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/core/layout/finance_content_constraints.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'narrow web compact gets native full-bleed shell gutter',
    (tester) async {
      expect(kIsWeb, isTrue);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late double gutter;
      late bool active;
      late bool compact;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              compact = RexUiTokens.isCompactChrome(context);
              active = ClarityNativeLayout.active(context);
              gutter = ClarityNativeLayout.shellContentGutter(context);
              return const ShellContentConstraints(
                child: SizedBox(
                  key: Key('narrow-web-child'),
                  width: double.infinity,
                  height: 80,
                ),
              );
            },
          ),
        ),
      );

      expect(compact, isTrue);
      expect(active, isTrue);
      expect(
        RexUiTokens.isNativeCompactChrome(
          tester.element(find.byType(ShellContentConstraints)),
        ),
        isTrue,
      );
      expect(
        RexUiTokens.autoOpensConfirmDialog(
          tester.element(find.byType(ShellContentConstraints)),
        ),
        isFalse,
      );
      expect(gutter, 0.0);

      final box = tester.renderObject<RenderBox>(
        find.byKey(const Key('narrow-web-child')),
      );
      expect(box.size.width, closeTo(390, 0.5));
    },
  );

  testWidgets(
    'wide web keeps desktop shell gutter',
    (tester) async {
      expect(kIsWeb, isTrue);

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late double gutter;
      late bool active;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              active = ClarityNativeLayout.active(context);
              gutter = ClarityNativeLayout.shellContentGutter(context);
              return const ShellContentConstraints(
                child: SizedBox(
                  key: Key('wide-web-child'),
                  width: double.infinity,
                  height: 80,
                ),
              );
            },
          ),
        ),
      );

      expect(active, isFalse);
      expect(gutter, clarityDesktopContentGutter);

      final box = tester.renderObject<RenderBox>(
        find.byKey(const Key('wide-web-child')),
      );
      expect(
        box.size.width,
        closeTo(1280 - clarityDesktopContentGutter * 2, 0.5),
      );
    },
  );
}
