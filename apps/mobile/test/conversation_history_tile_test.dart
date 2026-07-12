import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/presentation/widgets/conversation_history_widgets.dart';
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

  testWidgets('compact conversation tile shows title without preview body', (
    tester,
  ) async {
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
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(ConversationHistoryTile)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
  });
}
