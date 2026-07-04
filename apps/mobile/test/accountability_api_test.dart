import 'dart:convert';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/accountability/data/accountability_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('creates a simple plan through Rex API', () async {
    final requests = <http.Request>[];
    final api = _apiWith((request) async {
      requests.add(request);
      expect(request.method, 'POST');
      expect(request.url.path, '/plans');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['plan_type'], 'personal');
      expect(body['title'], 'Build morning routine');
      return http.Response(
        jsonEncode({
          'id': 'plan-1',
          'plan_type': 'personal',
          'title': body['title'],
          'description': body['description'],
          'desired_outcome': body['desired_outcome'],
          'priority': body['priority'],
          'status': 'active',
          'active': true,
        }),
        201,
      );
    });

    final plan = await api.createPlan(
      title: 'Build morning routine',
      description: 'Wake up at 5 AM.',
    );

    expect(requests.single.url.path, '/plans');
    expect(plan.id, 'plan-1');
    expect(plan.title, 'Build morning routine');
  });

  test('archives plans with backend confirmation', () async {
    final api = _apiWith((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/plans/plan-1');
      return http.Response('', 204);
    });

    await api.archivePlan('plan-1');
  });

  test('creates an open thread through Rex API', () async {
    final api = _apiWith((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/open-threads');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['title'], 'Morning routine');
      expect(body['source'], 'user_created');
      return http.Response(
        jsonEncode({
          'id': 'thread-1',
          'title': body['title'],
          'summary': body['summary'],
          'status': 'active',
          'source': 'user_created',
        }),
        201,
      );
    });

    final thread = await api.createOpenThread(
      title: 'Morning routine',
      summary: 'Trying to wake up earlier',
    );

    expect(thread.id, 'thread-1');
    expect(thread.title, 'Morning routine');
    expect(thread.status, 'active');
  });
}

AccountabilityApi _apiWith(MockClientHandler handler) {
  return AccountabilityApi(
    apiClient: RexApiClient(
      baseUrl: 'https://api.example.test',
      authHeaders: RexAuthHeaders(accessTokenProvider: () => 'token'),
      httpClient: MockClient(handler),
    ),
  );
}
