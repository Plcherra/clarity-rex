import 'dart:io';

import 'package:clarity/rex/voice/data/streaming_voice_ticket.dart';
import 'package:clarity/rex/voice/data/voice_websocket.dart';

class IoVoiceWebSocket implements VoiceWebSocket {
  IoVoiceWebSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<dynamic> get stream => _socket;

  @override
  void add(dynamic data) => _socket.add(data);

  @override
  Future<void> close() => _socket.close();
}

/// iOS/Android: auth via short-lived ticket (same as web). Custom Authorization
/// headers on dart:io WebSocket are unreliable and left the VPS with zero
/// `/voice/stream` hits while chat+TTS fallback still answered once.
Future<VoiceWebSocket> connectVoiceWebSocket(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  try {
    final ticket = await fetchVoiceStreamTicket(uri, headers);
    final ticketUri = voiceStreamUriWithTicket(uri, ticket);
    return IoVoiceWebSocket(
      await WebSocket.connect(ticketUri.toString()).timeout(
        const Duration(seconds: 8),
      ),
    );
  } on StreamingVoiceApiException {
    rethrow;
  } on Object {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  }
}
