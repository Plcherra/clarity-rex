import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/voice/data/voice_websocket.dart';

import 'streaming_voice_api_io.dart'
    if (dart.library.html) 'streaming_voice_api_web.dart';

export 'voice_websocket.dart';

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

  Map<String, dynamic>? get memoryChanges {
    final value = data['memory_changes'];
    return value is Map<String, dynamic> ? value : null;
  }

  String? get audioBase64 => data['audio_base64'] as String?;

  String get audioContentType =>
      data['audio_content_type'] as String? ?? 'audio/mpeg';

  String? get detail => data['detail'] as String?;

  String? get errorCode => data['code'] as String?;
}

class StreamingVoiceSession {
  StreamingVoiceSession(this._socket);

  final VoiceWebSocket _socket;
  var _closed = false;

  late final Stream<VoiceStreamEvent> events = _socket.stream.map(_parseEvent);

  void sendAudioChunk(Uint8List chunk) {
    if (_closed || chunk.isEmpty) {
      return;
    }
    _socket.add(chunk);
  }

  void endUtterance({
    String? transcript,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) {
    final payload = <String, Object>{'event': 'utterance.end'};
    final trimmedTranscript = transcript?.trim();
    if (trimmedTranscript != null && trimmedTranscript.isNotEmpty) {
      // Authority when live Deepgram finish() returns blank after partials.
      payload['transcript'] = trimmedTranscript;
    }
    if (financialContext != null) {
      payload['financial_context'] = financialContext;
    }
    if (writeConfirmation != null) {
      payload['write_confirmation'] = writeConfirmation;
    }
    _sendJson(payload);
  }

  void interrupt() {
    _sendJson({'event': 'user.interrupt'});
  }

  Future<void> endSession() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _sendJson({'event': 'session.end'});
    await _socket.close();
  }

  void _sendJson(Map<String, dynamic> payload) {
    if (_closed) {
      return;
    }
    _socket.add(jsonEncode(payload));
  }

  VoiceStreamEvent _parseEvent(dynamic rawEvent) {
    if (rawEvent is! String) {
      throw const StreamingVoiceApiException(
        'Assistant voice stream returned an unreadable event.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(rawEvent);
    } on FormatException {
      throw const StreamingVoiceApiException(
        'Assistant voice stream returned invalid JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const StreamingVoiceApiException(
        'Assistant voice stream returned an invalid event.',
      );
    }

    return VoiceStreamEvent.fromJson(decoded);
  }
}

class StreamingVoiceApi {
  StreamingVoiceApi({
    String? baseUrl,
    VoiceWebSocketConnector? connector,
    RexApiClient? apiClient,
    String? Function()? resolveLocale,
  }) : _apiClient = apiClient ?? RexApiClient(baseUrl: baseUrl),
       _connector = connector ?? connectVoiceWebSocket,
       _resolveLocale = resolveLocale;

  final RexApiClient _apiClient;
  final VoiceWebSocketConnector _connector;
  final String? Function()? _resolveLocale;

  Future<StreamingVoiceSession> connect({
    String? conversationId,
    String inputMimeType = 'audio/linear16',
    int sampleRate = 16000,
    String client = 'flutter_streaming',
    Map<String, dynamic>? financialContext,
  }) async {
    await _apiClient.prepareAuthSession();
    final socket = await _connector(
      _streamUri(),
      headers: _apiClient.authHeaders(),
    );
    final payload = <String, Object>{
      'event': 'session.start',
      'input_mime_type': inputMimeType,
      'sample_rate': sampleRate,
      'client': client,
    };
    if (conversationId != null) {
      payload['conversation_id'] = conversationId;
    }
    if (financialContext != null) {
      payload['financial_context'] = financialContext;
    }
    final locale = _resolveLocale?.call()?.trim();
    if (locale != null && locale.isNotEmpty) {
      payload['locale'] = locale;
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
        'Clarity API URL must use http, https, ws, or wss.',
      );
    }
  }
}
