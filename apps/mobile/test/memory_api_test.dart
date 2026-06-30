import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/memory/data/memory_constants.dart';
import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';

const _emptyPagedResponse =
    '{"items":[],"next_cursor":null,"has_more":false}';

void main() {
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

  test('MemoryApi passes active filters only when requested', () async {
    final requests = <http.Request>[];
    final api = MemoryApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(_emptyPagedResponse, 200);
        }),
      ),
    );

    await api.getMemories(active: true);
    await api.getEntities(active: true);
    await api.getPeople(active: true);
    await api.getPeople();

    expect(requests[0].url.path, '/memory');
    expect(requests[0].url.queryParameters['active'], 'true');
    expect(requests[0].url.queryParameters['paginated'], 'true');
    expect(requests[1].url.path, '/entities');
    expect(requests[1].url.queryParameters['active'], 'true');
    expect(requests[1].url.queryParameters['paginated'], 'true');
    expect(requests[1].url.queryParameters.containsKey('entity_type'), isFalse);
    expect(requests[2].url.path, '/entities');
    expect(requests[2].url.queryParameters['active'], 'true');
    expect(requests[2].url.queryParameters['paginated'], 'true');
    expect(requests[2].url.queryParameters['entity_type'], 'person');
    expect(requests[3].url.path, '/entities');
    expect(requests[3].url.queryParameters.containsKey('active'), isFalse);
    expect(requests[3].url.queryParameters['paginated'], 'true');
    expect(requests[3].url.queryParameters['entity_type'], 'person');
  });

  test('MemoryApi getEntities uses the shared list limit', () async {
    final requests = <http.Request>[];
    final api = MemoryApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(_emptyPagedResponse, 200);
        }),
      ),
    );

    await api.getEntities(active: true);

    expect(requests.single.url.queryParameters['limit'], '$kMemoryListLimit');
    expect(requests.single.url.queryParameters['paginated'], 'true');
  });

  test('MemoryApi creates memory through POST /memory', () async {
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
            '{"id":"memory-9","memory_type":"fact","content":"Pedro lives in Somerville.","importance":3,"active":true,"metadata":{}}',
            201,
          );
        }),
      ),
    );

    final memory = await api.createMemory(
      memoryType: MemoryType.fact,
      content: 'Pedro lives in Somerville.',
      memoryCategory: 'Places',
    );

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/memory');
    expect(memory.id, 'memory-9');
    expect(memory.content, 'Pedro lives in Somerville.');
  });
}

String? _testAccessToken() => 'test-token';
