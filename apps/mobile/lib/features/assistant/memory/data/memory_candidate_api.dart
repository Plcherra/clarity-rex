part of 'memory_api.dart';

mixin _MemoryCandidateApi on _MemoryApiTransport {
  Future<List<PendingMemoryCandidateItem>> getMemoryCandidates({
    String status = 'pending',
    int limit = 50,
  }) async {
    final data = await _getList('/memory-candidates', {
      'status': status,
      'limit': limit.toString(),
    });
    return data
        .map(PendingMemoryCandidateItem.fromJson)
        .toList(growable: false);
  }

  Future<PendingMemoryCandidateItem> approveMemoryCandidate(
    String candidateId,
  ) async {
    final response = await _apiClient.postJson(
      '/memory-candidates/$candidateId/approve',
      {'approved_by': 'user'},
    );
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const MemoryApiException('Backend returned an invalid response.');
    }
    return PendingMemoryCandidateItem.fromJson(data);
  }

  Future<PendingMemoryCandidateItem> updateMemoryCandidate(
    String candidateId, {
    Map<String, dynamic>? payload,
    String? reason,
  }) async {
    final body = _withoutNulls({'payload': payload, 'reason': reason});
    final data = await _patchJson('/memory-candidates/$candidateId', body);
    return PendingMemoryCandidateItem.fromJson(data);
  }

  Future<PendingMemoryCandidateItem> rejectMemoryCandidate(
    String candidateId,
  ) async {
    final response = await _apiClient.postJson(
      '/memory-candidates/$candidateId/reject',
      {'reason': 'Rejected from Memory review.'},
    );
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const MemoryApiException('Backend returned an invalid response.');
    }
    return PendingMemoryCandidateItem.fromJson(data);
  }
}
