import 'package:clarity/rex/chat/application/chat_controller.dart';
import 'package:clarity/rex/chat/data/chat_api.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_action_cards_strip.dart';
import 'package:clarity/rex/data/financial_context_service.dart';
import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_page_test_helpers.dart';

void main() {
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
      expect(memoryApi.peopleActiveFilters.last, isTrue);
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
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi({required this.response});

  final ChatApiResponse response;
  final financialContexts = <Map<String, dynamic>?>[];

  @override
  Future<ChatApiResponse> sendMessage(
    String message, {
    String? conversationId,
    XFile? attachment,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    financialContexts.add(financialContext);
    return response;
  }
}
