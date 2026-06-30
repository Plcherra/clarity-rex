import 'package:clarity/l10n/app_localizations.dart';
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

import 'helpers/l10n_test_wrapper.dart';

void main() {
  testWidgets('Assistant navigation renders the four tabs in contract order', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await _pumpAssistantNavigation(tester);

    final tabs = tester.widgetList<Tab>(find.byType(Tab)).toList();

    expect(
      tabs.map((tab) => tab.key),
      AssistantTab.values.map((tab) => tab.key),
    );
    for (final tab in AssistantTab.values) {
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

    expect(voiceController.startCount, 0);
  });

  testWidgets(
    'Assistant navigation keeps Chats as a tab, not a header action',
    (tester) async {
      await _pumpAssistantNavigation(tester);

      expect(find.byKey(AssistantTab.chats.key), findsOneWidget);
      expect(find.byTooltip('Conversations'), findsNothing);

      await tester.tap(find.byKey(AssistantTab.chats.key));
      await tester.pumpAndSettle();

      expect(find.text('Chats'), findsWidgets);
      expect(find.byTooltip('Conversations'), findsNothing);
    },
  );

  testWidgets(
    'Chats search submits backend query and renders backend results',
    (tester) async {
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

      await tester.tap(find.byKey(AssistantTab.chats.key));
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
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const sizes = [Size(320, 568), Size(390, 844), Size(430, 932)];

    for (final (index, size) in sizes.indexed) {
      await tester.binding.setSurfaceSize(size);
      final voiceController = _FakeVoiceCallController();
      await _pumpAssistantNavigation(
        tester,
        voiceController: voiceController,
        rootKey: ValueKey('assistant-size-$index'),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      for (final tab in AssistantTab.values) {
        expect(find.byKey(tab.key), findsOneWidget);
      }

      for (final tab in [
        AssistantTab.chat,
        AssistantTab.memory,
        AssistantTab.goals,
        AssistantTab.chats,
      ]) {
        await tester.tap(find.byKey(tab.key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}

Future<void> _pumpAssistantNavigation(
  WidgetTester tester, {
  _FakeVoiceCallController? voiceController,
  _FakeConversationApi? conversationApi,
  Key? rootKey,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationApiProvider.overrideWithValue(
          conversationApi ?? _FakeConversationApi(),
        ),
        memoryApiProvider.overrideWithValue(_FakeMemoryApi()),
        if (voiceController != null)
          voiceCallProvider.overrideWith(() => voiceController),
      ],
      child: wrapWithL10n(AssistantScreen(key: rootKey)),
    ),
  );
  await tester.pump();
}

class _FakeConversationApi extends ConversationApi {
  _FakeConversationApi({this.searchResults = const []});

  final List<ConversationSearchResult> searchResults;
  final List<String> searchQueries = [];

  @override
  Future<List<Conversation>> getConversations() async => const [];

  @override
  Future<List<ChatMessage>> getConversationMessages(
    String conversationId,
  ) async {
    return const [];
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
  Future<List<CommitmentMemoryItem>> getCommitments({
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
  Future<MemoryPagedResult<CommitmentMemoryItem>> getCommitmentsPaged({
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
