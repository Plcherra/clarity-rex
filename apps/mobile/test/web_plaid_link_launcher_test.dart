import 'package:clarity/features/plaid/application/plaid_link_service.dart';
import 'package:clarity/features/plaid/application/web_plaid_link_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebPlaidLinkLauncher parsing', () {
    test('detects OAuth redirect return URLs', () {
      expect(
        readPlaidOAuthRedirectUriFromHref(
          'https://goclarity.app/app/?oauth_state_id=abc123',
        ),
        'https://goclarity.app/app/?oauth_state_id=abc123',
      );
      expect(
        readPlaidOAuthRedirectUriFromHref('https://goclarity.app/app/'),
        isNull,
      );
    });

    test('parses web success metadata into launch success', () {
      final result = launchResultFromWebSuccess(
        ' public-production-web ',
        {
          'institution': {
            'institution_id': 'ins_127989',
            'name': 'Bank of America',
          },
          'accounts': [
            {'id': 'acc_1'},
            {'id': 'acc_2'},
          ],
        },
      );

      expect(result, isA<PlaidLinkLaunchSuccess>());
      final success = result as PlaidLinkLaunchSuccess;
      expect(success.publicToken, 'public-production-web');
      expect(success.institutionId, 'ins_127989');
      expect(success.institutionName, 'Bank of America');
      expect(success.accountCount, 2);
    });

    test('returns null when web success payload lacks public token', () {
      expect(launchResultFromWebSuccess(' ', const {}), isNull);
    });

    test('parses web exit metadata into launch exit', () {
      final result = launchResultFromWebExit(
        {
          'error_code': 'INVALID_CREDENTIALS',
          'error_type': 'ITEM_ERROR',
        },
        {
          'status': 'requires_credentials',
          'request_id': 'req-web-1',
        },
      );

      expect(result, isA<PlaidLinkLaunchExit>());
      final exit = result as PlaidLinkLaunchExit;
      expect(exit.status, 'requires_credentials');
      expect(exit.errorCode, 'INVALID_CREDENTIALS');
      expect(exit.errorType, 'ITEM_ERROR');
      expect(exit.requestId, 'req-web-1');
    });

    test('clears oauth query params from history href without throwing', () {
      expect(
        () => clearPlaidOAuthRedirectFromHistoryForHref(
          'https://goclarity.app/app/',
        ),
        returnsNormally,
      );
    });
  });
}
