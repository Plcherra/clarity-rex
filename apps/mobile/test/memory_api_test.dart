import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/features/assistant/memory/data/memory_api.dart';

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
}

String? _testAccessToken() => 'test-token';
