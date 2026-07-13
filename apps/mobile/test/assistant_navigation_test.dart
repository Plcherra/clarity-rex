import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/accountability/data/accountability_api.dart';
import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/memory/data/memory_constants.dart';
import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/data/memory_paged_result.dart';
import 'package:clarity/rex/presentation/assistant_screen.dart';
import 'package:clarity/rex/presentation/assistant_tab.dart';
import 'package:clarity/rex/voice/application/voice_call_controller.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/assistant_test_harness.dart';
import 'helpers/l10n_test_wrapper.dart';

void _setViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  test('compact vs wide assistant tab sets', () {
    expect(
      assistantTabsForLayout(compact: true),
      [
        AssistantTab.chats,
        AssistantTab.chat,
        AssistantTab.memory,
        AssistantTab.goals,
        AssistantTab.overview,
      ],
    );
    expect(
      assistantTabsForLayout(compact: false),
      [
        AssistantTab.chat,
        AssistantTab.memory,
        AssistantTab.goals,
        AssistantTab.overview,
      ],
    );
  });

  testWidgets('wide Assistant navigation omits Chats sub-tab', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    _setViewSize(tester, const Size(1200, 900));
    await _pumpAssistantNavigation(tester);

    final expected = assistantTabsForLayout(compact: false);
    final tabs = tester.widgetList<Tab>(find.byType(Tab)).toList();

    expect(tabs.map((tab) => tab.key), expected.map((tab) => tab.key));
    for (final tab in expected) {
      expect(find.text(tab.label(l10n)), findsOneWidget);
    }
    expect(find.byKey(AssistantTab.chats.key), findsNothing);
  });

  testWidgets('compact Assistant navigation includes Chats first', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    _setViewSize(tester, const Size(390, 844));
    await _pumpAssistantNavigation(tester);

    final expected = assistantTabsForLayout(compact: true);
    final tabs = tester.widgetList<Tab>(find.byType(Tab)).toList();

    expect(tabs.map((tab) => tab.key), expected.map((tab) => tab.key));
    for (final tab in expected) {
      expect(find.text(tab.label(l10n)), findsOneWidget);
      final tabSemantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byKey(tab.key),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        tabSemantics.any(
          (semantics) => semantics.properties.label == tab.semanticLabel(l10n),
        ),
        isTrue,
      );
    }
  });

  testWidgets('Assistant navigation changes selected tab for every section', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1200, 900));
    final voiceController = _FakeVoiceCallController();
    await _pumpAssistantNavigation(tester, voiceController: voiceController);

    TabController controller() {
      return tester.widget<TabBar>(find.byType(TabBar)).controller!;
    }

    final tabs = assistantTabsForLayout(compact: false);
    expect(controller().index, tabs.indexOf(AssistantTab.chat));

    for (final tab in tabs) {
      await tester.tap(find.byKey(tab.key));
      await tester.pumpAndSettle();

      expect(controller().index, tabs.indexOf(tab));
    }

    expect(voiceController.startCount, 0);
  });

  testWidgets(
    'Assistant navigation keeps Overview as a tab on wide layout',
    (tester) async {
      _setViewSize(tester, const Size(1200, 900));
      await _pumpAssistantNavigation(tester);

      expect(find.byKey(AssistantTab.overview.key), findsOneWidget);
      expect(find.byKey(AssistantTab.chats.key), findsNothing);
      expect(find.byTooltip('Conversations'), findsNothing);

      await tester.tap(find.byKey(AssistantTab.overview.key));
      await tester.pumpAndSettle();

      expect(find.text('Companion overview'), findsOneWidget);
      expect(find.byTooltip('Conversations'), findsNothing);
    },
  );

  testWidgets(
    'compact Chats tab selection opens Chat with loaded conversation',
    (tester) async {
      _setViewSize(tester, const Size(390, 844));

      final conversationApi = _FakeConversationApi(
        conversations: [
          Conversation(
            id: 'conversation-budget',
            title: 'Budget check-in',
            timestamp: DateTime.utc(2026, 6, 1),
          ),
        ],
        messagesById: {
          'conversation-budget': [
            ChatMessage(
              id: 'msg-1',
              role: ChatMessageRole.assistant,
              content: 'Loaded from history',
              timestamp: DateTime.utc(2026, 6, 2),
            ),
          ],
        },
      );
      await _pumpAssistantNavigation(tester, conversationApi: conversationApi);

      await tester.tap(find.byKey(AssistantTab.chats.key));
      await tester.pumpAndSettle();
      expect(find.text('Budget check-in'), findsOneWidget);

      await tester.tap(find.text('Budget check-in'));
      await tester.pumpAndSettle();

      final tabs = assistantTabsForLayout(compact: true);
      final controller =
          tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(controller.index, tabs.indexOf(AssistantTab.chat));
      expect(find.text('Loaded from history'), findsOneWidget);
    },
  );

  testWidgets(
    'Chats search from Overview submits backend query and renders results',
    (tester) async {
      // Medium desktop: no compact Chats tab, no wide chat sidebar split.
      _setViewSize(tester, const Size(900, 800));
      final conversationApi = _FakeConversationApi(
        searchResults: [
          ConversationSearchResult(
            conversationId: 'conversation-mom',
            matchType: 'message',
            preview: "My mom's birthday is June 18th.",
            conversationTitle: 'Family dates',
            conversationTimestamp: DateTime.utc(2026, 6, 18),
            matchedTerms: const ['18', '18th'],
          ),
        ],
      );
      await _pumpAssistantNavigation(tester, conversationApi: conversationApi);

      await tester.tap(find.byKey(AssistantTab.overview.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse chats'));
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search chats',
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, '18');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(conversationApi.searchQueries, ['18']);
      expect(find.text('Family dates'), findsOneWidget);
      expect(find.text("My mom's birthday is June 18th."), findsOneWidget);
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

  testWidgets('Assistant shell fits common iPhone safe-area widths', (
    tester,
  ) async {
    const sizes = [Size(320, 568), Size(390, 844), Size(430, 932)];
    final compactTabs = assistantTabsForLayout(compact: true);

    for (final (index, size) in sizes.indexed) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      final voiceController = _FakeVoiceCallController();
      await _pumpAssistantNavigation(
        tester,
        voiceController: voiceController,
        rootKey: ValueKey('assistant-size-$index'),
      );

      expect(tester.takeException(), isNull);
      // Native compact hides the redundant Assistant page title.
      expect(find.text('Assistant'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      for (final tab in compactTabs) {
        expect(find.byKey(tab.key), findsOneWidget);
      }

      for (final tab in [
        AssistantTab.chat,
        AssistantTab.memory,
        AssistantTab.goals,
        AssistantTab.overview,
      ]) {
        await tester.tap(find.byKey(tab.key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

Future<void> _pumpAssistantNavigation(
  WidgetTester tester, {
  _FakeVoiceCallController? voiceController,
  _FakeConversationApi? conversationApi,
  Key? rootKey,
}) async {
  final harness = AssistantTestHarness();
  addTearDown(harness.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationApiProvider.overrideWithValue(
          conversationApi ?? _FakeConversationApi(),
        ),
        memoryApiProvider.overrideWithValue(_FakeMemoryApi()),
        accountabilityApiProvider.overrideWithValue(_FakeAccountabilityApi()),
        localeControllerProvider.overrideWithValue(harness.localeController),
        if (voiceController != null)
          voiceCallProvider.overrideWith(() => voiceController),
      ],
      child: wrapWithL10n(
        AssistantScreen(
          key: rootKey,
          profileController: harness.profileController,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FakeConversationApi extends ConversationApi {
  _FakeConversationApi({
    this.searchResults = const [],
    this.conversations = const [],
    this.messagesById = const {},
  });

  final List<ConversationSearchResult> searchResults;
  final List<Conversation> conversations;
  final Map<String, List<ChatMessage>> messagesById;
  final List<String> searchQueries = [];

  @override
  Future<List<Conversation>> getConversations() async => conversations;

  @override
  Future<List<ChatMessage>> getConversationMessages(
    String conversationId,
  ) async {
    return messagesById[conversationId] ?? const [];
  }

  @override
  Future<List<ConversationSearchResult>> searchConversations(
    String query,
  ) async {
    searchQueries.add(query);
    return searchResults;
  }
}

class _FakeMemoryApi extends MemoryApi {
  @override
  Future<List<MemoryItem>> getMemories({
    MemoryType? memoryType,
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    return const [];
  }

  @override
  Future<List<EntityMemoryItem>> getEntities({
    String? entityType,
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    return const [];
  }

  @override
  Future<List<EntityEventItem>> getEntityEvents(
    String entityId, {
    bool? active,
    int limit = kEntityEventPreviewLimit,
  }) async {
    return const [];
  }

  @override
  Future<List<PersonMemoryItem>> getPeople({
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    return const [];
  }

  @override
  Future<List<RuleMemoryItem>> getRules({
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    return const [];
  }

  @override
  Future<List<PlanMemoryItem>> getPlans({
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    return const [];
  }

  @override
  Future<MemoryPagedResult<MemoryItem>> getMemoriesPaged({
    MemoryType? memoryType,
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    return const MemoryPagedResult(items: []);
  }

  @override
  Future<MemoryPagedResult<EntityMemoryItem>> getEntitiesPaged({
    String? entityType,
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    return const MemoryPagedResult(items: []);
  }

  @override
  Future<MemoryPagedResult<RuleMemoryItem>> getRulesPaged({
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    return const MemoryPagedResult(items: []);
  }

  @override
  Future<MemoryPagedResult<PlanMemoryItem>> getPlansPaged({
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    return const MemoryPagedResult(items: []);
  }

  @override
  Future<List<PlanMilestoneMemoryItem>> getPlanMilestones(
    String planId, {
    bool? active,
    int limit = kPlanMilestonePreviewLimit,
  }) async {
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getSavedKnowledgeOverview({
    bool activeOnly = true,
    int limit = kMemoryListLimit,
  }) async {
    return const {
      'memories': <Map<String, dynamic>>[],
      'people': <Map<String, dynamic>>[],
      'entities': <Map<String, dynamic>>[],
      'rules': <Map<String, dynamic>>[],
      'plans': <Map<String, dynamic>>[],
    };
  }
}

class _FakeAccountabilityApi extends AccountabilityApi {
  @override
  Future<AccountabilityOverview> getOverview({
    int limit = 25,
    Map<String, dynamic>? budgetPerformance,
  }) async {
    return const AccountabilityOverview(
      signals: [],
      ruleRisks: [],
      planRisks: [],
      recentPatterns: [],
      activeRules: [],
      openThreads: [],
      activePlans: [],
      openMilestones: [],
      completedMilestones: [],
      planHierarchy: [],
      duplicateWarnings: [],
      metadata: {},
    );
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
