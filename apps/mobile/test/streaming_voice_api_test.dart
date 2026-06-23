import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/voice/data/streaming_voice_api.dart';

void main() {
  test(
    'StreamingVoiceApi authenticates websocket handshakes with headers',
    () async {
      Uri? connectedUri;
      Map<String, String>? connectedHeaders;
      final socket = _FakeVoiceWebSocket();
      final api = StreamingVoiceApi(
        apiClient: RexApiClient(
          baseUrl: 'https://clarity.example.com/rex',
          authHeaders: const RexAuthHeaders(
            accessTokenProvider: _testAccessToken,
          ),
        ),
        connector: (uri, {headers}) async {
          connectedUri = uri;
          connectedHeaders = headers;
          return socket;
        },
      );

      await api.connect(conversationId: 'conversation-1');

      expect(
        connectedUri.toString(),
        'wss://clarity.example.com/rex/voice/stream',
      );
      expect(connectedUri!.queryParameters, isEmpty);
      expect(connectedHeaders, {'Authorization': 'Bearer test-token'});
      expect(socket.sentMessages, hasLength(1));
      expect(jsonDecode(socket.sentMessages.single as String), {
        'event': 'session.start',
        'input_mime_type': 'audio/linear16',
        'sample_rate': 16000,
        'client': 'flutter_streaming',
        'conversation_id': 'conversation-1',
      });
    },
  );

  test('VoiceStreamEvent exposes memory changes', () {
    final event = VoiceStreamEvent.fromJson({
      'event': 'messages.updated',
      'memory_changes': {'created': 1},
    });

    expect(event.memoryChanges, {'created': 1});
  });
}

class _FakeVoiceWebSocket implements VoiceWebSocket {
  final _controller = StreamController<dynamic>();
  final sentMessages = <dynamic>[];

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void add(dynamic data) => sentMessages.add(data);

  @override
  Future<void> close() => _controller.close();
}

String? _testAccessToken() => 'test-token';
