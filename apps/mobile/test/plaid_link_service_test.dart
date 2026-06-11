import 'package:clarity/features/plaid/application/plaid_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}

final class _FakePlaidLinkTokenApi implements PlaidLinkTokenApi {
  _FakePlaidLinkTokenApi({required this.token});

  final PlaidLinkToken token;
  int calls = 0;

  @override
  Future<PlaidLinkToken> createLinkToken() async {
    calls++;
    return token;
  }
}

final class _ThrowingPlaidLinkTokenApi implements PlaidLinkTokenApi {
  @override
  Future<PlaidLinkToken> createLinkToken() {
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
