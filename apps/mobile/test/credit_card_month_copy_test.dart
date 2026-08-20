import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/accounts/presentation/credit_card_month_copy.dart';
import 'package:clarity/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('identifies credit cards only', () {
    expect(
      isCreditCardAccount(const Account(id: 'c', name: 'Card', type: AccountType.creditCard)),
      isTrue,
    );
    expect(
      isCreditCardAccount(const Account(id: 'k', name: 'Checking', type: AccountType.checking)),
      isFalse,
    );
  });

  test('uses charged copy when the card has no payments', () {
    expect(
      creditCardMonthActivityValue(l10n: l10n, payments: 0, charged: 459.98),
      '\$459.98 charged',
    );
  });

  test('uses paid and charged copy when the card has payments', () {
    expect(
      creditCardMonthActivityValue(l10n: l10n, payments: 200, charged: 459.98),
      '\$200.00 paid / \$459.98 charged',
    );
  });
}
