import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/data/chat_api.dart';

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

  Future<List<ConversationSearchResult>> searchConversations(
    String query,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final response = await _apiClient.get(
      '/conversations/search',
      query: {'q': trimmed},
    );
    final data = _decodeResponse(response);

    if (data is! List) {
      throw const ChatApiException('Backend returned an invalid response.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ConversationSearchResult.fromJson)
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

    return 'Clarity API returned an error.';
  }
}

class ConversationSearchResult {
  const ConversationSearchResult({
    required this.conversationId,
    required this.matchType,
    required this.preview,
    this.conversationTitle,
    this.conversationTimestamp,
    this.message,
    this.relevanceScore,
    this.searchReason,
    this.matchedTerms = const <String>[],
  });

  final String conversationId;
  final String matchType;
  final String preview;
  final String? conversationTitle;
  final DateTime? conversationTimestamp;
  final ChatApiMessage? message;
  final double? relevanceScore;
  final String? searchReason;
  final List<String> matchedTerms;

  factory ConversationSearchResult.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    return ConversationSearchResult(
      conversationId: json['conversation_id'] as String? ?? '',
      conversationTitle: json['conversation_title'] as String?,
      conversationTimestamp: _dateTimeOrNull(json['conversation_timestamp']),
      matchType: json['match_type'] as String? ?? 'message',
      preview: json['preview'] as String? ?? '',
      message: message is Map<String, dynamic>
          ? ChatApiMessage.fromJson(message)
          : null,
      relevanceScore: _doubleOrNull(json['relevance_score']),
      searchReason: json['search_reason'] as String?,
      matchedTerms:
          (json['matched_terms'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
    );
  }
}

double? _doubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
