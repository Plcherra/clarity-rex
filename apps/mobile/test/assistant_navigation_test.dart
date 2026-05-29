import 'package:clarity/features/assistant/chat/data/chat_models.dart';
import 'package:clarity/features/assistant/chat/data/conversation_api.dart';
import 'package:clarity/features/assistant/chat/domain/chat_message.dart';
import 'package:clarity/features/assistant/presentation/assistant_screen.dart';
import 'package:clarity/features/assistant/presentation/assistant_tab.dart';
import 'package:clarity/features/assistant/voice/application/voice_call_controller.dart';
import 'package:clarity/features/assistant/voice/domain/voice_call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Assistant navigation renders the five tabs in contract order', (
    tester,
  ) async {
    await _pumpAssistantNavigation(tester);

    final tabs = tester.widgetList<Tab>(find.byType(Tab)).toList();

    expect(
      tabs.map((tab) => tab.key),
      AssistantTab.values.map((tab) => tab.key),
    );
    expect(
      tabs.map((tab) => tab.text),
      AssistantTab.values.map((tab) => tab.label),
    );
    for (final (index, tab) in tabs.indexed) {
      final icon = tab.icon;
      expect(icon, isA<Semantics>());
      expect(
        (icon! as Semantics).properties.label,
        AssistantTab.values[index].semanticLabel,
      );
    }
  });

  testWidgets('Assistant navigation changes selected tab for every section', (
    tester,
  ) async {
    final voiceController = _FakeVoiceCallController();
    await _pumpAssistantNavigation(tester, voiceController: voiceController);

    TabController controller() {
      return tester.widget<TabBar>(find.byType(TabBar)).controller!;
    }

    expect(controller().index, AssistantTab.chat.index);

    for (final tab in AssistantTab.values) {
      await tester.tap(find.byKey(tab.key));
      await tester.pumpAndSettle();

      expect(controller().index, tab.index);
    }

    expect(voiceController.startCount, 1);
  });

  testWidgets(
    'Assistant navigation keeps Chats as a tab, not a header action',
    (tester) async {
      await _pumpAssistantNavigation(tester);

      expect(find.byKey(AssistantTab.chats.key), findsOneWidget);
      expect(find.byTooltip('Conversations'), findsNothing);

      await tester.tap(find.byKey(AssistantTab.chats.key));
      await tester.pumpAndSettle();

      expect(find.text('Conversations'), findsOneWidget);
      expect(find.byTooltip('Conversations'), findsNothing);
    },
  );

  testWidgets('Assistant navigation excludes unrelated global actions', (
    tester,
  ) async {
    await _pumpAssistantNavigation(tester);

    expect(find.byTooltip('Sign out'), findsNothing);
    expect(find.byTooltip('Account menu'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}

Future<void> _pumpAssistantNavigation(
  WidgetTester tester, {
  _FakeVoiceCallController? voiceController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationApiProvider.overrideWithValue(_FakeConversationApi()),
        if (voiceController != null)
          voiceCallProvider.overrideWith(() => voiceController),
      ],
      child: const MaterialApp(home: AssistantScreen()),
    ),
  );
  await tester.pump();
}

class _FakeConversationApi extends ConversationApi {
  @override
  Future<List<Conversation>> getConversations() async => const [];

  @override
  Future<List<ChatMessage>> getConversationMessages(
    String conversationId,
  ) async {
    return const [];
  }
}

class _FakeVoiceCallController extends VoiceCallController {
  var startCount = 0;

  @override
  VoiceCallState build() => const VoiceCallState();

  @override
  Future<bool> startCall({String? conversationId}) async {
    startCount += 1;
    state = VoiceCallState(
      phase: VoiceCallPhase.listening,
      conversationId: conversationId,
      callStartedAt: DateTime.utc(2026, 5, 29),
    );
    return true;
  }
}
