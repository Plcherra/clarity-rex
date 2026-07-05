import 'package:clarity/rex/chat/application/chat_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upsertVoiceUserMessage creates interim user message', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(chatProvider.notifier);

    controller.upsertVoiceUserMessage(
      localId: 'local-voice-1',
      content: 'Hello Rex',
    );

    final messages = container.read(chatProvider).messages;
    expect(messages, hasLength(1));
    expect(messages.first.role, ChatMessageRole.user);
    expect(messages.first.content, 'Hello Rex');
    expect(messages.first.isVoiceInterim, isTrue);
  });

  test('upsertVoiceUserMessage updates existing interim message', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(chatProvider.notifier);

    controller.upsertVoiceUserMessage(
      localId: 'local-voice-1',
      content: 'Hello',
    );
    controller.upsertVoiceUserMessage(
      localId: 'local-voice-1',
      content: 'Hello Rex',
    );

    final messages = container.read(chatProvider).messages;
    expect(messages, hasLength(1));
    expect(messages.first.content, 'Hello Rex');
    expect(messages.first.isVoiceInterim, isTrue);
  });

  test('finalizeVoiceUserMessage keeps message with normal styling flag', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(chatProvider.notifier);

    controller.upsertVoiceUserMessage(
      localId: 'local-voice-1',
      content: 'Hello Rex',
    );
    controller.finalizeVoiceUserMessage(
      localId: 'local-voice-1',
      content: 'Hello Rex, how are budgets looking?',
    );

    final messages = container.read(chatProvider).messages;
    expect(messages, hasLength(1));
    expect(messages.first.content, 'Hello Rex, how are budgets looking?');
    expect(messages.first.isVoiceInterim, isFalse);
  });

  test('removeVoiceUserMessage drops pending interim message', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(chatProvider.notifier);

    controller.upsertVoiceUserMessage(
      localId: 'local-voice-1',
      content: 'Hello Rex',
    );
    controller.removeVoiceUserMessage('local-voice-1');

    expect(container.read(chatProvider).messages, isEmpty);
  });

  test('finalizeVoiceUserMessage with empty content removes pending message', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(chatProvider.notifier);

    controller.upsertVoiceUserMessage(
      localId: 'local-voice-1',
      content: 'Hello Rex',
    );
    controller.finalizeVoiceUserMessage(
      localId: 'local-voice-1',
      content: '   ',
    );

    expect(container.read(chatProvider).messages, isEmpty);
  });

  test(
    'finalizeVoiceUserMessage with empty content keeps finalized message',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(chatProvider.notifier);

      controller.upsertVoiceUserMessage(
        localId: 'local-voice-1',
        content: 'Hello Rex',
      );
      controller.finalizeVoiceUserMessage(
        localId: 'local-voice-1',
        content: 'Hello Rex, how are budgets looking?',
      );
      controller.finalizeVoiceUserMessage(
        localId: 'local-voice-1',
        content: '   ',
      );

      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.first.isVoiceInterim, isFalse);
    },
  );

  test('removeVoiceUserMessage ignores finalized voice message', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(chatProvider.notifier);

    controller.finalizeVoiceUserMessage(
      localId: 'local-voice-1',
      content: 'Keep this message',
    );
    controller.removeVoiceUserMessage('local-voice-1');

    final messages = container.read(chatProvider).messages;
    expect(messages, hasLength(1));
    expect(messages.first.content, 'Keep this message');
  });

  test(
    'mergeBackendMessagesPreservingLocalVoice keeps interim when backend empty',
    () {
      final merged = mergeBackendMessagesPreservingLocalVoice(
        local: const [
          ChatMessage(
            id: 'local-voice-1',
            role: ChatMessageRole.user,
            content: 'Still talking',
            isVoiceInterim: true,
          ),
        ],
        backend: const [],
      );

      expect(merged, hasLength(1));
      expect(merged.first.id, 'local-voice-1');
    },
  );

  test(
    'mergeBackendMessagesPreservingLocalVoice drops local when backend matches',
    () {
      final merged = mergeBackendMessagesPreservingLocalVoice(
        local: const [
          ChatMessage(
            id: 'local-voice-1',
            role: ChatMessageRole.user,
            content: 'Plan my launch week',
            isVoiceInterim: false,
          ),
        ],
        backend: const [
          ChatMessage(
            id: 'user-message-1',
            role: ChatMessageRole.user,
            content: 'Plan my launch week',
          ),
          ChatMessage(
            id: 'assistant-message-1',
            role: ChatMessageRole.assistant,
            content: 'Use weekly launch plans.',
          ),
        ],
      );

      expect(merged, hasLength(2));
      expect(merged.first.id, 'user-message-1');
      expect(merged.last.id, 'assistant-message-1');
    },
  );

  test(
    'mergeBackendMessagesPreservingLocalVoice keeps local user before assistant',
    () {
      final merged = mergeBackendMessagesPreservingLocalVoice(
        local: const [
          ChatMessage(
            id: 'local-voice-1',
            role: ChatMessageRole.user,
            content: 'to the door frame.',
            isVoiceInterim: false,
          ),
        ],
        backend: const [
          ChatMessage(
            id: 'assistant-message-1',
            role: ChatMessageRole.assistant,
            content: 'It is a doorway pull-up bar.',
          ),
        ],
      );

      expect(merged, hasLength(2));
      expect(merged.first.id, 'local-voice-1');
      expect(merged.last.id, 'assistant-message-1');
    },
  );

  test(
    'applyBackendMessages preserves local voice row when backend has only assistant',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(chatProvider.notifier);

      controller.finalizeVoiceUserMessage(
        localId: 'local-voice-1',
        content: 'to the door frame.',
      );
      controller.applyBackendMessages(
        conversationId: 'conversation-1',
        messages: const [
          ChatApiMessage(
            id: 'assistant-message-1',
            conversationId: 'conversation-1',
            role: 'assistant',
            content: 'It is a doorway pull-up bar.',
          ),
        ],
      );

      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(2));
      expect(messages.first.id, 'local-voice-1');
      expect(messages.last.role, ChatMessageRole.assistant);
    },
  );
}
