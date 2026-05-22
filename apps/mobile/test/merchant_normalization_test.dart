import 'package:clarity/features/transactions/domain/merchant_normalization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('merchantKeyLowerFromDescription', () {
    test('normalizes Dunkin and high-confidence aliases to one key', () {
      expect(
        merchantKeyLowerFromDescription(
          'DUNKIN #304654 12/31 MOBILE PURCHASE SOMERVILLE MA',
        ),
        'dunkin',
      );
      expect(merchantKeyLowerFromDescription('DD/BR #1234'), 'dunkin');
      expect(merchantKeyLowerFromDescription('DUNKIN DONUTS #1234'), 'dunkin');
      expect(merchantKeyLowerFromDescription("DUNKIN' DONUTS"), 'dunkin');
    });

    test('keeps underlying merchant when a payment aggregator is present', () {
      expect(
        merchantKeyLowerFromDescription(
          'TST* BOM DOUGH 02/28 MOBILE PURCHASE CAMBRIDGE MA',
        ),
        'bom dough',
      );
      expect(
        merchantKeyLowerFromDescription(
          'SQ *BOM DOUGH 02/28 MOBILE PURCHASE CAMBRIDGE MA',
        ),
        'bom dough',
      );
      expect(
        merchantKeyLowerFromDescription('PAYPAL *SPOTIFY 1234'),
        'spotify',
      );
    });

    test('removes date, phone, reference, and location noise', () {
      expect(
        merchantKeyLowerFromDescription(
          'APPLE.COM/BILL 05/03 REFUND 866-712-7753 CA',
        ),
        'apple com bill',
      );
      expect(
        merchantKeyLowerFromDescription(
          'BKOFAMERICA ATM 03/02 #XXXXX6083 WITHDRWL EAST CAMBRIDGE MA',
        ),
        'bkofamerica atm withdrwl',
      );
    });

    test('does not merge unrelated merchants', () {
      final pearl = merchantKeyLowerFromDescription(
        'PEARL ST MARKET 02/28 MOBILE PURCHASE SOMERVILLE MA',
      );
      final dollarTree = merchantKeyLowerFromDescription(
        'DOLLARTREE 01/08 MOBILE PURCHASE SOMERVILLE MA',
      );

      expect(pearl, 'pearl st market');
      expect(dollarTree, 'dollartree');
      expect(pearl, isNot(dollarTree));
    });

    test('returns an empty key for empty or all-noise descriptions', () {
      expect(merchantKeyLowerFromDescription(''), '');
      expect(merchantKeyLowerFromDescription('  '), '');
      expect(merchantKeyLowerFromDescription('05/03 #123456 866-712-7753'), '');
    });
  });
}
