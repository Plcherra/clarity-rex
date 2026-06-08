import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/features/accounts/data/plaid_account_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PlaidAccountService', () {
    test('fetches connected item status and last synced time', () async {
      final service = _serviceWith((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/plaid/item-status/item-record-1');
        return http.Response('''
          {
            "plaid_item_record_id": "item-record-1",
            "status": "active",
            "institution_name": "Bank of Test",
            "last_synced_at": "2026-06-08T12:00:00Z"
          }
          ''', 200);
      });

      final status = await service.fetchItemStatus('item-record-1');

      expect(status.itemId, 'item-record-1');
      expect(status.status, PlaidAccountConnectionStatus.connected);
      expect(status.institutionName, 'Bank of Test');
      expect(status.lastSyncedAt, isNotNull);
    });

    test('maps login-required status to degraded', () async {
      final service = _serviceWith((request) async {
        return http.Response('''
          {
            "plaid_item_record_id": "item-record-1",
            "status": "login_required"
          }
          ''', 200);
      });

      final status = await service.fetchItemStatus('item-record-1');

      expect(status.status, PlaidAccountConnectionStatus.degraded);
    });

    test('syncs item and returns safe counts', () async {
      final service = _serviceWith((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/plaid/sync-item/item-record-1');
        return http.Response('''
          {
            "plaid_item_record_id": "item-record-1",
            "accounts_synced": 2,
            "transactions_added": 4,
            "transactions_modified": 1,
            "transactions_removed": 0
          }
          ''', 200);
      });

      final summary = await service.syncItem('item-record-1');

      expect(summary.itemId, 'item-record-1');
      expect(summary.accountsSynced, 2);
      expect(summary.transactionsAdded, 4);
      expect(summary.transactionsModified, 1);
    });

    test('returns safe backend error detail', () async {
      final service = _serviceWith((request) async {
        return http.Response('{"detail":"Plaid item was not found."}', 404);
      });

      await expectLater(
        service.fetchItemStatus('missing-item'),
        throwsA(
          isA<PlaidAccountServiceException>().having(
            (error) => error.message,
            'message',
            'Plaid item was not found.',
          ),
        ),
      );
    });
  });
}

PlaidAccountService _serviceWith(MockClientHandler handler) {
  return PlaidAccountService(
    apiClient: RexApiClient(
      baseUrl: 'https://api.example.test',
      authHeaders: RexAuthHeaders(accessTokenProvider: () => 'token'),
      httpClient: MockClient(handler),
    ),
  );
}
