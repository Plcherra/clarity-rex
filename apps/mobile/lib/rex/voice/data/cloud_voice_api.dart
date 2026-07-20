import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';

class CloudVoiceApiException implements Exception {
  const CloudVoiceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudVoiceApi {
  CloudVoiceApi({
    http.Client? client,
    String? baseUrl,
    RexAuthHeaders? authHeaders,
    RexApiClient? apiClient,
    String? Function()? resolveLocale,
  }) : _apiClient =
           apiClient ??
           RexApiClient(
             httpClient: client,
             baseUrl: baseUrl,
             authHeaders: authHeaders,
           ),
       _resolveLocale = resolveLocale;

  final RexApiClient _apiClient;
  final String? Function()? _resolveLocale;

  void _attachLocale(Map<String, String> fields) {
    final locale = _resolveLocale?.call()?.trim();
    if (locale != null && locale.isNotEmpty) {
      fields['locale'] = locale;
    }
  }

  Future<CloudVoiceTranscriptionResponse> transcribe({
    required XFile audio,
    required String inputMimeType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _apiClient.uri('/voice/transcribe'),
    )..fields['input_mime_type'] = inputMimeType;
    _attachLocale(request.fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        await audio.readAsBytes(),
        filename: audio.name,
      ),
    );

    final response = await _sendMultipart(request);
    return CloudVoiceTranscriptionResponse.fromJson(_jsonMap(response));
  }

  Future<CloudVoiceSynthesisResponse> synthesize(String text) async {
    final payload = <String, String>{'text': text};
    _attachLocale(payload);
    final response = await _apiClient.postJson('/voice/synthesize', payload);
    return CloudVoiceSynthesisResponse.fromJson(_jsonMap(response));
  }

  Future<CloudVoiceTurnResponse> sendVoiceTurn({
    required XFile audio,
    required String inputMimeType,
    String? conversationId,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    final request = http.MultipartRequest('POST', _apiClient.uri('/voice/turn'))
      ..fields['input_mime_type'] = inputMimeType;
    if (conversationId != null) {
      request.fields['conversation_id'] = conversationId;
    }
    if (financialContext != null) {
      request.fields['financial_context'] = jsonEncode(financialContext);
    }
    if (writeConfirmation != null) {
      request.fields['write_confirmation'] = jsonEncode(writeConfirmation);
    }
    _attachLocale(request.fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        await audio.readAsBytes(),
        filename: audio.name,
      ),
    );

    final response = await _sendMultipart(request);
    return CloudVoiceTurnResponse.fromJson(_jsonMap(response));
  }

  Future<http.Response> _sendMultipart(http.MultipartRequest request) async {
    try {
      return http.Response.fromStream(await _apiClient.send(request));
    } on RexAuthException catch (error) {
      throw CloudVoiceApiException(error.message);
    } on http.ClientException {
      throw const CloudVoiceApiException(
        'Could not reach Assistant voice. Check your connection and try again.',
      );
    } on Object {
      throw const CloudVoiceApiException('Voice upload failed.');
    }
  }

  Map<String, dynamic> _jsonMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudVoiceApiException(_errorMessage(response.body));
    }

    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      throw const CloudVoiceApiException(
        'Assistant voice returned an unreadable response.',
      );
    }
    if (data is! Map<String, dynamic>) {
      throw const CloudVoiceApiException(
        'Assistant voice returned an invalid response.',
      );
    }
    return data;
  }

  String _errorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    } on FormatException {
      return 'Assistant voice returned an unreadable error.';
    }
    return 'Assistant voice returned an error.';
  }
}

class CloudVoiceTranscriptionResponse {
  const CloudVoiceTranscriptionResponse({
    required this.transcript,
    this.confidence,
    this.durationSeconds,
    this.metadata = const {},
  });

  factory CloudVoiceTranscriptionResponse.fromJson(Map<String, dynamic> json) {
    return CloudVoiceTranscriptionResponse(
      transcript: json['transcript'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble(),
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      metadata: _mapFromJson(json['metadata']),
    );
  }

  final String transcript;
  final double? confidence;
  final double? durationSeconds;
  final Map<String, dynamic> metadata;
}

class CloudVoiceSynthesisResponse {
  const CloudVoiceSynthesisResponse({
    required this.audioContentType,
    required this.audioBase64,
    required this.audioEncoding,
    required this.voiceName,
    required this.languageCode,
    this.metadata = const {},
  });

  factory CloudVoiceSynthesisResponse.fromJson(Map<String, dynamic> json) {
    return CloudVoiceSynthesisResponse(
      audioContentType: json['audio_content_type'] as String? ?? 'audio/mpeg',
      audioBase64: json['audio_base64'] as String? ?? '',
      audioEncoding: json['audio_encoding'] as String? ?? '',
      voiceName: json['voice_name'] as String? ?? '',
      languageCode: json['language_code'] as String? ?? '',
      metadata: _mapFromJson(json['metadata']),
    );
  }

  final String audioContentType;
  final String audioBase64;
  final String audioEncoding;
  final String voiceName;
  final String languageCode;
  final Map<String, dynamic> metadata;
}

class CloudVoiceTurnResponse {
  const CloudVoiceTurnResponse({
    required this.conversationId,
    required this.transcript,
    this.transcriptConfidence,
    required this.responseText,
    required this.audioContentType,
    required this.audioBase64,
    required this.audioEncoding,
    required this.voiceName,
    required this.languageCode,
    this.messages = const [],
    this.memoryChanges,
    this.voiceMetadata = const {},
  });

  factory CloudVoiceTurnResponse.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return CloudVoiceTurnResponse(
      conversationId: json['conversation_id'] as String? ?? '',
      transcript: json['transcript'] as String? ?? '',
      transcriptConfidence: (json['transcript_confidence'] as num?)?.toDouble(),
      responseText: json['response_text'] as String? ?? '',
      audioContentType: json['audio_content_type'] as String? ?? 'audio/mpeg',
      audioBase64: json['audio_base64'] as String? ?? '',
      audioEncoding: json['audio_encoding'] as String? ?? '',
      voiceName: json['voice_name'] as String? ?? '',
      languageCode: json['language_code'] as String? ?? '',
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map<String, dynamic>>()
                .map(ChatApiMessage.fromJson)
                .toList(growable: false)
          : const [],
      memoryChanges: _nullableMapFromJson(json['memory_changes']),
      voiceMetadata: _mapFromJson(json['voice_metadata']),
    );
  }

  final String conversationId;
  final String transcript;
  final double? transcriptConfidence;
  final String responseText;
  final String audioContentType;
  final String audioBase64;
  final String audioEncoding;
  final String voiceName;
  final String languageCode;
  final List<ChatApiMessage> messages;
  final Map<String, dynamic>? memoryChanges;
  final Map<String, dynamic> voiceMetadata;
}

Map<String, dynamic>? _nullableMapFromJson(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return null;
}

Map<String, dynamic> _mapFromJson(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const {};
}
