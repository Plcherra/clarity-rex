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

  test('creates a morning routine commitment as a habit', () async {
    final api = _apiWith((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/commitments');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['commitment_type'], 'habit');
      expect(body['title'], 'Wake up at 5 AM');
      expect(body['metadata']['routine'], 'morning');
      return http.Response(
        jsonEncode({
          'id': 'commitment-1',
          'commitment_type': body['commitment_type'],
          'title': body['title'],
          'commitment_text': body['commitment_text'],
          'priority': body['priority'],
          'status': 'open',
          'active': true,
        }),
        201,
      );
    });

    final commitment = await api.createCommitment(
      title: 'Wake up at 5 AM',
      commitmentText: 'Wake up at 5 AM and start my morning routine',
      commitmentType: 'habit',
    );

    expect(commitment.id, 'commitment-1');
    expect(commitment.commitmentType, 'habit');
    expect(commitment.title, 'Wake up at 5 AM');
  });

  test(
    'completes and archives commitments with backend confirmation',
    () async {
      final paths = <String>[];
      final api = _apiWith((request) async {
        paths.add('${request.method} ${request.url.path}');
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['status'], 'completed');
          expect(body['active'], isFalse);
          return http.Response(
            jsonEncode({
              'id': 'commitment-1',
              'commitment_type': 'habit',
              'title': 'Wake up at 5 AM',
              'commitment_text': 'Wake up at 5 AM',
              'priority': 5,
              'status': 'completed',
              'active': false,
              'completed_at': body['completed_at'],
            }),
            200,
          );
        }
        expect(request.method, 'DELETE');
        return http.Response('', 204);
      });

      final completed = await api.completeCommitment('commitment-1');
      await api.archiveCommitment('commitment-1');

      expect(completed.status, 'completed');
      expect(completed.active, isFalse);
      expect(paths, [
        'PATCH /commitments/commitment-1',
        'DELETE /commitments/commitment-1',
      ]);
    },
  );

  test('marks commitments missed with backend confirmation', () async {
    final api = _apiWith((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/commitments/commitment-1');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['status'], 'missed');
      expect(body['active'], isFalse);
      expect(body['last_checked_at'], isA<String>());
      return http.Response(
        jsonEncode({
          'id': 'commitment-1',
          'commitment_type': 'habit',
          'title': 'Wake up at 5 AM',
          'commitment_text': 'Wake up at 5 AM',
          'priority': 5,
          'status': 'missed',
          'active': false,
          'last_checked_at': body['last_checked_at'],
        }),
        200,
      );
    });

    final missed = await api.missCommitment('commitment-1');

    expect(missed.status, 'missed');
    expect(missed.active, isFalse);
  });

  test('archives plans with backend confirmation', () async {
    final api = _apiWith((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/plans/plan-1');
      return http.Response('', 204);
    });

    await api.archivePlan('plan-1');
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
