import 'package:clarity/rex/chat/application/chat_controller.dart';
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
}
