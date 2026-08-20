import '../../../core/formatting/formatting.dart';
import '../../../core/models/models.dart';
import '../../../l10n/app_localizations.dart';

bool isCreditCardAccount(Account account) =>
    account.type == AccountType.creditCard;

/// This-month flow for a card: payments and charges, never cash in/out.
String creditCardMonthActivityValue({
  required AppLocalizations l10n,
  required double payments,
  required double charged,
}) {
  if (payments.abs() > 0.005) {
    return l10n.plaidAccountPaidChargedSummary(
      formatMoney(payments),
      formatMoney(charged),
    );
  }
  return l10n.plaidAccountChargedSummary(formatMoney(charged));
}
