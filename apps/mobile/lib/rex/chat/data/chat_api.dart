import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';

class ChatApiException implements Exception {
  const ChatApiException(this.message, {this.type = ChatApiErrorType.unknown});

  final String message;
  final ChatApiErrorType type;

  @override
  String toString() => message;
}

enum ChatApiErrorType {
  backendValidation,
  network,
  timeout,
  upload,
  invalidResponse,
  unknown,
}

class ChatApi {
  static const _chatStreamIdleTimeout = Duration(seconds: 60);

  ChatApi({
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

  void _attachLocale(Map<String, dynamic> payload) {
    final locale = _resolveLocale?.call()?.trim();
    if (locale != null && locale.isNotEmpty) {
      payload['locale'] = locale;
    }
  }

  @visibleForTesting
  Map<String, dynamic> attachLocaleForTesting(Map<String, dynamic> payload) {
    _attachLocale(payload);
    return payload;
  }

  Future<ChatApiResponse> sendMessage(
    String message, {
    String? conversationId,
    XFile? attachment,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    final uri = _apiClient.uri('/chat');
    try {
      final response = attachment == null
          ? await _sendJsonMessage(
              uri,
              message: message,
              conversationId: conversationId,
              financialContext: financialContext,
              writeConfirmation: writeConfirmation,
            )
          : await _sendMultipartMessage(
              uri,
              message: message,
              conversationId: conversationId,
              attachment: attachment,
              financialContext: financialContext,
            );

      return _chatResponseFromHttpResponse(response);
    } on RexAuthException catch (error) {
      throw ChatApiException(
        error.message,
        type: ChatApiErrorType.backendValidation,
      );
    } on ChatApiException {
      rethrow;
    } on TimeoutException {
      throw ChatApiException(
        attachment == null
            ? 'Assistant took too long to respond. Please try again.'
            : 'The upload took too long. Please try again.',
        type: attachment == null
            ? ChatApiErrorType.timeout
            : ChatApiErrorType.upload,
      );
    } on http.ClientException {
      throw ChatApiException(
        attachment == null
            ? 'Could not reach Assistant. Check your connection and try again.'
            : 'Could not upload the file. Check your connection and try again.',
        type: attachment == null
            ? ChatApiErrorType.network
            : ChatApiErrorType.upload,
      );
    } on Object {
      throw ChatApiException(
        attachment == null
            ? 'Something went wrong sending the message.'
            : 'Something went wrong uploading the file.',
        type: attachment == null
            ? ChatApiErrorType.unknown
            : ChatApiErrorType.upload,
      );
    }
  }

  Stream<ChatStreamEvent> streamMessage(
    String message, {
    String? conversationId,
    XFile? attachment,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async* {
    final uri = _apiClient.uri('/chat');
    try {
      final request = attachment == null
          ? _jsonStreamRequest(
              uri,
              message: message,
              conversationId: conversationId,
              financialContext: financialContext,
              writeConfirmation: writeConfirmation,
            )
          : await _multipartStreamRequest(
              uri,
              message: message,
              conversationId: conversationId,
              attachment: attachment,
              financialContext: financialContext,
              writeConfirmation: writeConfirmation,
            );
      final response = await _apiClient.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw ChatApiException(
          _errorMessage(body),
          type: _errorTypeForStatusCode(response.statusCode),
        );
      }

      await for (final event in _eventsFromSse(
        response.stream.timeout(_chatStreamIdleTimeout),
      )) {
        yield event;
      }
    } on RexAuthException catch (error) {
      throw ChatApiException(
        error.message,
        type: ChatApiErrorType.backendValidation,
      );
    } on ChatApiException {
      rethrow;
    } on TimeoutException {
      throw ChatApiException(
        attachment == null
            ? 'Assistant took too long to respond. Please try again.'
            : 'The upload took too long. Please try again.',
        type: attachment == null
            ? ChatApiErrorType.timeout
            : ChatApiErrorType.upload,
      );
    } on http.ClientException {
      throw ChatApiException(
        attachment == null
            ? 'Could not reach Assistant. Check your connection and try again.'
            : 'Could not upload the file. Check your connection and try again.',
        type: attachment == null
            ? ChatApiErrorType.network
            : ChatApiErrorType.upload,
      );
    } on FormatException {
      throw const ChatApiException(
        'Assistant returned an unreadable streaming response.',
        type: ChatApiErrorType.invalidResponse,
      );
    } on Object {
      throw ChatApiException(
        attachment == null
            ? 'Something went wrong streaming the response.'
            : 'Something went wrong uploading the file.',
        type: attachment == null
            ? ChatApiErrorType.unknown
            : ChatApiErrorType.upload,
      );
    }
  }

  Future<http.Response> _sendJsonMessage(
    Uri uri, {
    required String message,
    String? conversationId,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    final payload = <String, dynamic>{'message': message};
    if (conversationId != null) {
      payload['conversation_id'] = conversationId;
    }
    if (financialContext != null) {
      payload['financial_context'] = financialContext;
    }
    if (writeConfirmation != null) {
      payload['write_confirmation'] = writeConfirmation;
    }
    _attachLocale(payload);

    return _apiClient.postJson('/chat', payload);
  }

  Future<http.Response> _sendMultipartMessage(
    Uri uri, {
    required String message,
    String? conversationId,
    required XFile attachment,
    Map<String, dynamic>? financialContext,
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..fields['message'] = message;
    if (conversationId != null) {
      request.fields['conversation_id'] = conversationId;
    }
    if (financialContext != null) {
      request.fields['financial_context'] = jsonEncode(financialContext);
    }
    final locale = _resolveLocale?.call()?.trim();
    if (locale != null && locale.isNotEmpty) {
      request.fields['locale'] = locale;
    }

    final fileName = resolvedChatAttachmentFileName(attachment);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await _attachmentBytes(attachment),
        filename: fileName,
        contentType: _attachmentMediaType(fileName),
      ),
    );

    final streamedResponse = await _apiClient.send(request);
    return http.Response.fromStream(streamedResponse);
  }

  http.BaseRequest _jsonStreamRequest(
    Uri uri, {
    required String message,
    String? conversationId,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) {
    final payload = <String, dynamic>{'message': message, 'stream': true};
    if (conversationId != null) {
      payload['conversation_id'] = conversationId;
    }
    if (financialContext != null) {
      payload['financial_context'] = financialContext;
    }
    if (writeConfirmation != null) {
      payload['write_confirmation'] = writeConfirmation;
    }
    final locale = _resolveLocale?.call()?.trim();
    if (locale != null && locale.isNotEmpty) {
      payload['locale'] = locale;
    }

    return http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(payload);
  }

  Future<http.BaseRequest> _multipartStreamRequest(
    Uri uri, {
    required String message,
    String? conversationId,
    required XFile attachment,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..fields['message'] = message
      ..fields['stream'] = 'true';
    if (conversationId != null) {
      request.fields['conversation_id'] = conversationId;
    }
    if (financialContext != null) {
      request.fields['financial_context'] = jsonEncode(financialContext);
    }
    if (writeConfirmation != null) {
      request.fields['write_confirmation'] = jsonEncode(writeConfirmation);
    }
    final locale = _resolveLocale?.call()?.trim();
    if (locale != null && locale.isNotEmpty) {
      request.fields['locale'] = locale;
    }

    final fileName = resolvedChatAttachmentFileName(attachment);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await _attachmentBytes(attachment),
        filename: fileName,
        contentType: _attachmentMediaType(fileName),
      ),
    );
    return request;
  }

  Future<List<int>> _attachmentBytes(XFile attachment) async {
    try {
      return await attachment.readAsBytes();
    } on Object {
      throw const ChatApiException(
        'Could not read selected file before upload.',
        type: ChatApiErrorType.upload,
      );
    }
  }

  MediaType? _attachmentMediaType(String fileName) {
    final contentType = chatAttachmentContentType(fileName);
    if (contentType == null) {
      return null;
    }
    return MediaType.parse(contentType);
  }

  @visibleForTesting
  Stream<ChatStreamEvent> parseSseEventsForTesting(Stream<List<int>> byteStream) {
    return _eventsFromSse(byteStream);
  }

  Stream<ChatStreamEvent> _eventsFromSse(Stream<List<int>> byteStream) async* {
    var eventName = 'message';
    final dataLines = <String>[];

    void reset() {
      eventName = 'message';
      dataLines.clear();
    }

    ChatStreamEvent? parseEvent() {
      if (dataLines.isEmpty) {
        reset();
        return null;
      }

      final currentEventName = eventName;
      final data = jsonDecode(dataLines.join('\n'));
      reset();
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid SSE payload.');
      }

      switch (currentEventName) {
        case 'conversation':
          final conversationId = data['conversation_id'];
          if (conversationId is String && conversationId.isNotEmpty) {
            return ChatStreamConversation(conversationId);
          }
          throw const FormatException('Missing streamed conversation id.');
        case 'token':
          final token = data['token'];
          return ChatStreamToken(token is String ? token : '');
        case 'done':
          return ChatStreamDone(ChatApiResponse.fromJson(data));
        case 'error':
          final detail = data['detail'];
          throw ChatApiException(
            detail is String && detail.trim().isNotEmpty
                ? detail
                : 'Assistant streaming failed.',
            type: ChatApiErrorType.unknown,
          );
        default:
          return null;
      }
    }

    await for (final line
        in byteStream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        final parsed = parseEvent();
        if (parsed != null) {
          yield parsed;
        }
        continue;
      }

      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }

    final parsed = parseEvent();
    if (parsed != null) {
      yield parsed;
    }
  }

  ChatApiResponse _chatResponseFromHttpResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatApiException(
        _errorMessage(response.body),
        type: _errorTypeForStatusCode(response.statusCode),
      );
    }

    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      throw const ChatApiException(
        'Assistant returned an unreadable response.',
        type: ChatApiErrorType.invalidResponse,
      );
    }
    if (data is! Map<String, dynamic>) {
      throw const ChatApiException(
        'Assistant returned an invalid response.',
        type: ChatApiErrorType.invalidResponse,
      );
    }

    return ChatApiResponse.fromJson(data);
  }

  ChatApiErrorType _errorTypeForStatusCode(int statusCode) {
    if (statusCode == 408 || statusCode == 504) {
      return ChatApiErrorType.timeout;
    }
    if (statusCode == 400 ||
        statusCode == 413 ||
        statusCode == 415 ||
        statusCode == 422) {
      return ChatApiErrorType.backendValidation;
    }

    return ChatApiErrorType.unknown;
  }

  String _errorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
        if (detail is Map<String, dynamic>) {
          final message = detail['message'] ?? detail['msg'];
          if (message is String && message.trim().isNotEmpty) {
            return message;
          }
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map<String, dynamic>) {
            final message = first['msg'] ?? first['message'];
            if (message is String && message.trim().isNotEmpty) {
              return message;
            }
          }
          return 'Request could not be processed.';
        }
      }
    } on FormatException {
      return 'Backend returned an unreadable error.';
    }

    return 'Clarity API returned an error.';
  }
}

sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStreamConversation extends ChatStreamEvent {
  const ChatStreamConversation(this.conversationId);

  final String conversationId;
}

class ChatStreamToken extends ChatStreamEvent {
  const ChatStreamToken(this.token);

  final String token;
}

class ChatStreamDone extends ChatStreamEvent {
  const ChatStreamDone(this.response);

  final ChatApiResponse response;
}
