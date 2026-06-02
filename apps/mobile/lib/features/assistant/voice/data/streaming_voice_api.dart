import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';

class StreamingVoiceApiException implements Exception {
  const StreamingVoiceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef VoiceWebSocketConnector =
    Future<VoiceWebSocket> Function(Uri uri, {Map<String, String>? headers});

abstract class VoiceWebSocket {
  Stream<dynamic> get stream;

  void add(dynamic data);

  Future<void> close();
}

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

class VoiceStreamEvent {
  const VoiceStreamEvent(this.name, this.data);

  factory VoiceStreamEvent.fromJson(Map<String, dynamic> json) {
    return VoiceStreamEvent(json['event'] as String? ?? 'unknown', json);
  }

  final String name;
  final Map<String, dynamic> data;

  String? get transcript => data['transcript'] as String?;

  bool get speechFinal => data['speech_final'] as bool? ?? false;

  String? get token => data['token'] as String?;

  String? get conversationId => data['conversation_id'] as String?;

  String? get responseText => data['response_text'] as String?;

  String? get audioBase64 => data['audio_base64'] as String?;

  String get audioContentType =>
      data['audio_content_type'] as String? ?? 'audio/mpeg';

  String? get detail => data['detail'] as String?;

  String? get errorCode => data['code'] as String?;
}

class StreamingVoiceSession {
  StreamingVoiceSession(this._socket);

  final VoiceWebSocket _socket;

  late final Stream<VoiceStreamEvent> events = _socket.stream.map(_parseEvent);

  void sendAudioChunk(Uint8List chunk) {
    if (chunk.isEmpty) {
      return;
    }
    _socket.add(chunk);
  }

  void endUtterance() {
    _sendJson({'event': 'utterance.end'});
  }

  void interrupt() {
    _sendJson({'event': 'user.interrupt'});
  }

  Future<void> endSession() async {
    _sendJson({'event': 'session.end'});
    await _socket.close();
  }

  void _sendJson(Map<String, dynamic> payload) {
    _socket.add(jsonEncode(payload));
  }

  VoiceStreamEvent _parseEvent(dynamic rawEvent) {
    if (rawEvent is! String) {
      throw const StreamingVoiceApiException(
        'Rex voice stream returned an unreadable event.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(rawEvent);
    } on FormatException {
      throw const StreamingVoiceApiException(
        'Rex voice stream returned invalid JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const StreamingVoiceApiException(
        'Rex voice stream returned an invalid event.',
      );
    }

    final event = VoiceStreamEvent.fromJson(decoded);
    if (event.name == 'error') {
      if (event.errorCode == 'turn_in_progress') {
        return event;
      }
      throw StreamingVoiceApiException(
        event.detail ?? 'Rex voice stream failed.',
      );
    }
    return event;
  }
}

class StreamingVoiceApi {
  StreamingVoiceApi({
    String? baseUrl,
    VoiceWebSocketConnector? connector,
    RexApiClient? apiClient,
  }) : _apiClient = apiClient ?? RexApiClient(baseUrl: baseUrl),
       _connector = connector ?? _connectIoWebSocket;

  final RexApiClient _apiClient;
  final VoiceWebSocketConnector _connector;

  Future<StreamingVoiceSession> connect({
    String? conversationId,
    String inputMimeType = 'audio/linear16',
    int sampleRate = 16000,
    Map<String, dynamic>? financialContext,
  }) async {
    final socket = await _connector(
      _streamUri(),
      headers: _apiClient.authHeaders(),
    );
    final payload = <String, Object>{
      'event': 'session.start',
      'input_mime_type': inputMimeType,
      'sample_rate': sampleRate,
    };
    if (conversationId != null) {
      payload['conversation_id'] = conversationId;
    }
    if (financialContext != null) {
      payload['financial_context'] = financialContext;
    }
    socket.add(jsonEncode(payload));
    return StreamingVoiceSession(socket);
  }

  Uri _streamUri() {
    try {
      return _apiClient.webSocketUri('/voice/stream');
    } on RexAuthException catch (error) {
      throw StreamingVoiceApiException(error.message);
    } on Object {
      throw const StreamingVoiceApiException(
        'Rex backend URL must use http, https, ws, or wss.',
      );
    }
  }

  static Future<VoiceWebSocket> _connectIoWebSocket(
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
        'Could not open Rex voice stream. Check your connection and try again.',
      );
    }
  }
}
