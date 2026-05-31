import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/features/assistant/memory/data/memory_api.dart';

void main() {
  test('MemoryApi lists pending memory candidates', () async {
    final requests = <http.Request>[];
    final api = MemoryApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '[{"id":"candidate-1","candidate_type":"long_term_memory","status":"pending","risk_level":"medium","preview":"long_term_memory: Pedro prefers email"}]',
            200,
          );
        }),
      ),
    );

    final candidates = await api.getMemoryCandidates(limit: 25);

    expect(requests.single.url.path, '/memory-candidates');
    expect(requests.single.url.queryParameters['status'], 'pending');
    expect(requests.single.url.queryParameters['limit'], '25');
    expect(candidates.single.id, 'candidate-1');
    expect(candidates.single.candidateTypeLabel, 'Memory');
    expect(candidates.single.previewLabel, 'Memory: Pedro prefers email');
  });

  test('MemoryApi posts approve and reject candidate decisions', () async {
    final requests = <http.Request>[];
    final api = MemoryApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"id":"candidate-1","candidate_type":"correction","status":"applied","risk_level":"high","preview":"correction: Fix old fact"}',
            200,
          );
        }),
      ),
    );

    final approved = await api.approveMemoryCandidate('candidate-1');
    final rejected = await api.rejectMemoryCandidate('candidate-1');

    expect(requests.first.url.path, '/memory-candidates/candidate-1/approve');
    expect(requests.first.body, contains('"approved_by":"user"'));
    expect(requests.last.url.path, '/memory-candidates/candidate-1/reject');
    expect(requests.last.body, contains('"Rejected from Memory review."'));
    expect(approved.statusLabel, 'Saved');
    expect(rejected.candidateTypeLabel, 'Correction');
  });

  test('MemoryApi patches pending memory candidates before approval', () async {
    final requests = <http.Request>[];
    final api = MemoryApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"id":"candidate-1","candidate_type":"long_term_memory","status":"pending","risk_level":"medium","reason":"Edited by Pedro.","payload":{"content":"Pedro prefers concise email."},"preview":"long_term_memory: Pedro prefers concise email."}',
            200,
          );
        }),
      ),
    );

    final updated = await api.updateMemoryCandidate(
      'candidate-1',
      payload: {'content': 'Pedro prefers concise email.'},
      reason: 'Edited by Pedro.',
    );

    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/memory-candidates/candidate-1');
    expect(
      requests.single.body,
      contains('"content":"Pedro prefers concise email."'),
    );
    expect(requests.single.body, contains('"reason":"Edited by Pedro."'));
    expect(updated.previewLabel, 'Memory: Pedro prefers concise email.');
    expect(updated.reasonLabel, 'Edited by Pedro.');
    expect(updated.editableProposal, 'Pedro prefers concise email.');
  });

  test('MemoryApi archives memory through the safe deactivate route', () async {
    final requests = <http.Request>[];
    final api = MemoryApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
      ),
    );

    await api.archiveMemory('memory-1');

    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/memory/memory-1');
  });
}

String? _testAccessToken() => 'test-token';
