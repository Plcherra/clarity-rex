import 'dart:async';

class StreamingVoiceApiException implements Exception {
  const StreamingVoiceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Platform-agnostic WebSocket surface for Rex streaming voice.
abstract class VoiceWebSocket {
  Stream<dynamic> get stream;

  void add(dynamic data);

  Future<void> close();
}

typedef VoiceWebSocketConnector =
    Future<VoiceWebSocket> Function(Uri uri, {Map<String, String>? headers});
