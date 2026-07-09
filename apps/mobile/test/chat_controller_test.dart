import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/rex/chat/application/chat_controller.dart';
import 'package:clarity/rex/chat/data/chat_api.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_action_cards_strip.dart';
import 'package:clarity/rex/data/financial_context_service.dart';
import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'memory_page_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'applyBackendMessages attaches pending write proposals from voice turns',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(chatProvider.notifier);

      controller.applyBackendMessages(
        conversationId: 'conversation-1',
        messages: const [
          ChatApiMessage(
            id: 'message-1',
            conversationId: 'conversation-1',
            role: 'user',
            content: 'Money has been really tight lately.',
          ),
          ChatApiMessage(
            id: 'message-2',
            conversationId: 'conversation-1',
            role: 'assistant',
            content:
                'Want me to keep track of this and check in later? It would show up in your Goals tab as an open thread — not saved memory.',
          ),
        ],
        memoryChanges: {
          'confirmation_required': 1,
          'write_proposals': [
            {
              'id': 'open-thread-proposal-1',
              'write_kind': 'open_thread',
              'action': 'save_open_thread',
              'title': 'Money has been really tight lately.',
              'body': 'Money has been really tight lately.',
              'confirmation_text': 'Track this in Goals as an open thread?',
              'risk_level': 'medium',
              'status': 'pending',
            },
          ],
        },
      );

      final pending = pendingClarityActions(
        container.read(chatProvider).messages,
      );
      expect(pending, hasLength(1));
      expect(pending.first.writeKind, 'open_thread');
    },
  );

  test(
    'applyBackendMessages synthesizes assistant row for pending proposals',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(chatProvider.notifier);

      controller.finalizeVoiceUserMessage(
        localId: 'local-voice-1',
        content: 'My next goal should buy this bar.',
      );
      controller.applyBackendMessages(
        conversationId: 'conversation-1',
        messages: const [
          ChatApiMessage(
            id: 'message-1',
            conversationId: 'conversation-1',
            role: 'user',
            content: 'My next goal should buy this bar.',
          ),
        ],
        memoryChanges: {
          'confirmation_required': 1,
          'write_proposals': [
            {
              'id': 'plan-proposal-1',
              'write_kind': 'plan',
              'action': 'save_plan',
              'title': 'Buy pull-up bar',
              'body': 'Buy pull-up bar',
              'confirmation_text': 'Save this as a goal in Clarity?',
              'risk_level': 'medium',
              'status': 'pending',
            },
          ],
        },
      );

      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(2));
      expect(messages.last.role, ChatMessageRole.assistant);
      final pending = pendingClarityActions(messages);
      expect(pending, hasLength(1));
      expect(pending.first.writeKind, 'plan');
    },
  );

  test(
    'ChatController refreshes Knows after confirmed memory archive',
    () async {
      final chatApi = _FakeChatApi(
        response: const ChatApiResponse(
          conversationId: 'conversation-1',
          response: 'Done.',
          messages: [],
          memoryChanges: {'archived': 1},
        ),
      );
      final memoryApi = MemoryPageFakeMemoryApi();
      final container = ProviderContainer(
        overrides: [
          chatApiProvider.overrideWithValue(chatApi),
          memoryApiProvider.overrideWithValue(memoryApi),
        ],
      );
      addTearDown(container.dispose);

      final response = await container
          .read(chatProvider.notifier)
          .sendMessageForAssistantResponse('Delete that memory', stream: false);

      expect(response, 'Done.');
      expect(memoryApi.memoryActiveFilters.last, isTrue);
      expect(memoryApi.entityActiveFilters.last, isTrue);
    },
  );

  test(
    'ChatController does not build financial context for casual chat',
    () async {
      final chatApi = _FakeChatApi(
        response: const ChatApiResponse(
          conversationId: 'conversation-1',
          response: 'Sounds like a busy training day.',
          messages: [],
        ),
      );
      var buildSummaryCalls = 0;
      final financialContextService = AssistantFinancialContextService(
        loadFinancialReadModel: () async {
          buildSummaryCalls += 1;
          throw StateError('financial context should not load');
        },
        spendReference: DateTime.now,
        notifyDataChanged: () {},
      );
      final container = ProviderContainer(
        overrides: [
          chatApiProvider.overrideWithValue(chatApi),
          assistantFinancialContextServiceProvider.overrideWithValue(
            financialContextService,
          ),
        ],
      );
      addTearDown(container.dispose);

      final response = await container
          .read(chatProvider.notifier)
          .sendMessageForAssistantResponse(
            'I worked with two new employees, Aaron and Jessica.',
            stream: false,
          );

      expect(response, 'Sounds like a busy training day.');
      expect(buildSummaryCalls, 0);
      expect(chatApi.financialContexts, [isNull]);
    },
  );

  test(
    'ChatController does not build financial context for money recall',
    () async {
      final chatApi = _FakeChatApi(
        response: const ChatApiResponse(
          conversationId: 'conversation-1',
          response: 'I found that in chat history.',
          messages: [],
        ),
      );
      var buildSummaryCalls = 0;
      final financialContextService = AssistantFinancialContextService(
        loadFinancialReadModel: () async {
          buildSummaryCalls += 1;
          throw StateError('financial context should not load');
        },
        spendReference: DateTime.now,
        notifyDataChanged: () {},
      );
      final container = ProviderContainer(
        overrides: [
          chatApiProvider.overrideWithValue(chatApi),
          assistantFinancialContextServiceProvider.overrideWithValue(
            financialContextService,
          ),
        ],
      );
      addTearDown(container.dispose);

      final response = await container
          .read(chatProvider.notifier)
          .sendMessageForAssistantResponse(
            'What did I say about money?',
            stream: false,
          );

      expect(response, 'I found that in chat history.');
      expect(buildSummaryCalls, 0);
      expect(chatApi.financialContexts, [isNull]);
    },
  );

  test(
    'confirm marks applied only when backend write_proposals report applied',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final localeController = LocaleController(
        preferences: SharedPreferencesAsync(),
      );
      await localeController.load();

      final chatApi = _FakeChatApi(
        response: ChatApiResponse(
          conversationId: 'conversation-1',
          response: '',
          messages: const [],
          memoryChanges: {
            'write_proposals': [
              {
                'id': 'plan-proposal-1',
                'write_kind': 'plan',
                'action': 'save_plan',
                'title': 'Buy pull-up bar',
                'body': 'Buy pull-up bar',
                'confirmation_text': 'Save this as a goal in Clarity?',
                'risk_level': 'medium',
                'status': 'applied',
              },
            ],
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          chatApiProvider.overrideWithValue(chatApi),
          localeControllerProvider.overrideWithValue(localeController),
          assistantFinancialContextServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(chatProvider.notifier);

      controller.applyBackendMessages(
        conversationId: 'conversation-1',
        messages: const [
          ChatApiMessage(
            id: 'message-1',
            conversationId: 'conversation-1',
            role: 'assistant',
            content: 'Want me to save this goal?',
          ),
        ],
        memoryChanges: {
          'confirmation_required': 1,
          'write_proposals': [
            {
              'id': 'plan-proposal-1',
              'write_kind': 'plan',
              'action': 'save_plan',
              'title': 'Buy pull-up bar',
              'body': 'Buy pull-up bar',
              'confirmation_text': 'Save this as a goal in Clarity?',
              'risk_level': 'medium',
              'status': 'pending',
            },
          ],
        },
      );

      final pending = pendingClarityActions(
        container.read(chatProvider).messages,
      );
      expect(pending, hasLength(1));

      await controller.executeClarityAction(pending.first);

      final card = _clarityActionById(
        container.read(chatProvider).messages,
        'plan-proposal-1',
      );
      expect(card?.status, 'applied');
      expect(chatApi.writeConfirmations, isNotEmpty);
    },
  );

  test(
    'confirm fails when backend response has no applied evidence',
    () async {
      final chatApi = _FakeChatApi(
        response: const ChatApiResponse(
          conversationId: 'conversation-1',
          response: '',
          messages: [],
        ),
      );
      final container = ProviderContainer(
        overrides: [chatApiProvider.overrideWithValue(chatApi)],
      );
      addTearDown(container.dispose);
      final controller = container.read(chatProvider.notifier);

      controller.applyBackendMessages(
        conversationId: 'conversation-1',
        messages: const [
          ChatApiMessage(
            id: 'message-1',
            conversationId: 'conversation-1',
            role: 'assistant',
            content: 'Want me to save this goal?',
          ),
        ],
        memoryChanges: {
          'confirmation_required': 1,
          'write_proposals': [
            {
              'id': 'plan-proposal-1',
              'write_kind': 'plan',
              'action': 'save_plan',
              'title': 'Buy pull-up bar',
              'body': 'Buy pull-up bar',
              'confirmation_text': 'Save this as a goal in Clarity?',
              'risk_level': 'medium',
              'status': 'pending',
            },
          ],
        },
      );

      final pending = pendingClarityActions(
        container.read(chatProvider).messages,
      );
      await controller.executeClarityAction(pending.first);

      final card = _clarityActionById(
        container.read(chatProvider).messages,
        'plan-proposal-1',
      );
      expect(card?.status, 'failed');
      expect(card?.errorMessage, 'Could not confirm the plan save.');
      expect(card?.isApplied, isFalse);
    },
  );

  test(
    'incomplete stream surfaces error and does not clear it',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final localeController = LocaleController(
        preferences: SharedPreferencesAsync(),
      );
      await localeController.load();

      final chatApi = _FakeChatApi(
        response: const ChatApiResponse(
          conversationId: 'conversation-1',
          response: 'unused',
          messages: [],
        ),
        streamEvents: const [
          ChatStreamConversation('conversation-1'),
          ChatStreamToken('Partial'),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          chatApiProvider.overrideWithValue(chatApi),
          localeControllerProvider.overrideWithValue(localeController),
        ],
      );
      addTearDown(container.dispose);

      final response = await container
          .read(chatProvider.notifier)
          .sendMessageForAssistantResponse('Hello', stream: true);

      final state = container.read(chatProvider);
      expect(response, isNull);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, isNotEmpty);
      expect(
        state.messages.where((message) => message.isStreaming),
        isEmpty,
      );
    },
  );

  test(
    'cancelled incomplete stream does not surface a false failure',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final localeController = LocaleController(
        preferences: SharedPreferencesAsync(),
      );
      await localeController.load();

      final chatApi = _FakeChatApi(
        response: const ChatApiResponse(
          conversationId: 'conversation-1',
          response: 'unused',
          messages: [],
        ),
        streamEvents: const [
          ChatStreamConversation('conversation-1'),
          ChatStreamToken('Partial'),
        ],
        delayBeforeYielding: const Duration(milliseconds: 40),
      );
      final container = ProviderContainer(
        overrides: [
          chatApiProvider.overrideWithValue(chatApi),
          localeControllerProvider.overrideWithValue(localeController),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(chatProvider.notifier);

      final pending = controller.sendMessageForAssistantResponse(
        'Hello',
        stream: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.cancelStreaming();
      final response = await pending;

      final state = container.read(chatProvider);
      expect(response, isNull);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'loadConversation surfaces banner when pending write hydration fails',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final localeController = LocaleController(
        preferences: SharedPreferencesAsync(),
      );
      await localeController.load();

      final conversationApi = _FakeConversationApi(
        messages: const [
          ChatMessage(
            id: 'message-1',
            role: ChatMessageRole.user,
            content: 'Remember my morning routine.',
          ),
        ],
        pendingWriteError: const ChatApiException('network down'),
      );
      final container = ProviderContainer(
        overrides: [
          conversationApiProvider.overrideWithValue(conversationApi),
          localeControllerProvider.overrideWithValue(localeController),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatProvider.notifier)
          .loadConversation('conversation-1');

      final state = container.read(chatProvider);
      final l10n = lookupEnglishLocalizationsForTests();
      expect(state.isLoading, isFalse);
      expect(state.messages, hasLength(1));
      expect(state.errorMessage, l10n.chatPendingWriteHydrationFailed);
      expect(pendingClarityActions(state.messages), isEmpty);
    },
  );

  test(
    'loadConversation attaches pending write proposal on successful hydration',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final localeController = LocaleController(
        preferences: SharedPreferencesAsync(),
      );
      await localeController.load();

      final conversationApi = _FakeConversationApi(
        messages: const [
          ChatMessage(
            id: 'message-1',
            role: ChatMessageRole.user,
            content: 'Track waking up at 5am.',
          ),
          ChatMessage(
            id: 'message-2',
            role: ChatMessageRole.assistant,
            content: 'Want me to keep this as an open thread?',
          ),
        ],
        pendingWrite: {
          'confirmation_required': 1,
          'write_proposals': [
            {
              'id': 'open-thread-proposal-1',
              'write_kind': 'open_thread',
              'action': 'save_open_thread',
              'title': 'Wake up at 5am',
              'body': 'Wake up at 5am',
              'confirmation_text': 'Track this in Goals as an open thread?',
              'risk_level': 'medium',
              'status': 'pending',
            },
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [
          conversationApiProvider.overrideWithValue(conversationApi),
          localeControllerProvider.overrideWithValue(localeController),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatProvider.notifier)
          .loadConversation('conversation-1');

      final state = container.read(chatProvider);
      final pending = pendingClarityActions(state.messages);
      expect(state.errorMessage, isNull);
      expect(pending, hasLength(1));
      expect(pending.first.writeKind, 'open_thread');
    },
  );
}

ClarityActionCard? _clarityActionById(
  Iterable<ChatMessage> messages,
  String actionId,
) {
  for (final message in messages) {
    for (final action in message.clarityActions) {
      if (action.id == actionId) {
        return action;
      }
    }
  }
  return null;
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi({
    required this.response,
    this.streamEvents = const <ChatStreamEvent>[],
    this.delayBeforeYielding,
  });

  final ChatApiResponse response;
  final List<ChatStreamEvent> streamEvents;
  final Duration? delayBeforeYielding;
  final financialContexts = <Map<String, dynamic>?>[];
  final writeConfirmations = <Map<String, dynamic>?>[];

  @override
  Future<ChatApiResponse> sendMessage(
    String message, {
    String? conversationId,
    XFile? attachment,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    financialContexts.add(financialContext);
    writeConfirmations.add(writeConfirmation);
    return response;
  }

  @override
  Stream<ChatStreamEvent> streamMessage(
    String message, {
    String? conversationId,
    XFile? attachment,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async* {
    financialContexts.add(financialContext);
    writeConfirmations.add(writeConfirmation);
    final delay = delayBeforeYielding;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    for (final event in streamEvents) {
      yield event;
    }
  }
}

class _FakeConversationApi extends ConversationApi {
  _FakeConversationApi({
    required this.messages,
    this.pendingWrite,
    this.pendingWriteError,
  });

  final List<ChatMessage> messages;
  final Map<String, dynamic>? pendingWrite;
  final Object? pendingWriteError;

  @override
  Future<List<ChatMessage>> getConversationMessages(
    String conversationId,
  ) async {
    return messages;
  }

  @override
  Future<Map<String, dynamic>?> getPendingWriteProposal(
    String conversationId,
  ) async {
    final error = pendingWriteError;
    if (error != null) {
      throw error;
    }
    return pendingWrite;
  }
}
