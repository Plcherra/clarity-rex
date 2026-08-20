import '../../../core/models/models.dart';
import '../../transactions/domain/transaction_resolution.dart';
import 'account_balance_breakdown.dart';
import 'dashboard_snapshot.dart';

/// What the user is holding in savings, and what moved there this month.
///
/// Kept apart from income and spending on purpose: moving pay into savings is
/// not spending it, and moving it back out is not earning. The month change is
/// every deposit minus every withdrawal on the savings accounts themselves.
class SavingsSnapshot {
  const SavingsSnapshot({
    required this.balance,
    required this.changeThisMonth,
    required this.accountCount,
  });

  final double balance;
  final double changeThisMonth;
  final int accountCount;

  bool get grewThisMonth => changeThisMonth > 0.005;
  bool get shrankThisMonth => changeThisMonth < -0.005;
}

/// Null when no savings account is in scope — nothing to show, nothing faked.
SavingsSnapshot? buildSavingsSnapshot({
  required DashboardScope scope,
  required DateTime reference,
  required List<Account> accounts,
  required List<ResolvedTransaction> resolved,
}) {
  final savingsAccounts = accounts
      .where((account) => account.type == AccountType.savings)
      .where(
        (account) => switch (scope) {
          GlobalDashboardScope() => true,
          AccountDashboardScope(:final accountId) => account.id == accountId,
        },
      )
      .toList(growable: false);
  if (savingsAccounts.isEmpty) return null;

  final ids = {for (final account in savingsAccounts) account.id};
  var change = 0.0;
  for (final row in resolved) {
    final transaction = row.transaction;
    if (!ids.contains(transaction.accountId)) continue;
    if (transaction.date.year != reference.year ||
        transaction.date.month != reference.month) {
      continue;
    }
    change += transaction.amount;
  }

  return SavingsSnapshot(
    balance: savingsAccounts.fold<double>(
      0,
      (sum, account) => sum + (liveSignedBalanceForAccount(account) ?? 0),
    ),
    changeThisMonth: change,
    accountCount: savingsAccounts.length,
  );
}
