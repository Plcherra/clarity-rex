import 'package:clarity/rex/chat/application/chat_controller.dart';
import 'package:clarity/rex/chat/data/chat_api.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_page_test_helpers.dart';

void main() {
  test('ChatController refreshes Knows after confirmed memory archive', () async {
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
  });
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi({required this.response});

  final ChatApiResponse response;

  @override
  Future<ChatApiResponse> sendMessage(
    String message, {
    String? conversationId,
    XFile? attachment,
    Map<String, dynamic>? financialContext,
  }) async {
    return response;
  }
}
