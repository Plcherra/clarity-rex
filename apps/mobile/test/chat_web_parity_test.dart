import 'dart:convert';
import 'dart:typed_data';

import 'package:clarity/rex/chat/data/chat_api.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_attachment_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatApi parses streamed SSE tokens and done event', () async {
    final api = ChatApi();
    final body = [
      'event: conversation',
      'data: {"conversation_id":"conv-1"}',
      '',
      'event: token',
      'data: {"token":"Hello"}',
      '',
      'event: token',
      'data: {"token":" world"}',
      '',
      'event: done',
      'data: {"conversation_id":"conv-1","response":"Hello world","messages":[]}',
      '',
    ].join('\n');

    final events = await api
        .parseSseEventsForTesting(Stream.value(utf8.encode(body)))
        .toList();

    expect(events, hasLength(4));
    expect(events[0], isA<ChatStreamConversation>());
    expect((events[0] as ChatStreamConversation).conversationId, 'conv-1');
    expect((events[1] as ChatStreamToken).token, 'Hello');
    expect((events[2] as ChatStreamToken).token, ' world');
    expect(events[3], isA<ChatStreamDone>());
    expect((events[3] as ChatStreamDone).response.response, 'Hello world');
  });

  testWidgets('ChatAttachmentImage renders preview bytes on web-safe path', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAttachmentImage(
            previewBytes: bytes,
            maxHeight: 48,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });
}
