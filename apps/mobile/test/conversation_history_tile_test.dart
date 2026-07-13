import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/presentation/pages/conversation_list_chrome.dart';
import 'package:clarity/rex/chat/presentation/widgets/conversation_history_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  test('conversationTitle prefers stored title over message preview', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final conversation = Conversation(
      id: 'c1',
      title: 'Budget check-in',
      timestamp: DateTime.utc(2026, 7, 11),
      lastMessage: ChatApiMessage(
        id: 'm1',
        conversationId: 'c1',
        role: 'user',
        content: 'Can we talk about rent?',
        timestamp: DateTime.utc(2026, 7, 11),
      ),
    );

    expect(conversationTitle(l10n, conversation), 'Budget check-in');
  });

  test('clampConversationTitle hard-caps long titles', () {
    final long =
        'This is a very long conversation title that should not crowd the sidebar forever and ever';
    final capped = clampConversationTitle(long);
    expect(capped.length, lessThanOrEqualTo(kConversationTitleMaxLength));
    expect(capped.endsWith('…'), isTrue);
  });

  test('clampConversationTitle can omit ellipsis for phone display', () {
    final long =
        'This is a very long conversation title that should not crowd the sidebar forever and ever';
    final capped = clampConversationTitle(long, maxLength: 28, ellipsis: false);
    expect(capped.length, lessThanOrEqualTo(28));
    expect(capped.endsWith('…'), isFalse);
  });

  test('clampConversationTitle respects native listTitleMaxChars', () {
    final long =
        'This is a very long conversation title that should not crowd the sidebar forever and ever';
    final capped = clampConversationTitle(long, maxLength: 28);
    expect(capped.length, lessThanOrEqualTo(28));
    expect(capped.endsWith('…'), isTrue);
  });

  testWidgets('compact sidebar tile shows title without preview body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final conversation = Conversation(
      id: 'c1',
      title: 'Night routine',
      timestamp: DateTime.utc(2026, 7, 11, 16, 53),
      lastMessage: ChatApiMessage(
        id: 'm1',
        conversationId: 'c1',
        role: 'user',
        content: 'Help me think through tonight.',
        timestamp: DateTime.utc(2026, 7, 11, 16, 53),
      ),
    );

    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: ConversationHistoryTile(
            conversation: conversation,
            isSelected: true,
            compact: true,
            onTap: () {},
            onDelete: () {},
            onRename: () {},
          ),
        ),
      ),
    );

    expect(find.text('Night routine'), findsOneWidget);
    expect(find.text('Help me think through tonight.'), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(ConversationHistoryTile)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
  });

  testWidgets('native compact tile is title-only dense, no glyph', (
    tester,
  ) async {
    expect(kIsWeb, isFalse);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final conversation = Conversation(
      id: 'c1',
      title: 'Night routine',
      timestamp: DateTime.utc(2026, 7, 11, 16, 53),
      lastMessage: ChatApiMessage(
        id: 'm1',
        conversationId: 'c1',
        role: 'user',
        content: 'Help me think through tonight.',
        timestamp: DateTime.utc(2026, 7, 11, 16, 53),
      ),
    );

    late int titleMaxChars;
    late int previewMaxLines;
    late double listPadH;

    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: Builder(
            builder: (context) {
              expect(ClarityNativeLayout.active(context), isTrue);
              titleMaxChars = ClarityNativeLayout.listTitleMaxChars(context);
              previewMaxLines = ClarityNativeLayout.listPreviewMaxLines(context);
              listPadH = ClarityNativeLayout.listRowPadding(context).left;
              return ConversationHistoryTile(
                conversation: conversation,
                isSelected: false,
                compact: false,
                onTap: () {},
                onDelete: () {},
                onRename: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(titleMaxChars, 28);
    expect(previewMaxLines, 0);
    expect(listPadH, 10);
    expect(find.text('Night routine'), findsOneWidget);
    expect(find.text('Help me think through tonight.'), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
  });

  testWidgets('wide card tile keeps glyph and two-line preview', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final conversation = Conversation(
      id: 'c1',
      title: 'Night routine',
      timestamp: DateTime.utc(2026, 7, 11, 16, 53),
      lastMessage: ChatApiMessage(
        id: 'm1',
        conversationId: 'c1',
        role: 'user',
        content: 'Help me think through tonight.',
        timestamp: DateTime.utc(2026, 7, 11, 16, 53),
      ),
    );

    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: ConversationHistoryTile(
            conversation: conversation,
            isSelected: false,
            compact: false,
            onTap: () {},
            onDelete: () {},
            onRename: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.text('Help me think through tonight.'), findsOneWidget);
    final preview = tester.widget<Text>(
      find.text('Help me think through tonight.'),
    );
    expect(preview.maxLines, 2);
  });

  testWidgets('native search inset matches list row horizontal padding', (
    tester,
  ) async {
    expect(kIsWeb, isFalse);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late double searchInset;
    late double listPadH;

    await tester.pumpWidget(
      wrapWithL10n(
        Builder(
          builder: (context) {
            searchInset = conversationListHorizontalInset(
              context,
              compactSidebar: false,
            );
            listPadH = ClarityNativeLayout.listRowPadding(context).left;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(searchInset, listPadH);
    expect(searchInset, 10);
  });
}
