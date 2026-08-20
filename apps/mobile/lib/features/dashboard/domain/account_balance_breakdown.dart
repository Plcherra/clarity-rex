import '../../../core/models/models.dart';

/// Right-now position across accounts: cash, card debt, leftover credit.
///
/// Kept apart from this-month income/spending on purpose. Those are flow.
/// These numbers are stock. Both clocks count pending; flow updates when it posts.
class AccountBalanceBreakdown {
  const AccountBalanceBreakdown({
    required this.cashTotal,
    required this.debtTotal,
    this.creditAvailableTotal,
    required this.cashAccountCount,
    required this.creditAccountCount,
    required this.creditAccountsWithAvailableCount,
  });

  /// Checking + savings balances.
  final double cashTotal;

  /// Credit cards owed, as a positive amount.
  final double debtTotal;

  /// Unused card limit from Plaid, when at least one card reports it.
  final double? creditAvailableTotal;

  final int cashAccountCount;
  final int creditAccountCount;
  final int creditAccountsWithAvailableCount;

  /// Live net worth for these accounts: cash minus cards owed right now.
  double get netBalance => cashTotal - debtTotal;

  /// Cash plus unused credit — spendable room, not net worth.
  double get usableTotal => cashTotal + (creditAvailableTotal ?? 0);

  bool get hasCashAccounts => cashAccountCount > 0;
  bool get hasCreditCards => creditAccountCount > 0;
  bool get hasCreditAvailable => creditAvailableTotal != null;
  bool get creditLeftIncomplete =>
      creditAccountCount > creditAccountsWithAvailableCount;
}

/// Signed posted ledger. Prefer [liveSignedBalanceForAccount] for NOW.
double? signedBalanceFromCurrent(Account account) {
  final raw = account.currentBalance;
  if (raw == null || raw.isNaN) return null;
  return _signedFromRaw(account.type, raw);
}

/// Bank-matching NOW balance: Plaid available, else current ± pending.
///
/// Depository `available` already subtracts pending and holds — do not also
/// subtract our pending rows. Credit `current` is posted amount owed; when the
/// issuer does not send a live leftover, pending card charges still belong in
/// NOW debt so net worth moves the same day you spend.
double? liveSignedBalanceForAccount(
  Account account, {
  double? statementOverride,
  Iterable<Transaction> pendingTransactions = const [],
}) {
  if (statementOverride != null && !statementOverride.isNaN) {
    return _signedFromRaw(account.type, statementOverride);
  }
  switch (account.type) {
    case AccountType.checking:
    case AccountType.savings:
      final available = account.plaidAvailableBalance;
      if (available != null && !available.isNaN) return available;
      final current = account.currentBalance;
      if (current == null || current.isNaN) return null;
      return current + _pendingAmountDelta(pendingTransactions);
    case AccountType.creditCard:
      return _liveCreditSigned(account, pendingTransactions);
  }
}

/// Posted card debt plus pending charges when Plaid leftover is missing.
///
/// Old unpaid balance stays in `current`. New pending spend is added so
/// $200 leftover from last month plus an $800 charge is $1,000 owed now.
double? _liveCreditSigned(
  Account account,
  Iterable<Transaction> pendingTransactions,
) {
  final pendingDelta = _pendingAmountDelta(pendingTransactions);
  final current = account.currentBalance;
  if (current == null || current.isNaN) {
    return pendingDelta == 0 ? null : pendingDelta;
  }
  final signed = _signedFromRaw(AccountType.creditCard, current);
  if (_creditCurrentAlreadyLive(account, signed.abs())) return signed;
  return signed + pendingDelta;
}

/// True when leftover credit is a real bank figure, so `current` already
/// includes pending. Skip that add to avoid counting the same charge twice.
bool _creditCurrentAlreadyLive(Account account, double owed) {
  final available = account.plaidAvailableBalance;
  if (available == null || available.isNaN) return false;
  return (available - owed).abs() > 0.01;
}

double _signedFromRaw(AccountType type, double raw) {
  return switch (type) {
    AccountType.creditCard => raw <= 0 ? raw : -raw,
    AccountType.checking || AccountType.savings => raw,
  };
}

double _pendingAmountDelta(Iterable<Transaction> pending) {
  var total = 0.0;
  for (final transaction in pending) {
    if (transaction.amount.isNaN) continue;
    total += transaction.amount;
  }
  return total;
}

/// Leftover credit for one card. Prefer Plaid `available`; if the issuer
/// omitted it or copied the posted amount owed into it, fall back to
/// limit − live owed (posted + pending when those were folded in).
double? creditRemainingForAccount(Account account, {double? owed}) {
  if (account.type != AccountType.creditCard) return null;
  final postedOwed = account.currentBalance?.abs() ?? 0;
  final liveOwed = (owed ?? postedOwed).abs();
  final reported = account.plaidAvailableBalance;
  if (reported != null &&
      !reported.isNaN &&
      (reported - postedOwed).abs() > 0.01) {
    final extraPending = liveOwed > postedOwed ? liveOwed - postedOwed : 0.0;
    final leftover = reported - extraPending;
    return leftover < 0 ? 0 : leftover;
  }
  final limit = account.plaidCreditLimit;
  if (limit == null || limit.isNaN) return null;
  final leftover = limit - liveOwed;
  return leftover < 0 ? 0 : leftover;
}

AccountBalanceBreakdown buildAccountBalanceBreakdown({
  required Iterable<Account> accounts,
  required double? Function(Account account) signedBalanceFor,
}) {
  var cash = 0.0;
  var debt = 0.0;
  var creditAvailableSum = 0.0;
  var cashCount = 0;
  var creditCount = 0;
  var creditWithAvailable = 0;

  for (final account in accounts) {
    final signed = signedBalanceFor(account);
    switch (account.type) {
      case AccountType.checking:
      case AccountType.savings:
        cashCount += 1;
        if (signed != null) cash += signed;
      case AccountType.creditCard:
        creditCount += 1;
        if (signed != null) debt += signed.abs();
        final remaining = creditRemainingForAccount(
          account,
          owed: signed?.abs(),
        );
        if (remaining != null) {
          creditWithAvailable += 1;
          creditAvailableSum += remaining;
        }
    }
  }

  return AccountBalanceBreakdown(
    cashTotal: cash,
    debtTotal: debt,
    creditAvailableTotal: creditWithAvailable > 0 ? creditAvailableSum : null,
    cashAccountCount: cashCount,
    creditAccountCount: creditCount,
    creditAccountsWithAvailableCount: creditWithAvailable,
  );
}
