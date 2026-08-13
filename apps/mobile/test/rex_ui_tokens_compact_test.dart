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

  testWidgets('native compact tokens prefer phone chrome', (tester) async {
    late bool nativeCompact;
    late double bubbleInset;
    late bool showTitle;
    late bool showScrollbar;
    late bool filledComposer;
    late bool autoDialog;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              nativeCompact = RexUiTokens.isNativeCompactChrome(context);
              bubbleInset = RexUiTokens.bubbleSideInsetOf(context);
              showTitle = RexUiTokens.showsAssistantPageTitle(context);
              showScrollbar = RexUiTokens.showsTranscriptScrollbar(context);
              filledComposer = RexUiTokens.usesFilledComposerField(context);
              autoDialog = RexUiTokens.autoOpensConfirmDialog(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(nativeCompact, isTrue);
    expect(bubbleInset, RexUiTokens.bubbleSideInsetNativeCompact);
    expect(showTitle, isFalse);
    expect(showScrollbar, isFalse);
    expect(filledComposer, isFalse);
    expect(autoDialog, isFalse);
  });

  testWidgets('native composer tokens raise type height without fill', (
    tester,
  ) async {
    late bool filledComposer;
    late double fieldPadV;
    late double chromePadH;
    late double minHeight;
    late double transcriptPadH;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              filledComposer = RexUiTokens.usesFilledComposerField(context);
              fieldPadV = RexUiTokens.composerFieldPaddingVOf(context);
              chromePadH = RexUiTokens.composerPaddingHOf(context);
              minHeight = RexUiTokens.composerFieldMinHeightOf(context);
              transcriptPadH = RexUiTokens.transcriptPaddingHOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(filledComposer, isFalse);
    expect(fieldPadV, 10);
    expect(chromePadH, 10);
    expect(minHeight, greaterThanOrEqualTo(44));
    expect(transcriptPadH, 10);
  });

  testWidgets('wide composer padding tokens stay unchanged', (tester) async {
    late bool filledComposer;
    late double fieldPadV;
    late double chromePadH;
    late double transcriptPadH;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              filledComposer = RexUiTokens.usesFilledComposerField(context);
              fieldPadV = RexUiTokens.composerFieldPaddingVOf(context);
              chromePadH = RexUiTokens.composerPaddingHOf(context);
              transcriptPadH = RexUiTokens.transcriptPaddingHOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(filledComposer, isFalse);
    expect(fieldPadV, RexUiTokens.composerFieldPaddingV);
    expect(chromePadH, RexUiTokens.composerPaddingH);
    expect(transcriptPadH, RexUiTokens.space16);
  });

  testWidgets('wide layout keeps web-style assistant title and bubble inset', (
    tester,
  ) async {
    late double bubbleInset;
    late bool showTitle;
    late bool autoDialog;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              bubbleInset = RexUiTokens.bubbleSideInsetOf(context);
              showTitle = RexUiTokens.showsAssistantPageTitle(context);
              autoDialog = RexUiTokens.autoOpensConfirmDialog(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(bubbleInset, RexUiTokens.bubbleSideInset);
    expect(showTitle, isTrue);
    expect(autoDialog, isFalse);
  });

  testWidgets('compact width never auto-opens the confirm dialog', (
    tester,
  ) async {
    late bool autoDialog;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              autoDialog = RexUiTokens.autoOpensConfirmDialog(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(autoDialog, isFalse);
  });

  testWidgets('medium desktop still auto-opens the confirm dialog', (
    tester,
  ) async {
    late bool autoDialog;
    late bool nativeCompact;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(900, 800)),
          child: Builder(
            builder: (context) {
              nativeCompact = RexUiTokens.isNativeCompactChrome(context);
              autoDialog = RexUiTokens.autoOpensConfirmDialog(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(nativeCompact, isFalse);
    expect(autoDialog, isTrue);
  });
}
