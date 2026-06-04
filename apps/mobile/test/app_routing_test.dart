import 'package:clarity/app/app.dart';
import 'package:clarity/app/app_composition.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/auth/presentation/auth_screen.dart';
import 'package:clarity/features/onboarding/presentation/onboarding_screen.dart';
import 'package:clarity/features/assistant/presentation/assistant_screen.dart';
import 'package:clarity/features/assistant/presentation/assistant_tab.dart';
import 'package:clarity/features/assistant/chat/data/chat_models.dart';
import 'package:clarity/features/assistant/chat/data/conversation_api.dart';
import 'package:clarity/features/assistant/chat/domain/chat_message.dart';
import 'package:clarity/features/assistant/voice/application/voice_call_controller.dart';
import 'package:clarity/features/assistant/voice/domain/voice_call_state.dart';
import 'package:clarity/features/profile/presentation/profile_screen.dart';
import 'package:clarity/features/shell/presentation/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assistant tab contract is stable and ordered', () {
    expect(AssistantTab.values.map((tab) => tab.id), [
      'chat',
      'voice',
      'memory',
      'goals',
      'chats',
    ]);
    expect(AssistantTab.values.map((tab) => tab.label), [
      'Chat',
      'Voice',
      'Knows',
      'Goals',
      'Chats',
    ]);
    expect(AssistantTab.values.map((tab) => tab.semanticLabel), [
      'Assistant Chat tab',
      'Assistant Voice tab',
      'Assistant Knows tab',
      'Assistant Goals tab',
      'Assistant Chats tab',
    ]);
  });

  testWidgets('signed out users see auth screen', (tester) async {
    final app = AppComposition();
    addTearDown(app.dispose);

    await tester.pumpWidget(
      ClarityApp(
        ui: app.ui,
        authController: app.authController,
        profileController: app.profileController,
      ),
    );

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('signed in users without profile see onboarding', (tester) async {
    final app = AppComposition(initialAuthenticated: true);
    addTearDown(app.dispose);

    await tester.pumpWidget(
      ClarityApp(
        ui: app.ui,
        authController: app.authController,
        profileController: app.profileController,
      ),
    );

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('signed in users with complete profile see home shell', (
    tester,
  ) async {
    final app = AppComposition(initialAuthenticated: true);
    addTearDown(app.dispose);
    app.profileController.profile = ProfileRecord(
      id: 'user-1',
      email: 'test@example.com',
      fullName: 'Test User',
      avatarUrl: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      ClarityApp(
        ui: app.ui,
        authController: app.authController,
        profileController: app.profileController,
      ),
    );

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('profile and security actions live in the Profile tab', (
    tester,
  ) async {
    final app = AppComposition(initialAuthenticated: true);
    addTearDown(app.dispose);
    app.profileController.profile = ProfileRecord(
      id: 'user-1',
      email: 'test@example.com',
      fullName: 'Test User',
      avatarUrl: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      ClarityApp(
        ui: app.ui,
        authController: app.authController,
        profileController: app.profileController,
      ),
    );

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Sign out'), findsNothing);

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Account menu'), findsNothing);
    expect(find.text('Multi-factor authentication'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Multi-factor authentication'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets(
    'assistant tab exposes Chat Voice Knows Goals and Chats sections',
    (tester) async {
      final app = AppComposition(initialAuthenticated: true);
      addTearDown(app.dispose);
      app.profileController.profile = ProfileRecord(
        id: 'user-1',
        email: 'test@example.com',
        fullName: 'Test User',
        avatarUrl: null,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      await tester.pumpWidget(
        ClarityApp(
          ui: app.ui,
          authController: app.authController,
          profileController: app.profileController,
        ),
      );

      await tester.tap(find.text('Assistant'));
      await tester.pump();

      expect(find.byType(AssistantScreen), findsOneWidget);
      expect(find.byTooltip('Conversations'), findsNothing);
      expect(find.byTooltip('Knows'), findsNothing);
      expect(find.byTooltip('Accountability'), findsNothing);
      for (final tab in AssistantTab.values) {
        expect(find.byKey(tab.key), findsOneWidget);
        expect(find.text(tab.label), findsOneWidget);
      }
    },
  );

  testWidgets('assistant shared tab nav switches to Chats content', (
    tester,
  ) async {
    final app = AppComposition(initialAuthenticated: true);
    addTearDown(app.dispose);
    app.profileController.profile = ProfileRecord(
      id: 'user-1',
      email: 'test@example.com',
      fullName: 'Test User',
      avatarUrl: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      ClarityApp(
        ui: app.ui,
        authController: app.authController,
        profileController: app.profileController,
      ),
    );

    await tester.tap(find.text('Assistant'));
    await tester.pump();
    await tester.tap(find.byKey(AssistantTab.chats.key));
    await tester.pumpAndSettle();

    expect(find.text('Conversations'), findsOneWidget);
    expect(find.byTooltip('Conversations'), findsNothing);
  });

  testWidgets('assistant preserves chat draft when switching tabs', (
    tester,
  ) async {
    await _pumpAssistantScreen(
      tester,
      conversationApi: _FakeConversationApi.empty(),
    );

    await tester.enterText(find.byType(TextField), 'Draft for Rex');
    await tester.tap(find.byKey(AssistantTab.chats.key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AssistantTab.chat.key));
    await tester.pumpAndSettle();

    expect(find.text('Draft for Rex'), findsOneWidget);
  });

  testWidgets('assistant returns from Chats to selected conversation in Chat', (
    tester,
  ) async {
    await _pumpAssistantScreen(
      tester,
      conversationApi: _FakeConversationApi.withConversation(),
    );

    await tester.tap(find.byKey(AssistantTab.chats.key));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget check-in'));
    await tester.pumpAndSettle();

    expect(find.text('Loaded from history'), findsOneWidget);
    expect(find.text('Conversations'), findsNothing);
  });

  testWidgets(
    'assistant Voice tab opens minimal voice for the active conversation',
    (tester) async {
      final voiceController = _FakeVoiceCallController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationApiProvider.overrideWithValue(
              _FakeConversationApi.withConversation(),
            ),
            voiceCallProvider.overrideWith(() => voiceController),
          ],
          child: const MaterialApp(home: AssistantScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(AssistantTab.chats.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budget check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AssistantTab.voice.key));
      await tester.pumpAndSettle();
      expect(find.text('Tap to speak'), findsOneWidget);

      await tester.tap(find.text('Speak'));
      await tester.pumpAndSettle();

      expect(voiceController.startCount, 1);
      expect(voiceController.lastConversationId, 'conversation-1');
      expect(find.text('Listening...'), findsOneWidget);
    },
  );
}

Future<void> _pumpAssistantScreen(
  WidgetTester tester, {
  required ConversationApi conversationApi,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [conversationApiProvider.overrideWithValue(conversationApi)],
      child: const MaterialApp(home: AssistantScreen()),
    ),
  );
  await tester.pump();
}

class _FakeConversationApi extends ConversationApi {
  _FakeConversationApi({required this.conversations, required this.messages});

  factory _FakeConversationApi.empty() {
    return _FakeConversationApi(conversations: const [], messages: const {});
  }

  factory _FakeConversationApi.withConversation() {
    return _FakeConversationApi(
      conversations: [
        Conversation(
          id: 'conversation-1',
          title: 'Budget check-in',
          timestamp: DateTime.utc(2026, 5, 29),
        ),
      ],
      messages: {
        'conversation-1': [
          ChatMessage(
            id: 'message-1',
            role: ChatMessageRole.assistant,
            content: 'Loaded from history',
            timestamp: DateTime.utc(2026, 5, 29),
          ),
        ],
      },
    );
  }

  final List<Conversation> conversations;
  final Map<String, List<ChatMessage>> messages;

  @override
  Future<List<Conversation>> getConversations() async => conversations;

  @override
  Future<List<ChatMessage>> getConversationMessages(
    String conversationId,
  ) async {
    return messages[conversationId] ?? const [];
  }
}

class _FakeVoiceCallController extends VoiceCallController {
  var startCount = 0;
  String? lastConversationId;

  @override
  VoiceCallState build() => const VoiceCallState();

  @override
  Future<bool> startCall({String? conversationId}) async {
    startCount += 1;
    lastConversationId = conversationId;
    state = VoiceCallState(
      phase: VoiceCallPhase.listening,
      conversationId: conversationId,
      callStartedAt: DateTime.utc(2026, 5, 29),
    );
    return true;
  }
}
