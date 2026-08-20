import 'account_balance_breakdown.dart';
import 'balance_resolve.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import 'dashboard_activity_period.dart';
import 'dashboard_metrics.dart';
import 'monthly_cash_flow_series.dart';
import 'savings_snapshot.dart';
import '../../../core/models/models.dart';
import '../../transactions/domain/transaction_resolution.dart';

sealed class DashboardScope {
  const DashboardScope();
}

final class GlobalDashboardScope extends DashboardScope {
  const GlobalDashboardScope();
}

final class AccountDashboardScope extends DashboardScope {
  const AccountDashboardScope(this.accountId);
  final String accountId;
}

Account? scopedAccountForDashboard(
  DashboardScope scope,
  List<Account> accounts,
) {
  if (scope is! AccountDashboardScope) return null;
  for (final account in accounts) {
    if (account.id == scope.accountId) return account;
  }
  return null;
}

/// Statement months for [scopedTransactions], newest calendar month first.
/// Matches [DashboardSnapshot.monthlyGroups] from [buildDashboardSnapshot].
List<MonthlyBankGroup> monthlyBankGroupsNewestFirstForScopedTransactions(
  List<Transaction> scopedTransactions, {
  required Map<String, String> categoryOverrides,
  required Map<String, String> categoryDisplayRenamesLower,
  Map<String, String> merchantCategoryMemory = const {},
}) {
  final resolved = resolveTransactions(
    scopedTransactions,
    categoryOverrides: categoryOverrides,
    categoryDisplayRenamesLower: categoryDisplayRenamesLower,
    merchantCategoryMemory: merchantCategoryMemory,
    accountsById: const {},
    allTransactions: scopedTransactions,
  );
  final grouped = monthlyGroupsFromResolvedTransactions(resolved);
  return grouped.reversed.toList();
}

List<MonthlyBankGroup> monthlyBankGroupsNewestFirstForResolvedTransactions(
  List<ResolvedTransaction> scopedTransactions,
) {
  final grouped = monthlyGroupsFromResolvedTransactions(scopedTransactions);
  return grouped.reversed.toList();
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.totalBalance,
    this.cashTotal = 0,
    this.debtTotal = 0,
    this.creditAvailableTotal,
    this.creditLeftIncomplete = false,
    required this.spentThisMonth,
    required this.incomeThisMonth,
    required this.availableThisMonth,
    required this.topCategories,
    required this.biggestLeaksThisMonth,
    required this.burnRunwayDays,
    required this.monthlyGroups,
    required this.referenceMonth,
    this.pendingIncomeThisMonth = 0,
    this.pendingSpentThisMonth = 0,
    this.monthlyCashFlow = const [],
    this.monthlyCategorySpend = const {},
    this.savings,
  });

  /// The month every "this month" number here was measured in. Drill-downs read
  /// it so a detail screen can never show a different month than the card.
  final DateTime referenceMonth;

  final double totalBalance;

  /// Checking + savings right now. Not this month's leftover.
  final double cashTotal;

  /// Credit cards owed right now, as a positive amount.
  final double debtTotal;

  /// Unused card limit, when at least one connected card reports it.
  final double? creditAvailableTotal;

  /// True when at least one card is owed or connected but has no leftover figure.
  final bool creditLeftIncomplete;

  final double spentThisMonth;
  final double incomeThisMonth;

  /// Income minus spending this month. Not cash on hand.
  final double availableThisMonth;

  /// Pending slice already included in [incomeThisMonth].
  final double pendingIncomeThisMonth;

  /// Pending slice already included in [spentThisMonth].
  final double pendingSpentThisMonth;

  final List<CategorySpend> topCategories;
  final List<CategoryLeakStat> biggestLeaksThisMonth;
  final int? burnRunwayDays;

  /// Statement months, newest first. Every row of the month, for month detail.
  final List<MonthlyBankGroup> monthlyGroups;

  /// Chart series, oldest month first. Counted like [spentThisMonth] and
  /// [incomeThisMonth] so a chart can never disagree with the overview card.
  final List<MonthlyCashFlowPoint> monthlyCashFlow;

  /// Posted spend by `YYYY-MM` then category. Charts sum this for 1M / 6M / 1Y.
  final Map<String, Map<String, double>> monthlyCategorySpend;

  /// Null unless a savings account is connected in this scope.
  final SavingsSnapshot? savings;

  bool get hasPendingCashFlowThisMonth =>
      pendingIncomeThisMonth > 0 || pendingSpentThisMonth > 0;
}

DashboardSnapshot buildDashboardSnapshot({
  required DashboardScope scope,
  required DateTime reference,
  required List<Account> accounts,
  required List<Transaction> allTransactions,
  required List<Transaction> scopedTransactions,
  required Map<String, String> categoryOverrides,
  required Map<String, String> categoryDisplayRenamesLower,
  Map<String, String> merchantCategoryMemory = const {},
  required double? scopedBalanceFromStatement,
  double? Function(Account account)? signedBalanceFor,
}) {
  final accountsById = {for (final a in accounts) a.id: a};
  final resolved = resolveTransactions(
    scopedTransactions,
    categoryOverrides: categoryOverrides,
    categoryDisplayRenamesLower: categoryDisplayRenamesLower,
    merchantCategoryMemory: merchantCategoryMemory,
    accountsById: accountsById,
    allTransactions: allTransactions,
  );

  final y = reference.year;
  final m = reference.month;

  // Spend/income use the scoped list; role resolution uses global context so
  // internal-payment matching stays correct. Pending rows count now and drop
  // out when Plaid replaces them with the posted copy — same clock as NOW.
  var spent = 0.0;
  var income = 0.0;
  var pendingSpent = 0.0;
  var pendingIncome = 0.0;
  for (final r in resolved) {
    final t = r.transaction;
    if (t.date.year != y || t.date.month != m) continue;
    if (r.countsAsSpend) {
      spent += -t.amount;
      if (t.pending) pendingSpent += -t.amount;
    }
    if (r.countsAsIncome) {
      income += t.amount;
      if (t.pending) pendingIncome += t.amount;
    }
  }

  final available = income - spent;

  final categorySpendByMonth = monthlyCategorySpendTotals(resolved);
  final top5 = categorySpendForActivityPeriod(
    monthlyCategorySpend: categorySpendByMonth,
    reference: reference,
    period: DashboardActivityPeriod.month,
  );

  // Leaks (scoped). Note: biggestCategoryLeaks currently uses its provided list
  // for role resolution context. For v1, this is acceptable; the major correctness
  // issue (CC payment exclusion) is handled in spend/income above.
  final leaks = biggestCategoryLeaks(
    scopedTransactions,
    accounts,
    reference,
    limit: 3,
    categoryOverrides: categoryOverrides,
    categoryDisplayRenamesLower: categoryDisplayRenamesLower,
    merchantCategoryMemory: merchantCategoryMemory,
  );

  final monthsNewestFirst = monthlyBankGroupsNewestFirstForResolvedTransactions(
    resolved,
  );

  final scopedAccounts = switch (scope) {
    GlobalDashboardScope() => accounts,
    AccountDashboardScope(:final accountId) =>
      accounts.where((account) => account.id == accountId).toList(),
  };
  final breakdown = buildAccountBalanceBreakdown(
    accounts: scopedAccounts,
    signedBalanceFor: signedBalanceFor ?? signedBalanceFromCurrent,
  );

  final balance = switch (scope) {
    GlobalDashboardScope() => breakdown.netBalance,
    AccountDashboardScope(:final accountId) =>
      scopedBalanceFromStatement ??
          accountsById[accountId]?.currentBalance ??
          resolveTotalBalance(scopedBalanceFromStatement),
  };

  final runway = runwayDaysFromBurnRate(
    totalBalance: balance,
    spentThisMonth: spent,
    referenceInMonth: reference,
  );

  return DashboardSnapshot(
    totalBalance: balance,
    cashTotal: breakdown.cashTotal,
    debtTotal: breakdown.debtTotal,
    creditAvailableTotal: breakdown.creditAvailableTotal,
    creditLeftIncomplete: breakdown.creditLeftIncomplete,
    spentThisMonth: spent,
    incomeThisMonth: income,
    availableThisMonth: available,
    pendingIncomeThisMonth: pendingIncome,
    pendingSpentThisMonth: pendingSpent,
    topCategories: top5,
    biggestLeaksThisMonth: leaks,
    burnRunwayDays: runway,
    monthlyGroups: monthsNewestFirst,
    referenceMonth: reference,
    monthlyCashFlow: buildMonthlyCashFlowSeries(resolved),
    monthlyCategorySpend: categorySpendByMonth,
    savings: buildSavingsSnapshot(
      scope: scope,
      reference: reference,
      accounts: accounts,
      resolved: resolved,
    ),
  );
}
