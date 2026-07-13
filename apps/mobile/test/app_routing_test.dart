import 'package:clarity/rex/chat/application/chat_action_result_formatter.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/app/app.dart';
import 'package:clarity/app/app_composition.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/auth/presentation/auth_screen.dart';
import 'package:clarity/features/onboarding/presentation/onboarding_screen.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/features/profile/presentation/profile_screen.dart';
import 'package:clarity/features/shell/presentation/home_shell.dart';
import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/presentation/assistant_screen.dart';
import 'package:clarity/rex/presentation/assistant_tab.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/voice/application/voice_call_controller.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/assistant_test_harness.dart';
import 'helpers/l10n_test_wrapper.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
  });

  test('assistant tab contract is stable and ordered', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(AssistantTab.values.map((tab) => tab.id), [
      'chats',
      'chat',
      'memory',
      'goals',
      'overview',
    ]);
    expect(AssistantTab.values.map((tab) => tab.label(l10n)), [
      'Chats',
      'Chat',
      'Knows',
      'Goals',
      'Overview',
    ]);
    expect(AssistantTab.values.map((tab) => tab.semanticLabel(l10n)), [
      'Assistant Chats tab',
      'Assistant Chat tab',
      'Assistant Knows tab',
      'Assistant Goals tab',
      'Assistant Overview tab',
    ]);
    expect(
      assistantTabsForLayout(compact: true).map((tab) => tab.id),
      ['chats', 'chat', 'memory', 'goals', 'overview'],
    );
    expect(
      assistantTabsForLayout(compact: false).map((tab) => tab.id),
      ['chat', 'memory', 'goals', 'overview'],
    );
  });

  testWidgets('signed out users see auth screen', (tester) async {
    final app = AppComposition();
    addTearDown(app.dispose);

    await tester.pumpWidget(
      ClarityApp(
        ui: app.ui,
        authController: app.authController,
        profileController: app.profileController,
        themeModeController: app.themeModeController,
        localeController: app.localeController,
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
        themeModeController: app.themeModeController,
        localeController: app.localeController,
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
        themeModeController: app.themeModeController,
        localeController: app.localeController,
      ),
    );

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('signed in home shell settles without provider errors', (
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
        themeModeController: app.themeModeController,
        localeController: app.localeController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

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
        themeModeController: app.themeModeController,
        localeController: app.localeController,
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
    expect(find.text('Voice usage'), findsOneWidget);
    expect(
      find.textContaining('Minutes today, this week, and this month'),
      findsOneWidget,
    );
    expect(find.text('Appearance'), findsNWidgets(2));
    expect(find.text('Dark'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsNWidgets(2));
    expect(find.text('English'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sign out'), 120);
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('assistant tab exposes Chat Knows Goals and Overview sections', (
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
        themeModeController: app.themeModeController,
        localeController: app.localeController,
      ),
    );

    await tester.tap(find.byIcon(Icons.psychology_alt_outlined));
    await tester.pump();

    expect(find.byType(AssistantScreen), findsOneWidget);
    expect(find.byTooltip('Conversations'), findsNothing);
    expect(find.byTooltip('Knows'), findsNothing);
    expect(find.byTooltip('Accountability'), findsNothing);
    // Default test surface is desktop-width: no compact Chats sub-tab.
    for (final tab in assistantTabsForLayout(compact: false)) {
      expect(find.byKey(tab.key), findsOneWidget);
      expect(
        find.text(tab.label(lookupAppLocalizations(const Locale('en')))),
        findsOneWidget,
      );
    }
    expect(find.byKey(AssistantTab.chats.key), findsNothing);
    expect(find.text('Voice'), findsNothing);
  });

  testWidgets('assistant shared tab nav exposes Overview instead of Chats', (
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
        themeModeController: app.themeModeController,
        localeController: app.localeController,
      ),
    );

    await tester.tap(find.byIcon(Icons.psychology_alt_outlined));
    await tester.pump();

    expect(find.byKey(AssistantTab.overview.key), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('assistant-tab-chats')), findsNothing);
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
    await tester.tap(find.byKey(AssistantTab.overview.key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AssistantTab.chat.key));
    await tester.pumpAndSettle();

    expect(find.text('Draft for Rex'), findsOneWidget);
  });

  testWidgets(
    'assistant returns from chat history to selected conversation in Chat',
    (tester) async {
      await _pumpAssistantScreen(
        tester,
        conversationApi: _FakeConversationApi.withConversation(),
      );

      await tester.tap(find.byKey(AssistantTab.overview.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse chats'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budget check-in'));
      await tester.pumpAndSettle();

      expect(find.text('Loaded from history'), findsOneWidget);
      expect(find.text('Conversations'), findsNothing);
    },
  );

  testWidgets('assistant chat mic starts voice for the active conversation', (
    tester,
  ) async {
    final voiceController = _FakeVoiceCallController();
    final harness = AssistantTestHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationApiProvider.overrideWithValue(
            _FakeConversationApi.withConversation(),
          ),
          voiceCallProvider.overrideWith(() => voiceController),
          localeControllerProvider.overrideWithValue(harness.localeController),
          actionResultMessageFormatterProvider.overrideWith(
            (ref) {
              final l10n = lookupAppLocalizations(const Locale('en'));
              return (action, result) =>
                  actionResultMessage(l10n, action, result);
            },
          ),
        ],
        child: wrapWithL10n(
          AssistantScreen(profileController: harness.profileController),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(AssistantTab.overview.key));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse chats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start voice mode'));
    await tester.pump();

    expect(voiceController.startCount, 1);
    expect(voiceController.lastConversationId, 'conversation-1');
    expect(find.byTooltip('Mute mic'), findsOneWidget);
    expect(find.byTooltip('End voice'), findsOneWidget);
  });

  testWidgets('home shell uses centered bottom dock at desktop width', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
        themeModeController: app.themeModeController,
        localeController: app.localeController,
      ),
    );
    await tester.pump();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('home shell keeps bottom navigation on narrow width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
        themeModeController: app.themeModeController,
        localeController: app.localeController,
      ),
    );
    await tester.pump();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}

Future<void> _pumpAssistantScreen(
  WidgetTester tester, {
  required ConversationApi conversationApi,
}) async {
  final harness = AssistantTestHarness();
  addTearDown(harness.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationApiProvider.overrideWithValue(conversationApi),
        localeControllerProvider.overrideWithValue(harness.localeController),
        actionResultMessageFormatterProvider.overrideWith(
          (ref) {
            final l10n = lookupAppLocalizations(const Locale('en'));
            return (action, result) =>
                actionResultMessage(l10n, action, result);
          },
        ),
      ],
      child: wrapWithL10n(
        AssistantScreen(profileController: harness.profileController),
      ),
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
