import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('confirm title field uses bodyMedium weight on compact', (
    tester,
  ) async {
    late TextStyle? titleStyle;
    late double cardPadding;
    late double buttonHeight;
    late bool compact;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              compact = RexUiTokens.isCompactChrome(context);
              titleStyle = RexUiTokens.confirmTitleFieldStyle(context);
              cardPadding = RexUiTokens.confirmCardPaddingOf(context);
              buttonHeight = RexUiTokens.confirmButtonHeightOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(compact, isTrue);
    expect(cardPadding, ClaritySpacing.sm);
    expect(buttonHeight, 36.0);
    expect(titleStyle?.fontWeight, FontWeight.w600);
    expect(titleStyle?.fontSize, lessThan(20));
  });

  testWidgets('wide layout keeps roomier confirm defaults', (tester) async {
    late double cardPadding;
    late double buttonHeight;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              cardPadding = RexUiTokens.confirmCardPaddingOf(context);
              buttonHeight = RexUiTokens.confirmButtonHeightOf(context);
              expect(RexUiTokens.isCompactChrome(context), isFalse);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(cardPadding, RexUiTokens.confirmCardPadding);
    expect(buttonHeight, RexUiTokens.confirmButtonHeight);
  });
}
