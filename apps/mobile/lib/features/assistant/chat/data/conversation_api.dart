import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/features/assistant/chat/data/chat_models.dart';
import 'package:clarity/features/assistant/chat/domain/chat_message.dart';
import 'package:clarity/features/assistant/chat/data/chat_api.dart';

final conversationApiProvider = Provider<ConversationApi>(
  (ref) => ConversationApi(),
);

class ConversationApi {
  ConversationApi({
    http.Client? client,
    String? baseUrl,
    RexAuthHeaders? authHeaders,
    RexApiClient? apiClient,
  }) : _apiClient =
          apiClient ??
          RexApiClient(
            httpClient: client,
            baseUrl: baseUrl,
            authHeaders: authHeaders,
          );

  final RexApiClient _apiClient;

  Future<List<Conversation>> getConversations() async {
    final response = await _apiClient.get('/conversations');
    final data = _decodeResponse(response);

    if (data is! List) {
      throw const ChatApiException('Backend returned an invalid response.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(Conversation.fromJson)
        .toList(growable: false);
  }

  Future<Conversation> createConversation() async {
    final response = await _apiClient.post('/conversations');
    final data = _decodeResponse(response);

    if (data is! Map<String, dynamic>) {
      throw const ChatApiException('Backend returned an invalid response.');
    }

    return Conversation.fromJson(data);
  }

  Future<List<ChatMessage>> getConversationMessages(
    String conversationId,
  ) async {
    final response = await _apiClient.get(
      '/conversations/$conversationId/messages',
    );
    final data = _decodeResponse(response);

    if (data is! List) {
      throw const ChatApiException('Backend returned an invalid response.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ChatApiMessage.fromJson)
        .map((message) => message.toDomain())
        .toList(growable: false);
  }

  Future<void> deleteConversation(String conversationId) async {
    final response = await _apiClient.delete('/conversations/$conversationId');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatApiException(_errorMessage(response.body));
    }
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatApiException(_errorMessage(response.body));
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ChatApiException('Backend returned an unreadable response.');
    }
  }

  String _errorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          return 'Request could not be processed.';
        }
      }
    } on FormatException {
      return 'Backend returned an unreadable error.';
    }

    return 'Rex backend returned an error.';
  }
}
