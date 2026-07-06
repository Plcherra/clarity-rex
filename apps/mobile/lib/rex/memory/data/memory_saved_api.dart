part of 'memory_api.dart';

mixin _SavedMemoryApi on _MemoryApiTransport {
  Future<List<MemoryItem>> getMemories({
    MemoryType? memoryType,
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    final page = await getMemoriesPaged(
      memoryType: memoryType,
      active: active,
      limit: limit,
    );
    return page.items;
  }

  Future<MemoryPagedResult<MemoryItem>> getMemoriesPaged({
    MemoryType? memoryType,
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };
    if (memoryType != null) {
      query['memory_type'] = memoryType.apiValue;
    }
    if (active != null) {
      query['active'] = active.toString();
    }

    final data = await _getPagedMap('/memory', query);
    return MemoryPagedResult.fromJson(data, MemoryItem.fromJson);
  }

  Future<MemoryItem> createMemory({
    required MemoryType memoryType,
    required String content,
    int importance = 3,
    String? memoryCategory,
  }) async {
    final data = await _postJson('/memory', _withoutNulls({
      'memory_type': memoryType.apiValue,
      'content': content,
      'importance': importance,
      'memory_category': memoryCategory,
    }));
    return MemoryItem.fromJson(data);
  }

  Future<MemoryItem> updateMemory(
    String memoryId, {
    MemoryType? memoryType,
    String? content,
    int? importance,
    bool? active,
  }) async {
    final body = <String, dynamic>{};
    if (memoryType != null && memoryType != MemoryType.other) {
      body['memory_type'] = memoryType.apiValue;
    }
    if (content != null) {
      body['content'] = content;
    }
    if (importance != null) {
      body['importance'] = importance;
    }
    if (active != null) {
      body['active'] = active;
    }

    final response = await _apiClient.patchJson('/memory/$memoryId', body);
    final data = _decodeResponse(response);

    if (data is! Map<String, dynamic>) {
      throw const MemoryApiException('Backend returned an invalid response.');
    }

    return MemoryItem.fromJson(data);
  }

  Future<void> deactivateMemory(String memoryId) async {
    await _delete('/memory/$memoryId');
  }

  Future<Map<String, dynamic>> getSavedKnowledgeOverview({
    bool activeOnly = true,
    int limit = kMemoryListLimit,
  }) async {
    final response = await _apiClient.get(
      '/saved-knowledge/overview',
      query: {
        'active_only': activeOnly.toString(),
        'limit': limit.toString(),
      },
    );
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const MemoryApiException('Backend returned an invalid response.');
    }
    return data;
  }

  Future<void> archiveMemory(String memoryId) async {
    await deactivateMemory(memoryId);
  }
}
