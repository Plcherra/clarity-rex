import '../../../core/models/models.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../transactions/domain/spend_categories.dart';
import '../../transactions/domain/transaction_resolution.dart';
import 'dashboard_transaction_groups.dart';

bool _inMonth(DateTime d, DateTime reference) {
  return d.year == reference.year && d.month == reference.month;
}

DateTime _firstDayOfPreviousMonth(DateTime ref) {
  if (ref.month == 1) return DateTime(ref.year - 1, 12, 1);
  return DateTime(ref.year, ref.month - 1, 1);
}

/// Sum of positive inflows in the calendar month of [reference].
///
/// Rows whose effective category is [kIgnoredCategoryLabel] (e.g. reversals) are omitted.
double totalIncomeInMonth(
  List<Transaction> txs,
  List<Account> accounts,
  DateTime reference, {
  Map<String, String> categoryOverrides = const {},
  Map<String, String> categoryDisplayRenamesLower = const {},
  Map<String, String> merchantCategoryMemory = const {},
}) {
  final accountsById = {for (final a in accounts) a.id: a};
  final resolved = resolveTransactions(
    txs,
    categoryOverrides: categoryOverrides,
    categoryDisplayRenamesLower: categoryDisplayRenamesLower,
    merchantCategoryMemory: merchantCategoryMemory,
    accountsById: accountsById,
    allTransactions: txs,
  );
  var sum = 0.0;
  for (final r in resolved) {
    final t = r.transaction;
    if (t.pending) continue;
    if (!_inMonth(t.date, reference)) continue;
    if (!r.countsAsIncome) continue;
    sum += t.amount;
  }
  return sum;
}

void addResolvedCategorySpend(
  Map<String, double> map,
  ResolvedTransaction resolved,
) {
  final transaction = resolved.transaction;
  if (transaction.pending) return;
  final bucket = spendCategoryBucketKey(resolved);
  if (isNeedsCategoryGroupKey(bucket)) {
    map[bucket] = (map[bucket] ?? 0) + transaction.amount.abs();
    return;
  }
  if (!resolved.countsAsSpend) return;
  if (isIgnoredCategoryLabel(bucket) || isIncomeCategoryLabel(bucket)) return;
  map[bucket] = (map[bucket] ?? 0) + (-transaction.amount);
}

Map<String, Map<String, double>> monthlyCategorySpendTotals(
  Iterable<ResolvedTransaction> resolved,
) {
  final byMonth = <String, Map<String, double>>{};
  for (final row in resolved) {
    if (row.transaction.pending) continue;
    final month = yearMonthKey(row.transaction.date);
    addResolvedCategorySpend(byMonth.putIfAbsent(month, () => {}), row);
  }
  return byMonth;
}

/// Spending by category (outflows, non-income labels), same rules as dashboard top categories.
Map<String, double> _spendByCategoryInMonth(
  List<Transaction> txs,
  List<Account> accounts,
  DateTime month,
  Map<String, String> categoryOverrides,
  Map<String, String> categoryDisplayRenamesLower,
  Map<String, String> merchantCategoryMemory,
) {
  final accountsById = {for (final a in accounts) a.id: a};
  final resolved = resolveTransactions(
    txs,
    categoryOverrides: categoryOverrides,
    categoryDisplayRenamesLower: categoryDisplayRenamesLower,
    merchantCategoryMemory: merchantCategoryMemory,
    accountsById: accountsById,
    allTransactions: txs,
  );
  final map = <String, double>{};
  for (final r in resolved) {
    final t = r.transaction;
    if (t.pending) continue;
    if (!_inMonth(t.date, month)) continue;
    final bucket = spendCategoryBucketKey(r);
    if (isNeedsCategoryGroupKey(bucket)) {
      map[bucket] = (map[bucket] ?? 0) + t.amount.abs();
      continue;
    }
    if (!r.countsAsSpend) continue;
    if (isIgnoredCategoryLabel(bucket)) continue;
    map[bucket] = (map[bucket] ?? 0) + (-t.amount);
  }
  return map;
}

double? _percentChange(double prev, double current) {
  if (prev <= 0) return null;
  return (current - prev) / prev;
}

/// Top [limit] spending categories for [reference] month with change vs previous month.
List<CategoryLeakStat> biggestCategoryLeaks(
  List<Transaction> txs,
  List<Account> accounts,
  DateTime reference, {
  int limit = 3,
  required Map<String, String> categoryOverrides,
  required Map<String, String> categoryDisplayRenamesLower,
  Map<String, String> merchantCategoryMemory = const {},
}) {
  final thisMonth = _spendByCategoryInMonth(
    txs,
    accounts,
    reference,
    categoryOverrides,
    categoryDisplayRenamesLower,
    merchantCategoryMemory,
  );
  final prevRef = _firstDayOfPreviousMonth(reference);
  final lastMonth = _spendByCategoryInMonth(
    txs,
    accounts,
    prevRef,
    categoryOverrides,
    categoryDisplayRenamesLower,
    merchantCategoryMemory,
  );

  final sorted = thisMonth.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.take(limit).toList();

  return top.map((e) {
    final name = e.key;
    final cur = e.value;
    final prev = lastMonth[name] ?? 0.0;
    return CategoryLeakStat(
      name: name,
      amountThisMonth: cur,
      amountLastMonth: prev,
      percentChangeFromLastMonth: _percentChange(prev, cur),
    );
  }).toList();
}

/// Days of runway if [spentThisMonth] continues at per-day pace for elapsed days in month.
int? runwayDaysFromBurnRate({
  required double totalBalance,
  required double spentThisMonth,
  required DateTime referenceInMonth,
}) {
  if (totalBalance <= 0 || spentThisMonth <= 0) return null;
  final day = referenceInMonth.day;
  final daily = spentThisMonth / (day < 1 ? 1 : day);
  if (daily <= 0 || daily.isNaN) return null;
  final days = (totalBalance / daily).floor();
  if (days < 0) return null;
  return days;
}
