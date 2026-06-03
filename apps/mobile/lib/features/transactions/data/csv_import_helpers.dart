import '../../../core/models/models.dart';

Transaction stampTransactionForAccount(
  Transaction transaction,
  String accountId,
) {
  return Transaction(
    date: transaction.date,
    description: transaction.description,
    amount: transaction.amount,
    accountId: accountId,
    category: transaction.category,
    balanceAfter: transaction.balanceAfter,
  );
}

DateTime importSpendReference(List<Transaction> transactions) {
  if (transactions.isEmpty) return DateTime.now();
  final spendTransactions = transactions
      .where((transaction) => transaction.amount < 0)
      .toList();
  final candidates = spendTransactions.isEmpty
      ? transactions
      : spendTransactions;
  var latest = candidates.first.date;
  for (final transaction in candidates.skip(1)) {
    if (transaction.date.isAfter(latest)) {
      latest = transaction.date;
    }
  }
  return latest;
}

({DateTime start, DateTime end})? transactionDateRange(
  List<Transaction> transactions,
) {
  if (transactions.isEmpty) return null;
  var start = transactions.first.date;
  var end = transactions.first.date;
  for (final transaction in transactions.skip(1)) {
    if (transaction.date.isBefore(start)) start = transaction.date;
    if (transaction.date.isAfter(end)) end = transaction.date;
  }
  return (start: start, end: end);
}
