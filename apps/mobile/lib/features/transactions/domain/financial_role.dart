import '../../../core/models/models.dart';
import 'internal_payment_matcher.dart';
import 'internal_transfer_matcher.dart';
import 'self_transfer_names.dart';
import 'spend_categories.dart';

bool _looksLikeRefundDescription(String description) {
  final h = description.toLowerCase();
  return h.contains('refund') ||
      h.contains('refunded') ||
      h.contains('reversal') ||
      h.contains('reversed') ||
      h.contains('chargeback');
}

/// Derives the effective financial role used for dashboards.
///
/// Direction is one-way: role resolution may call matchers, but matchers must
/// not call role resolution (prevents recursion).
FinancialRole effectiveFinancialRole({
  required Transaction t,
  required String effectiveCategoryLabel,
  required Map<String, Account> accountsById,
  required List<Transaction> allTransactions,
  SelfTransferNames selfTransferNames = SelfTransferNames.empty,
}) {
  final stored = t.financialRole;
  if (stored != null) return stored;

  if (isIgnoredCategoryLabel(effectiveCategoryLabel)) {
    return FinancialRole.adjustment;
  }

  // Refunds are a distinct role (v1 policy: exclude from both income and spend).
  if (t.amount > 0 && _looksLikeRefundDescription(t.description)) {
    return FinancialRole.refund;
  }

  // Banks file every outgoing Zelle as a transfer, whether the money went to
  // the user's own savings or to their landlord. So the label is a hint, never
  // proof on its own: money is only the user's own money when a second side of
  // the move can be seen. Rent has no second side, and hiding it from spending
  // is how a losing month reads as a profitable one.
  //
  // Each check below is one way that second side can show up. When none of them
  // holds, the fallback at the end of this function treats the row by
  // direction — the same conservative rule the card-payment branch uses.

  if (looksLikeInternalTransferDescription(
    t.description,
    amount: t.amount,
  )) {
    return FinancialRole.transfer;
  }

  // The row names another account the user connected, in either direction.
  if (describesAnotherOwnAccount(
    description: t.description,
    accountsById: accountsById,
    excludingAccountId: t.accountId,
  )) {
    return FinancialRole.transfer;
  }

  // The user paying themselves, recognised by a name their own transfers have
  // already proven — covers the days only one side of the move was imported.
  if (selfTransferNames.matches(t.description)) return FinancialRole.transfer;

  final internalTransfer = findConfirmedInternalTransferMatch(
    t: t,
    allTransactions: allTransactions,
    accountsById: accountsById,
  );
  if (internalTransfer != null) return FinancialRole.transfer;

  // Credit card payment: prefer a both-leg match; otherwise soft-match a
  // labeled depository outflow toward a connected card before the credit posts.
  if (effectiveCategoryLabel.trim().toLowerCase() ==
      'credit card payment'.toLowerCase()) {
    final match = findConfirmedCreditCardPaymentForTransaction(
      t: t,
      allTransactions: allTransactions,
      accountsById: accountsById,
    );
    if (match != null) return FinancialRole.creditCardPayment;
    if (looksLikeSoftCreditCardPayment(t: t, accountsById: accountsById)) {
      return FinancialRole.creditCardPayment;
    }
    return FinancialRole.expense;
  }

  // Nobody is paid onto a credit card: inflows there are rewards, statement
  // credits, or refunds. Counting them as income inflates what the user earned.
  if (t.amount > 0 &&
      accountsById[t.accountId]?.type == AccountType.creditCard) {
    return FinancialRole.adjustment;
  }

  if (isIncomeCategoryLabel(effectiveCategoryLabel)) {
    return FinancialRole.income;
  }

  // Fallback by sign: outflows are expenses; inflows only count as income when
  // the category already says income (payroll/zelle heuristics land there).
  if (t.amount < 0) return FinancialRole.expense;
  if (t.amount > 0) return FinancialRole.adjustment;
  return FinancialRole.adjustment;
}
