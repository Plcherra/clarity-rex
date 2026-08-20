import 'dart:convert';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/features/plaid/application/plaid_link_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PlaidLinkService', () {
    test(
      'fetches link token, opens launcher, and exchanges public token',
      () async {
        final tokenApi = _FakePlaidLinkTokenApi(
          token: const PlaidLinkToken(
            value: 'link-production-test',
            expiration: '2026-06-08T06:27:00Z',
          ),
        );
        final launcher = _FakePlaidLinkLauncher(
          result: const PlaidLinkLaunchSuccess(
            publicToken: 'public-production-test',
            institutionName: 'Bank of Test',
            accountCount: 2,
          ),
        );
        final exchangeApi = _FakePlaidExchangeApi();
        final service = PlaidLinkService(
          tokenApi: tokenApi,
          exchangeApi: exchangeApi,
          launcher: launcher,
        );

        final result = await service.connectBank();

        expect(tokenApi.calls, 1);
        expect(launcher.openedToken?.value, 'link-production-test');
        expect(exchangeApi.exchangedPublicToken, 'public-production-test');
        expect(exchangeApi.exchangedInstitutionName, 'Bank of Test');
        expect(result, isA<PlaidConnectionSuccess>());
        final success = result as PlaidConnectionSuccess;
        expect(success.itemId, 'item-record-1');
        expect(success.accountsSynced, 2);
      },
    );

    test('does not open launcher when token creation fails', () async {
      final tokenApi = _ThrowingPlaidLinkTokenApi();
      final launcher = _FakePlaidLinkLauncher(
        result: const PlaidLinkLaunchExit(status: 'unused'),
      );
      final service = PlaidLinkService(tokenApi: tokenApi, launcher: launcher);

      await expectLater(
        service.connectBank(),
        throwsA(isA<PlaidLinkServiceException>()),
      );

      expect(launcher.openedToken, isNull);
    });

    test('does not exchange token when user exits Link', () async {
      final tokenApi = _FakePlaidLinkTokenApi(
        token: const PlaidLinkToken(value: 'link-production-test'),
      );
      final launcher = _FakePlaidLinkLauncher(
        result: const PlaidLinkLaunchExit(status: 'requiresCredentials'),
      );
      final exchangeApi = _FakePlaidExchangeApi();
      final service = PlaidLinkService(
        tokenApi: tokenApi,
        exchangeApi: exchangeApi,
        launcher: launcher,
      );

      final result = await service.connectBank();

      expect(result, isA<PlaidConnectionExit>());
      expect(exchangeApi.exchangedPublicToken, isNull);
    });

    test(
      'fails clearly when Link success does not include public token',
      () async {
        final tokenApi = _FakePlaidLinkTokenApi(
          token: const PlaidLinkToken(value: 'link-production-test'),
        );
        final launcher = _FakePlaidLinkLauncher(
          result: const PlaidLinkLaunchSuccess(
            publicToken: '   ',
            institutionName: 'Bank of Test',
            accountCount: 2,
          ),
        );
        final exchangeApi = _FakePlaidExchangeApi();
        final service = PlaidLinkService(
          tokenApi: tokenApi,
          exchangeApi: exchangeApi,
          launcher: launcher,
        );

        await expectLater(
          service.connectBank(),
          throwsA(
            isA<PlaidLinkServiceException>().having(
              (error) => error.message,
              'message',
              contains('Plaid did not return the token'),
            ),
          ),
        );

        expect(exchangeApi.exchangedPublicToken, isNull);
      },
    );

    test('parses native iOS success payload into launch success', () {
      final result = NativePlaidLinkLauncher.launchResultFromNative({
        'type': 'success',
        'publicToken': ' public-production-native ',
        'institutionId': 'ins_127989',
        'institutionName': 'Bank of America',
        'accountCount': 2,
      });

      expect(result, isNotNull);
      expect(result, isA<PlaidLinkLaunchSuccess>());
      final success = result as PlaidLinkLaunchSuccess;
      expect(success.publicToken, 'public-production-native');
      expect(success.institutionId, 'ins_127989');
      expect(success.institutionName, 'Bank of America');
      expect(success.accountCount, 2);
    });

    test('ignores native iOS success payload without public token', () {
      final result = NativePlaidLinkLauncher.launchResultFromNative({
        'type': 'success',
        'publicToken': ' ',
        'institutionId': 'ins_127989',
        'institutionName': 'Bank of America',
      });

      expect(result, isNull);
    });

    test('parses sanitized exchange account summaries', () async {
      final api = RexPlaidApi(
        apiClient: RexApiClient(
          baseUrl: 'https://api.example.test',
          authHeaders: RexAuthHeaders(accessTokenProvider: _testAccessToken),
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(
              request.url.toString(),
              'https://api.example.test/plaid/exchange-token',
            );
            expect(request.headers['Authorization'], 'Bearer test-token');
            expect(jsonDecode(request.body), {
              'public_token': 'public-production-test',
              'institution_id': 'ins_1',
              'institution_name': 'Bank of Test',
            });
            return http.Response(
              jsonEncode({
                'plaid_item_record_id': 'item-record-1',
                'status': 'active',
                'institution_name': 'Bank of Test',
                'accounts': [
                  {
                    'linked_account_id': 'account-1',
                    'plaid_item_record_id': 'item-record-1',
                    'institution_name': 'Bank of Test',
                    'name': 'Adv Plus Banking',
                    'official_name': 'Advantage Plus Banking',
                    'mask': '1234',
                    'account_type': 'depository',
                    'account_subtype': 'checking',
                    'status': 'active',
                    'current_balance': 1250.25,
                    'available_balance': 1200,
                    'iso_currency_code': 'USD',
                  },
                ],
                'accounts_synced': 1,
                'transactions_added': 3,
                'transactions_modified': 1,
                'transactions_removed': 0,
              }),
              200,
            );
          }),
        ),
      );

      final result = await api.exchangePublicToken(
        const PlaidLinkLaunchSuccess(
          publicToken: 'public-production-test',
          institutionId: 'ins_1',
          institutionName: 'Bank of Test',
          accountCount: 1,
        ),
      );

      expect(result.itemId, 'item-record-1');
      expect(result.accountsSynced, 1);
      expect(result.accounts, hasLength(1));
      expect(result.accounts.single.linkedAccountId, 'account-1');
      expect(result.accounts.single.name, 'Adv Plus Banking');
      expect(result.accounts.single.officialName, 'Advantage Plus Banking');
      expect(result.accounts.single.mask, '1234');
      expect(result.accounts.single.currentBalance, 1250.25);
      expect(result.accounts.single.availableBalance, 1200);
      expect(result.accounts.single.isoCurrencyCode, 'USD');
    });

    test('reconnect opens update-mode Link and does not exchange', () async {
      final tokenApi = _FakePlaidLinkTokenApi(
        token: const PlaidLinkToken(value: 'link-update-test'),
      );
      final launcher = _FakePlaidLinkLauncher(
        result: const PlaidLinkLaunchSuccess(
          publicToken: 'public-should-not-exchange',
          institutionName: 'Bank of Test',
          accountCount: 1,
        ),
      );
      final exchangeApi = _FakePlaidExchangeApi();
      var completedItemId = '';
      final service = PlaidLinkService(
        tokenApi: tokenApi,
        exchangeApi: exchangeApi,
        launcher: launcher,
      );

      final result = await service.reconnectBank(
        'item-record-9',
        completeUpdate: (itemId) async {
          completedItemId = itemId;
          return const PlaidSyncSummary(
            itemId: 'item-record-9',
            accountsSynced: 2,
            transactionsAdded: 1,
            transactionsModified: 0,
            transactionsRemoved: 0,
          );
        },
      );

      expect(tokenApi.lastItemId, 'item-record-9');
      expect(launcher.openedToken?.value, 'link-update-test');
      expect(exchangeApi.exchangedPublicToken, isNull);
      expect(completedItemId, 'item-record-9');
      expect(result, isA<PlaidConnectionSuccess>());
      expect((result as PlaidConnectionSuccess).status, 'active');
    });
  });
}

String? _testAccessToken() => 'test-token';

final class _FakePlaidLinkTokenApi implements PlaidLinkTokenApi {
  _FakePlaidLinkTokenApi({required this.token});

  final PlaidLinkToken token;
  String? lastItemId;
  int calls = 0;

  @override
  Future<PlaidLinkToken> createLinkToken({String? itemId}) async {
    calls++;
    lastItemId = itemId;
    return token;
  }
}

final class _ThrowingPlaidLinkTokenApi implements PlaidLinkTokenApi {
  @override
  Future<PlaidLinkToken> createLinkToken({String? itemId}) {
    throw const PlaidLinkServiceException('Missing Plaid config.');
  }
}

final class _FakePlaidExchangeApi implements PlaidPublicTokenExchangeApi {
  String? exchangedPublicToken;
  String? exchangedInstitutionName;

  @override
  Future<PlaidConnectionSuccess> exchangePublicToken(
    PlaidLinkLaunchSuccess success,
  ) async {
    exchangedPublicToken = success.publicToken;
    exchangedInstitutionName = success.institutionName;
    return const PlaidConnectionSuccess(
      itemId: 'item-record-1',
      status: 'active',
      institutionName: 'Bank of Test',
      accountsSynced: 2,
      transactionsAdded: 3,
      transactionsModified: 1,
      transactionsRemoved: 0,
    );
  }
}

final class _FakePlaidLinkLauncher implements PlaidLinkLauncher {
  _FakePlaidLinkLauncher({required this.result});

  final PlaidLinkLaunchResult result;
  PlaidLinkToken? openedToken;

  @override
  Future<PlaidLinkLaunchResult> open(PlaidLinkToken token) async {
    openedToken = token;
    return result;
  }
}
