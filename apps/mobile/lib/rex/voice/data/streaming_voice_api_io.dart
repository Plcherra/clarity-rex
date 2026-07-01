import 'dart:io';

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

Future<VoiceWebSocket> connectVoiceWebSocket(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  try {
    return IoVoiceWebSocket(
      await WebSocket.connect(
        uri.toString(),
        headers: headers,
      ).timeout(const Duration(seconds: 8)),
    );
  } on Object {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  }
}
