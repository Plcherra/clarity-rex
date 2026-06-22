import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/actions/data/clarity_actions_api.dart';
import 'package:clarity/rex/chat/data/chat_api.dart';

void main() {
  test(
    'RexApiClient attaches Supabase bearer token to HTTP requests',
    () async {
      final requests = <http.Request>[];
      final client = RexApiClient(
        baseUrl: 'https://clarity.example.com/api',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('{"ok":true}', 200);
        }),
      );

      await client.get('/memory', query: {'limit': '10'});
      await client.postJson('/chat', {'message': 'hello'});

      expect(requests, hasLength(2));
      expect(
        requests.first.url.toString(),
        'https://clarity.example.com/api/memory?limit=10',
      );
      expect(requests.first.headers['Authorization'], 'Bearer test-token');
      expect(requests.last.headers['Authorization'], 'Bearer test-token');
      expect(requests.last.headers['Content-Type'], 'application/json');
      expect(requests.last.body, '{"message":"hello"}');
    },
  );

  test('RexApiClient builds websocket URLs without leaking access tokens', () {
    final client = RexApiClient(
      baseUrl: 'https://clarity.example.com/rex',
      authHeaders: const RexAuthHeaders(accessTokenProvider: _testAccessToken),
    );

    final uri = client.webSocketUri('/voice/stream');

    expect(uri.scheme, 'wss');
    expect(uri.path, '/rex/voice/stream');
    expect(uri.queryParameters, isEmpty);
    expect(client.authHeaders()['Authorization'], 'Bearer test-token');
  });

  test('RexAuthHeaders rejects missing sessions', () {
    const headers = RexAuthHeaders(accessTokenProvider: _missingAccessToken);

    expect(headers.headers, throwsA(isA<RexAuthException>()));
  });

  test('ChatApi sends full Clarity financial context', () async {
    final requests = <http.Request>[];
    final chatApi = ChatApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"conversation_id":"conversation-1","response":"ok","messages":[]}',
            200,
          );
        }),
      ),
    );

    await chatApi.sendMessage(
      'How am I doing?',
      financialContext: {
        'schema': 'clarity_unified_financial_context_v1',
        'cash_flow': {'spent_this_month': 1200.50},
        'transactions': [
          {'id': 'transaction-1', 'merchant': 'Coffee Shop', 'amount': 6.25},
        ],
      },
    );

    expect(requests.single.headers['Authorization'], 'Bearer test-token');
    expect(requests.single.body, contains('"financial_context"'));
    expect(requests.single.body, isNot(contains('deep_think')));
    expect(requests.single.body, contains('"spent_this_month":1200.5'));
    expect(requests.single.body, contains('"transactions"'));
    expect(requests.single.body, contains('"Coffee Shop"'));
  });

  test('ChatApi maps request timeouts to retryable Assistant errors', () async {
    final chatApi = ChatApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        requestTimeout: const Duration(milliseconds: 5),
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(
            '{"conversation_id":"conversation-1","response":"ok","messages":[]}',
            200,
          );
        }),
      ),
    );

    await expectLater(
      chatApi.sendMessage('Do you remember Jessica?'),
      throwsA(
        isA<ChatApiException>()
            .having((error) => error.type, 'type', ChatApiErrorType.timeout)
            .having(
              (error) => error.message,
              'message',
              contains('too long'),
            ),
      ),
    );
  });

  test('ChatApi sends PDF attachments with filename and content type', () async {
    final requests = <http.Request>[];
    final chatApi = ChatApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"conversation_id":"conversation-1","response":"ok","messages":[]}',
            200,
          );
        }),
      ),
    );

    await chatApi.sendMessage(
      'Read this PDF.',
      attachment: XFile.fromData(
        Uint8List.fromList('%PDF-1.4 test'.codeUnits),
        name: 'statement.pdf',
        mimeType: 'application/pdf',
        path: 'statement.pdf',
      ),
    );

    final request = requests.single;
    final body = String.fromCharCodes(request.bodyBytes);

    expect(request.headers['Authorization'], 'Bearer test-token');
    expect(request.headers['content-type'], contains('multipart/form-data'));
    expect(body, contains('name="file"'));
    expect(body, contains('filename="statement.pdf"'));
    expect(body.toLowerCase(), contains('content-type: application/pdf'));
    expect(body, contains('%PDF-1.4 test'));
  });

  test('ChatApi surfaces backend upload validation details', () async {
    final chatApi = ChatApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          return http.Response(
            '{"detail":"Uploaded PDF does not contain readable text."}',
            400,
          );
        }),
      ),
    );

    expect(
      () => chatApi.sendMessage(
        'Read this PDF.',
        attachment: XFile.fromData(
          Uint8List.fromList('%PDF-1.4 test'.codeUnits),
          name: 'scanned.pdf',
          mimeType: 'application/pdf',
          path: 'scanned.pdf',
        ),
      ),
      throwsA(
        isA<ChatApiException>().having(
          (error) => error.message,
          'message',
          'Uploaded PDF does not contain readable text.',
        ),
      ),
    );
  });

  test('ClarityActionsApi posts confirmed action requests', () async {
    final requests = <http.Request>[];
    final actionsApi = ClarityActionsApi(
      apiClient: RexApiClient(
        baseUrl: 'https://clarity.example.com',
        authHeaders: const RexAuthHeaders(
          accessTokenProvider: _testAccessToken,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"action":"update_transaction","status":"applied","result":[{"id":"transaction-1"}]}',
            200,
          );
        }),
      ),
    );

    final result = await actionsApi.execute(
      action: 'update_transaction',
      confirmed: true,
      payload: {'id': 'transaction-1', 'merchant': 'Coffee Shop'},
    );

    expect(requests.single.url.path, '/clarity/actions');
    expect(requests.single.headers['Authorization'], 'Bearer test-token');
    expect(requests.single.body, contains('"confirmed":true'));
    expect(requests.single.body, contains('"update_transaction"'));
    expect(result.status, 'applied');
    expect(result.result.single['id'], 'transaction-1');
  });
}

String? _testAccessToken() => 'test-token';

String? _missingAccessToken() => null;
